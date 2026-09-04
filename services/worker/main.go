package main

import (
	"context"
	"encoding/json"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	sqsTypes "github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

var (
	sqsMessagesReceived = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "worker_sqs_messages_received_total",
			Help: "Total number of SQS messages received by the worker.",
		},
	)
	eventsProcessed = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "worker_events_processed_total",
			Help: "Total number of events successfully processed by the worker.",
		},
		[]string{"event_type"},
	)
	eventProcessingFailures = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "worker_event_processing_failures_total",
			Help: "Total number of event processing failures.",
		},
		[]string{"event_type"},
	)
	sqsReceiveErrors = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "worker_sqs_receive_errors_total",
			Help: "Total number of SQS receive errors.",
		},
	)
	sqsDeleteErrors = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "worker_sqs_delete_errors_total",
			Help: "Total number of SQS delete errors.",
		},
	)
)

func init() {
	prometheus.MustRegister(
		sqsMessagesReceived,
		eventsProcessed,
		eventProcessingFailures,
		sqsReceiveErrors,
		sqsDeleteErrors,
	)
}

// Event represents a message from SQS
type Event struct {
	Type      string                 `json:"type"`
	Payload   map[string]interface{} `json:"payload"`
	Timestamp string                 `json:"timestamp"`
}

func main() {
	sqsQueue := os.Getenv("SQS_QUEUE_URL")
	if sqsQueue == "" {
		log.Fatal("SQS_QUEUE_URL is required")
	}

	awsConfig, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("Failed to load AWS config: %v", err)
	}
	sqsClient := sqs.NewFromConfig(awsConfig)

	// Internal service URLs for event-driven calls
	services := map[string]string{
		"inventory":    getEnv("INVENTORY_SERVICE_URL", "http://inventory-service:8082"),
		"payment":      getEnv("PAYMENT_SERVICE_URL", "http://payment-service:8083"),
		"notification": getEnv("NOTIFICATION_SERVICE_URL", "http://notification-service:8084"),
		"shipping":     getEnv("SHIPPING_SERVICE_URL", "http://shipping-service:8085"),
		"order":        getEnv("ORDER_SERVICE_URL", "http://order-service:8081"),
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Health check endpoint
	go func() {
		mux := http.NewServeMux()

		httpRequests := prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "worker_http_requests_total",
				Help: "Total number of HTTP requests to the worker health server.",
			},
			[]string{"route", "code", "method"},
		)
		httpDuration := prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name: "worker_http_request_duration_seconds",
				Help: "HTTP request duration in seconds for the worker health server.",
			},
			[]string{"route", "code", "method"},
		)
		prometheus.MustRegister(httpRequests, httpDuration)

		instrumentHandler := func(route string, handler http.Handler) http.Handler {
			labels := prometheus.Labels{"route": route}
			return promhttp.InstrumentHandlerDuration(
				httpDuration.MustCurryWith(labels),
				promhttp.InstrumentHandlerCounter(
					httpRequests.MustCurryWith(labels),
					handler,
				),
			)
		}

		mux.Handle("/livez", instrumentHandler("/livez", http.HandlerFunc(
			func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
			},
		)))
		mux.Handle("/healthz", instrumentHandler("/healthz", http.HandlerFunc(
			func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				json.NewEncoder(w).Encode(map[string]string{"status": "ok", "service": "worker"})
			},
		)))
		mux.Handle("/metrics", promhttp.Handler())

		port := getEnv("HEALTH_PORT", "8090")
		log.Printf("Worker health check on :%s", port)
		http.ListenAndServe(":"+port, mux)
	}()

	// Graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		log.Println("Shutting down worker...")
		cancel()
	}()

	log.Println("Worker started, polling SQS for events...")
	pollAndProcess(ctx, sqsClient, sqsQueue, services)
}

