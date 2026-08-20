package database

import (
	"database/sql"
	"fmt"

	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/config"
	"github.com/TheMudda6/jenkins-eks-challenge/application/internal/models"

	_ "github.com/lib/pq"
)

func Connect(cfg config.Config) (*sql.DB, error) {

	connStr := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		cfg.DatabaseHost,
		cfg.DatabasePort,
		cfg.DatabaseUser,
		cfg.DatabasePass,
		cfg.DatabaseName,
	)

	db, err := sql.Open("postgres", connStr)

	if err != nil {
		return nil, err
	}

	err = db.Ping()

	if err != nil {
		return nil, err
	}

	fmt.Println("Successfully connected to PostgreSQL.")

	return db, nil
}

func CreateOrdersTable(db *sql.DB) error {

	query := `
	CREATE TABLE IF NOT EXISTS orders (
		id SERIAL PRIMARY KEY,
		customer_name TEXT NOT NULL,
		product_name TEXT NOT NULL,
		quantity INTEGER NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);`

	_, err := db.Exec(query)

	if err != nil {
		return err
	}

	fmt.Println("Orders table is ready.")

	return nil
}

func CreateOrder(db *sql.DB, order models.Order) (int, error) {

	query := `
    INSERT INTO orders (customer_name, product_name, quantity)
    VALUES ($1, $2, $3)
    RETURNING id
    `

	var id int

	err := db.QueryRow(
		query,
		order.CustomerName,
		order.ProductName,
		order.Quantity,
	).Scan(&id)

	if err != nil {
		return 0, err
	}

	return id, nil
}

func GetOrders(db *sql.DB) ([]models.Order, error) {

	rows, err := db.Query(`
		SELECT id, customer_name, product_name, quantity
		FROM orders
		ORDER BY id;
	`)

	if err != nil {
		return nil, err
	}

	defer rows.Close()

	var orders []models.Order

	for rows.Next() {

		var order models.Order

		err := rows.Scan(
			&order.ID,
			&order.CustomerName,
			&order.ProductName,
			&order.Quantity,
		)

		if err != nil {
			return nil, err
		}

		orders = append(orders, order)
	}

	return orders, nil
}
