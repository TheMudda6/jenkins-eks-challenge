# --------------------------------------------------
# Stage 1 - Build the Go application
# --------------------------------------------------

FROM golang:1.25 AS builder

WORKDIR /app

COPY . .

RUN go mod tidy

RUN go build -o api ./cmd/api

# --------------------------------------------------
# Stage 2 - Runtime image
# --------------------------------------------------

FROM debian:bookworm-slim

WORKDIR /app

COPY --from=builder /app/api .

EXPOSE 8080

CMD ["./api"]