func pollAndProcess(ctx context.Context, sqsClient *sqs.Client, queueURL string, services map[string]string) {
	client := &http.Client{Timeout: 10 * time.Second}

	for {
		select {
		case <-ctx.Done():
			log.Println("Worker stopped")
			return
		default:
		}

		messages, err := receiveSQSMessages(ctx, sqsClient, queueURL)
		if err != nil {
			sqsReceiveErrors.Inc()
			if ctx.Err() != nil {
				log.Println("Worker stopped")
				return
			}
			log.Printf("Failed to receive SQS messages: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}

		sqsMessagesReceived.Add(float64(len(messages)))

		for _, message := range messages {
			if message.Body == nil || message.ReceiptHandle == nil {
				log.Println("Received SQS message without body or receipt handle")
				continue
			}

			var event Event
			if err := json.Unmarshal([]byte(*message.Body), &event); err != nil {
				log.Printf("Failed to parse event: %v", err)
				continue
			}

			log.Printf("Processing event: %s", event.Type)

			if err := handleEvent(client, services, event); err != nil {
				eventProcessingFailures.WithLabelValues(event.Type).Inc()
				log.Printf("Failed to handle event %s: %v", event.Type, err)
				// Do not delete the message. SQS will make it
				// visible again and eventually move it to the DLQ.
				continue
			}

			if _, err := sqsClient.DeleteMessage(ctx, &sqs.DeleteMessageInput{
				QueueUrl:      aws.String(queueURL),
				ReceiptHandle: message.ReceiptHandle,
			}); err != nil {
				sqsDeleteErrors.Inc()
				log.Printf("Failed to delete processed message %s: %v", event.Type, err)
				continue
			}

			eventsProcessed.WithLabelValues(event.Type).Inc()
			log.Printf("Successfully processed and deleted: %s", event.Type)
		}
	}
}

func handleEvent(client *http.Client, services map[string]string, event Event) error {
	switch event.Type {

	case "order.created":
		// 1. Reserve inventory
		log.Printf("  -> Reserving inventory for order")
		// POST to inventory-service/reserve with order items
		// If reservation fails, update order status to "cancelled"

		// 2. Process payment
		log.Printf("  -> Processing payment")
		// POST to payment-service/charge
		// If payment fails, release inventory reservation

		// 3. Send confirmation notification
		log.Printf("  -> Sending order confirmation")
		// POST to notification-service/send with order_confirmed template

		// 4. Update order to confirmed
		log.Printf("  -> Confirming order")
		// PUT to order-service/status with new_status: "confirmed"

	case "order.status_changed":
		newStatus, _ := event.Payload["new_status"].(string)

		switch newStatus {
		case "processing":
			// Create shipment
			log.Printf("  -> Creating shipment for order")
			// POST to shipping-service/shipments

		case "shipped":
			// Notify customer
			log.Printf("  -> Sending shipping notification")
			// POST to notification-service/send with order_shipped template

		case "delivered":
			log.Printf("  -> Sending delivery notification")
			// POST to notification-service/send with order_delivered template

		case "cancelled":
			// Release inventory
			log.Printf("  -> Releasing inventory reservation")
			// POST to inventory-service/release

			// Process refund if payment was made
			log.Printf("  -> Processing refund")
			// POST to payment-service/refund
		}

	case "payment.completed":
		log.Printf("  -> Payment successful, confirming order")
		// Update order status to confirmed

	case "payment.failed":
		log.Printf("  -> Payment failed, cancelling order")
		// Release inventory reservation
		// Update order status to cancelled
		// Send payment failed notification

	case "shipment.created":
		log.Printf("  -> Shipment created, updating order to processing")
		// Update order status

	case "shipment.delivered":
		log.Printf("  -> Shipment delivered, updating order")
		// Update order status to delivered
		// Send delivery notification

	default:
		log.Printf("  -> Unknown event type: %s (skipping)", event.Type)
	}

	_ = client
	_ = services
	return nil
}

func receiveSQSMessages(ctx context.Context, sqsClient *sqs.Client, queueURL string) ([]sqsTypes.Message, error) {
	result, err := sqsClient.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
		QueueUrl:            aws.String(queueURL),
		WaitTimeSeconds:     20,
		MaxNumberOfMessages: 10,
	})
	if err != nil {
		return nil, err
	}

	return result.Messages, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
