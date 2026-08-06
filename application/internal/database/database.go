package database

import (
    "database/sql"
    "fmt"

    "github.com/TheMudda6/jenkins-eks-challenge/application/internal/config"

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