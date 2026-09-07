package main

import (
	"context"
	"database/sql"
	"embed"
	"encoding/json"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	_ "github.com/lib/pq"
)

//go:embed static
var staticFiles embed.FS

var db *sql.DB

var (
	httpRequests = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests.",
		},
		[]string{"route", "code", "method"},
	)

	httpDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "http_request_duration_seconds",
			Help: "HTTP request duration in seconds.",
		},
		[]string{"route", "code", "method"},
	)
)

func init() {
	prometheus.MustRegister(httpRequests)
	prometheus.MustRegister(httpDuration)
}

func instrumentHandler(route string, handler http.Handler) http.Handler {
	labels := prometheus.Labels{"route": route}

	return promhttp.InstrumentHandlerDuration(
		httpDuration.MustCurryWith(labels),
		promhttp.InstrumentHandlerCounter(
			httpRequests.MustCurryWith(labels),
			handler,
		),
	)
}

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	var err error
	db, err = sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer func() {
		if err := db.Close(); err != nil {
			log.Printf("Failed to close database: %v", err)
		}
	}()

	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(3)
	db.SetConnMaxLifetime(5 * time.Minute)
	waitForDB()

	mux := http.NewServeMux()
	mux.Handle("/livez", instrumentHandler("/livez", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})))
	mux.Handle("/healthz", instrumentHandler("/healthz", http.HandlerFunc(handleHealth)))
	mux.Handle("/dashboard/healthz", instrumentHandler("/dashboard/healthz", http.HandlerFunc(handleHealth)))
	mux.Handle("/dashboard/summary", instrumentHandler("/dashboard/summary", http.HandlerFunc(handleSummary)))
	mux.Handle("/dashboard/orders/stats", instrumentHandler("/dashboard/orders/stats", http.HandlerFunc(handleOrderStats)))
	mux.Handle("/dashboard/revenue", instrumentHandler("/dashboard/revenue", http.HandlerFunc(handleRevenue)))
	mux.Handle("/dashboard/inventory/alerts", instrumentHandler("/dashboard/inventory/alerts", http.HandlerFunc(handleInventoryAlerts)))
	mux.Handle("/dashboard/shipping/overview", instrumentHandler("/dashboard/shipping/overview", http.HandlerFunc(handleShippingOverview)))

	// Serve frontend UI
	staticFS, _ := fs.Sub(staticFiles, "static")
	mux.Handle("/", instrumentHandler("/", http.FileServer(http.FS(staticFS))))

	mux.Handle("/metrics", promhttp.Handler())

	port := getEnv("PORT", "8086")
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		log.Printf("Dashboard API listening on :%s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("graceful shutdown error: %v", err)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	status := "ok"
	if err := db.Ping(); err != nil {
		status = "unhealthy"
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]string{"status": status, "service": "dashboard-api"}); err != nil {
		log.Printf("Failed to encode health response: %v", err)
	}
}

