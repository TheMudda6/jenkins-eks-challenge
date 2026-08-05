package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/models"
)

func Home(w http.ResponseWriter, r *http.Request) {

	w.Header().Set("Content-Type", "application/json")

	response := models.Message{
		Message: "Jenkins EKS Challenge API",
	}

	json.NewEncoder(w).Encode(response)
}