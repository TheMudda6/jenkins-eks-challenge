package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/models"
)

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {

	w.Header().Set("Content-Type", "application/json")

	response := models.Health{
		Status: "healthy",
	}

	json.NewEncoder(w).Encode(response)
}