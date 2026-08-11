package main

import (
	"fmt"
	"net/http"

	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/handlers"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/config"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/database"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/queue"
)

func main() {

    cfg := config.Load()

    sqsClient, err := queue.NewClient(cfg)

    if err != nil {
    panic(err)
    }

    db, err := database.Connect(cfg)

	if err != nil {
        panic(err)
	}

	err = database.CreateOrdersTable(db)

	if err != nil {
    panic(err)
	}

    handler := handlers.Handler{
	DB: db,
    Config: cfg,
    SQSClient: sqsClient,
    }

    http.HandleFunc("/", handler.Home)
    http.HandleFunc("/health", handler.Health)
    http.HandleFunc("/orders", handler.Orders)

    fmt.Println("Server starting on", cfg.Port)

    err = http.ListenAndServe(cfg.Port, nil)

    if err != nil {
        fmt.Println(err)
    }
}