package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/database"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/models"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/queue"
)

func (h *Handler) Orders(w http.ResponseWriter, r *http.Request) {

	switch r.Method {

	case http.MethodGet:

		orders, err := database.GetOrders(h.DB)

		if err != nil {
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(orders)

	case http.MethodPost:

		var order models.Order

		err := json.NewDecoder(r.Body).Decode(&order)

		if err != nil {
			http.Error(w, "Invalid request", http.StatusBadRequest)
			return
		}

		err = database.CreateOrder(h.DB, order)

		if err != nil {
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}

		message, err := json.Marshal(order)

		if err != nil {
			http.Error(w, "Failed to create message", http.StatusInternalServerError)
			return
		}

		err = queue.PublishOrderCreated(
			h.SQSClient,
			h.Config.QueueURL,
			string(message),
		)

		if err != nil {
			http.Error(w, "Failed to publish event", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusCreated)

	default:

		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)

	}
}
