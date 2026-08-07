package models

type Order struct {
	ID           int    `json:"id"`
	CustomerName string `json:"customer_name"`
	ProductName  string `json:"product_name"`
	Quantity     int    `json:"quantity"`
}