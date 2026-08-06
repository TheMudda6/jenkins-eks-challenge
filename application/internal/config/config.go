package config

import "os"

type Config struct {
	Port         string
	DatabaseHost string
	DatabasePort string
	DatabaseUser string
	DatabasePass string
	DatabaseName string
}

func Load() Config {

	port := os.Getenv("PORT")

	if port == "" {
		port = "8080"
	}

	dbHost := os.Getenv("DB_HOST")

if dbHost == "" {
    dbHost = "localhost"
}

dbPort := os.Getenv("DB_PORT")

if dbPort == "" {
    dbPort = "5432"
}

dbUser := os.Getenv("DB_USER")

if dbUser == "" {
    dbUser = "orderapi"
}

dbPass := os.Getenv("DB_PASSWORD")

if dbPass == "" {
    dbPass = "changeme"
}

dbName := os.Getenv("DB_NAME")

if dbName == "" {
    dbName = "orders"
}

return Config{
	Port:         ":" + port,
	DatabaseHost: dbHost,
	DatabasePort: dbPort,
	DatabaseUser: dbUser,
	DatabasePass: dbPass,
	DatabaseName: dbName,
}
}