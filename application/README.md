# Application

This directory contains a Go HTTP API application with PostgreSQL integration and an Amazon SQS client. It separates configuration, HTTP handlers, database operations, queue operations and data models into internal packages.

> **Scope:** This README documents the application under `application/`. The nine independently deployed microservices are maintained separately under `services/`.

## Architecture

flowchart TD
    A["cmd/api/main.go"] --> B["internal/config"]
    B --> C["internal/queue"]
    B --> D["internal/database"]
    C --> E["AWS SDK for Go v2"]
    E --> F["Amazon SQS"]
    D --> G["PostgreSQL"]
    D --> H["Create orders table"]
    A --> I["HTTP Handler"]
    I --> J["/"]
    I --> K["/health"]
    I --> L["/orders"]
    L --> D
    L --> C
    D --> M["internal/models"]


The entry point loads configuration, initialises the SQS client, connects to PostgreSQL, ensures the `orders` table exists, registers HTTP handlers and starts the HTTP server.

The database and queue packages provide integration points for persistent order data and asynchronous messaging. The precise order-request behaviour is implemented in the HTTP handlers.

## Directory structure

application/
├── cmd/
│   └── api/
│       └── main.go
├── internal/
│   ├── cache/
│   ├── config/
│   │   └── config.go
│   ├── database/
│   │   └── database.go
│   ├── handlers/
│   │   ├── handler.go
│   │   ├── health.go
│   │   ├── home.go
│   │   └── orders.go
│   ├── models/
│   │   ├── health.go
│   │   ├── message.go
│   │   └── order.go
│   └── queue/
│       ├── queue.go
│       └── sqs.go
├── .dockerignore
├── Dockerfile
├── go.mod
├── go.sum
└── README.md

| Component | Responsibility |
|---|---|
| `cmd/api` | Application entry point and HTTP server startup. |
| `internal/config` | Loads application settings from environment variables. |
| `internal/database` | Connects to PostgreSQL, creates the orders table, and inserts and retrieves orders. |
| `internal/handlers` | HTTP handlers for the home, health and orders endpoints. |
| `internal/models` | Application data structures. |
| `internal/queue` | Initialises the AWS SQS client and publishes messages. |
| `internal/cache` | Reserved package directory; a `.gitkeep` file alone does not indicate an implemented cache. |

## PostgreSQL integration

The database package uses Go's `database/sql` interface with the PostgreSQL driver `github.com/lib/pq`.

At startup, the application:

1. Opens the database connection.
2. Calls `db.Ping()` to check connectivity.
3. Creates the `orders` table if it does not already exist.

The table contains:

| Column | Description |
|---|---|
| `id` | Auto-incrementing primary key. |
| `customer_name` | Required customer name. |
| `product_name` | Required product name. |
| `quantity` | Required integer quantity. |
| `created_at` | Timestamp defaulting to the current time. |

The database package provides:

- `Connect()` — opens and checks the database connection.
- `CreateOrdersTable()` — creates the table if necessary.
- `CreateOrder()` — inserts an order and returns its generated ID.
- `GetOrders()` — retrieves orders ordered by ID.

These functions describe the database package's capabilities; whether each function is called for a particular HTTP request depends on the handler implementation.

## Amazon SQS integration

The queue package uses AWS SDK for Go v2.

- `NewClient()` loads the default AWS SDK configuration using the configured AWS region and creates an SQS client.
- `PublishOrderCreated()` sends a message body to the supplied queue URL.

The application requires AWS credentials to be available through the SDK's default credential chain. In AWS deployments, use the intended IAM role and least-privilege permissions rather than hard-coded credentials.

The queue URL is read from the `QUEUE_URL` environment variable. The configuration loader does not provide a default queue URL.

## Configuration

Settings are loaded from environment variables by `internal/config/config.go`.

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `8080` | HTTP server port. |
| `DB_HOST` | `localhost` | PostgreSQL hostname. |
| `DB_PORT` | `5432` | PostgreSQL