func handleSummary(w http.ResponseWriter, r *http.Request) {
	today := time.Now().UTC().Truncate(24 * time.Hour)

	summary := map[string]interface{}{}

	// Order counts
	var totalOrders, ordersToday int
	if err := db.QueryRow("SELECT COUNT(*) FROM orders").Scan(&totalOrders); err != nil {
		httpError(w, "failed to query total orders", http.StatusInternalServerError)
		return
	}
	if err := db.QueryRow("SELECT COUNT(*) FROM orders WHERE created_at >= $1", today).Scan(&ordersToday); err != nil {
		httpError(w, "failed to query orders for today", http.StatusInternalServerError)
		return
	}

	// Orders by status
	statusCounts := map[string]int{}
	rows, err := db.Query("SELECT status, COUNT(*) FROM orders GROUP BY status")
	if err == nil {
		defer func() {
			if err := rows.Close(); err != nil {
				log.Printf("Failed to close order status rows: %v", err)
			}
		}()
		for rows.Next() {
			var status string
			var count int
			if err := rows.Scan(&status, &count); err != nil {
				httpError(w, "failed to read order status", http.StatusInternalServerError)
				return
			}
			statusCounts[status] = count
		}
	}

	// Revenue (charges minus refunds)
	var totalCharges, totalRefunds, todayCharges, todayRefunds float64
	if err := db.QueryRow("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status IN ('completed','partially_refunded','refunded') AND (method IS NULL OR method != 'refund')").Scan(&totalCharges); err != nil {
		httpError(w, "failed to query total charges", http.StatusInternalServerError)
		return
	}
	if err := db.QueryRow("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'completed' AND method = 'refund'").Scan(&totalRefunds); err != nil {
		httpError(w, "failed to query total refunds", http.StatusInternalServerError)
		return
	}
	if err := db.QueryRow("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status IN ('completed','partially_refunded','refunded') AND (method IS NULL OR method != 'refund') AND created_at >= $1", today).Scan(&todayCharges); err != nil {
		httpError(w, "failed to query today's charges", http.StatusInternalServerError)
		return
	}
	if err := db.QueryRow("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'completed' AND method = 'refund' AND created_at >= $1", today).Scan(&todayRefunds); err != nil {
		httpError(w, "failed to query today's refunds", http.StatusInternalServerError)
		return
	}
	totalRevenue := totalCharges - totalRefunds
	revenueToday := todayCharges - todayRefunds

	// Product count
	var totalProducts int
	if err := db.QueryRow("SELECT COUNT(*) FROM products").Scan(&totalProducts); err != nil {
		httpError(w, "failed to query total products", http.StatusInternalServerError)
		return
	}

	// Low stock count
	var lowStockCount int
	if err := db.QueryRow("SELECT COUNT(*) FROM products WHERE (stock - reserved) < 10").Scan(&lowStockCount); err != nil {
		httpError(w, "failed to query low stock count", http.StatusInternalServerError)
		return
	}

	// Active shipments
	var activeShipments int
	if err := db.QueryRow("SELECT COUNT(*) FROM shipments WHERE status NOT IN ('delivered', 'cancelled')").Scan(&activeShipments); err != nil {
		httpError(w, "failed to query active shipments", http.StatusInternalServerError)
		return
	}

	summary["orders"] = map[string]interface{}{
		"total":     totalOrders,
		"today":     ordersToday,
		"by_status": statusCounts,
	}
	summary["revenue"] = map[string]interface{}{
		"total":    totalRevenue,
		"today":    revenueToday,
		"currency": "GBP",
	}
	summary["inventory"] = map[string]interface{}{
		"total_products": totalProducts,
		"low_stock":      lowStockCount,
	}
	summary["shipping"] = map[string]interface{}{
		"active_shipments": activeShipments,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(summary); err != nil {
		log.Printf("Failed to encode summary response: %v", err)
	}
}

func handleOrderStats(w http.ResponseWriter, r *http.Request) {
	// Orders per day for last 30 days
	rows, err := db.Query(
		`SELECT DATE(created_at) as day, COUNT(*), COALESCE(SUM(total), 0)
		 FROM orders
		 WHERE created_at >= NOW() - INTERVAL '30 days'
		 GROUP BY DATE(created_at)
		 ORDER BY day DESC`,
	)
	if err != nil {
		httpError(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer func() {
		if err := rows.Close(); err != nil {
			log.Printf("Failed to close statistics rows: %v", err)
		}
	}()

	type DayStat struct {
		Date    string  `json:"date"`
		Orders  int     `json:"orders"`
		Revenue float64 `json:"revenue"`
	}

	stats := []DayStat{}
	for rows.Next() {
		var s DayStat
		if err := rows.Scan(&s.Date, &s.Orders, &s.Revenue); err != nil {
			httpError(w, "failed to read statistics", http.StatusInternalServerError)
			return
		}
		stats = append(stats, s)
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(stats); err != nil {
		log.Printf("Failed to encode statistics response: %v", err)
	}
}

func handleRevenue(w http.ResponseWriter, r *http.Request) {
	// Revenue breakdown
	var total, refunded, net float64

	if err := db.QueryRow(
		"SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status IN ('completed', 'partially_refunded', 'refunded') AND (method IS NULL OR method != 'refund')",
	).Scan(&total); err != nil {
		httpError(w, "failed to query total revenue", http.StatusInternalServerError)
		return
	}

	if err := db.QueryRow(
		"SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'completed' AND method = 'refund'",
	).Scan(&refunded); err != nil {
		httpError(w, "failed to query refunded revenue", http.StatusInternalServerError)
		return
	}

	net = total - refunded

	// Revenue by day (last 7 days)
	rows, err := db.Query(
		`SELECT DATE(created_at) as day, COALESCE(SUM(amount), 0)
		 FROM payments
		 WHERE status IN ('completed', 'partially_refunded', 'refunded') AND (method IS NULL OR method != 'refund')
		 AND created_at >= NOW() - INTERVAL '7 days'
		 GROUP BY DATE(created_at)
		 ORDER BY day DESC`,
	)

	type DayRevenue struct {
		Date    string  `json:"date"`
		Revenue float64 `json:"revenue"`
	}

	daily := []DayRevenue{}
	if err == nil {
		defer func() {
			if err := rows.Close(); err != nil {
				log.Printf("Failed to close revenue rows: %v", err)
			}
		}()
		for rows.Next() {
			var d DayRevenue
			if err := rows.Scan(&d.Date, &d.Revenue); err != nil {
				httpError(w, "failed to read daily revenue", http.StatusInternalServerError)
				return
			}
			daily = append(daily, d)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]interface{}{
		"total":    total,
		"refunded": refunded,
		"net":      net,
		"currency": "GBP",
		"daily":    daily,
	}); err != nil {
		log.Printf("Failed to encode revenue response: %v", err)
	}
}

func handleInventoryAlerts(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(
		`SELECT id, name, sku, stock, reserved, (stock - reserved) as available
		 FROM products
		 WHERE (stock - reserved) < 10
		 ORDER BY (stock - reserved) ASC`,
	)
	if err != nil {
		httpError(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer func() {
		if err := rows.Close(); err != nil {
			log.Printf("Failed to close product rows: %v", err)
		}
	}()

	type Alert struct {
		ID        string `json:"id"`
		Name      string `json:"name"`
		SKU       string `json:"sku"`
		Stock     int    `json:"stock"`
		Reserved  int    `json:"reserved"`
		Available int    `json:"available"`
	}

	alerts := []Alert{}
	for rows.Next() {
		var a Alert
		if err := rows.Scan(&a.ID, &a.Name, &a.SKU, &a.Stock, &a.Reserved, &a.Available); err != nil {
			httpError(w, "failed to read inventory alert", http.StatusInternalServerError)
			return
		}
		alerts = append(alerts, a)
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(alerts); err != nil {
		log.Printf("Failed to encode inventory alerts response: %v", err)
	}
}

func handleShippingOverview(w http.ResponseWriter, r *http.Request) {
	// Shipments by status
	statusCounts := map[string]int{}
	rows, err := db.Query("SELECT status, COUNT(*) FROM shipments GROUP BY status")
	if err == nil {
		defer func() {
			if err := rows.Close(); err != nil {
				log.Printf("Failed to close alert rows: %v", err)
			}
		}()
		for rows.Next() {
			var status string
			var count int
			if err := rows.Scan(&status, &count); err != nil {
				httpError(w, "failed to read shipment status counts", http.StatusInternalServerError)
				return
			}
			statusCounts[status] = count
		}
	}

	// Carrier breakdown
	carrierCounts := map[string]int{}
	rows2, err := db.Query("SELECT carrier, COUNT(*) FROM shipments GROUP BY carrier")
	if err == nil {
		defer func() {
			if err := rows2.Close(); err != nil {
				log.Printf("Failed to close carrier rows: %v", err)
			}
		}()
		for rows2.Next() {
			var carrier string
			var count int
			if err := rows2.Scan(&carrier, &count); err != nil {
				httpError(w, "failed to read carrier breakdown", http.StatusInternalServerError)
				return
			}
			carrierCounts[carrier] = count
		}
	}

	// Average delivery time
	var avgDeliveryHours float64
	if err := db.QueryRow(
		`SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (delivered_at - shipped_at)) / 3600), 0)
		 FROM shipments WHERE delivered_at IS NOT NULL AND shipped_at IS NOT NULL`,
	).Scan(&avgDeliveryHours); err != nil {
		httpError(w, "failed to query average delivery time", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]interface{}{
		"by_status":          statusCounts,
		"by_carrier":         carrierCounts,
		"avg_delivery_hours": avgDeliveryHours,
	}); err != nil {
		log.Printf("Failed to encode shipping overview response: %v", err)
	}
}

func httpError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(map[string]string{"error": msg}); err != nil {
		log.Printf("Failed to encode error response: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func waitForDB() {
	for i := 0; i < 120; i++ {
		if err := db.Ping(); err == nil {
			return
		}
		log.Printf("Waiting for database... (%d/120)", i+1)
		time.Sleep(time.Second)
	}
	log.Fatal("Database not ready after 120s")
}
