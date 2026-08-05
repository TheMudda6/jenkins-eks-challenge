package main

import (
	"fmt"
	"net/http"

	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/handlers"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/config"
)

func main() {

	cfg := config.Load()

	http.HandleFunc("/", handlers.Home)

	http.HandleFunc("/health", handlers.Health)

	fmt.Println("Server starting on", cfg.Port)

	err := http.ListenAndServe(cfg.Port, nil)

	if err != nil {
		fmt.Println(err)
	}

}