package config

import "os"

type Config struct {
	Port         string
	DatabaseHost string
	DatabasePort string
	DatabaseUser string
	DatabasePass string
	DatabaseName string

	AWSRegion string
	QueueURL  string
}

func Load() Config {

	awsRegion := os.Getenv("AWS_REGION")

	if awsRegion == "" {
		awsRegion = "eu-west-2"
	}

	queueURL := os.Getenv("QUEUE_URL")

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

		AWSRegion: awsRegion,
		QueueURL:  queueURL,
	}
}
