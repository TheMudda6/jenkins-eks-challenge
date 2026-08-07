package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/database"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/models"
)

func Orders(db *sql.DB) http.HandlerFunc {

	return func(w http.ResponseWriter, r *http.Request) {

		switch r.Method {

		case http.MethodGet:

			orders, err := database.GetOrders(db)

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

			err = database.CreateOrder(db, order)

			if err != nil {
				http.Error(w, "Database error", http.StatusInternalServerError)
				return
			}

			w.WriteHeader(http.StatusCreated)

		default:

			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)

		}
	}
}