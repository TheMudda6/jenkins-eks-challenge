package main

import (
	"fmt"
	"net/http"

	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/handlers"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/config"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/database"
)

func main() {

    cfg := config.Load()

    db, err := database.Connect(cfg)

	if err != nil {
        panic(err)
	}

	err = database.CreateOrdersTable(db)

	if err != nil {
    panic(err)
	}

    http.HandleFunc("/", handlers.Home)
    http.HandleFunc("/health", handlers.Health)

    fmt.Println("Server starting on", cfg.Port)

    err = http.ListenAndServe(cfg.Port, nil)

    if err != nil {
        fmt.Println(err)
    }
}