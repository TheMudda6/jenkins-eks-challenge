## PostgreSQL Integration

### Features Implemented

- Added PostgreSQL database package
- Connected Go application to PostgreSQL
- Verified connectivity using `db.Ping()`
- Moved database configuration into the config package
- Added environment variable support for database configuration
- Added automatic creation of the `orders` table during application startup

### Technologies

- Go
- PostgreSQL 17
- Docker
- database/sql
- lib/pq

### Startup Flow

Application Start
↓
Load Configuration
↓
Connect to PostgreSQL
↓
Verify Connection
↓
Create Orders Table (if required)
↓
Register HTTP Routes
↓
Start API Server

