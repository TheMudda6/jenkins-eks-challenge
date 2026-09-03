FROM golang:1.24-bookworm AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /app/inventory-service .

FROM debian:bookworm-slim

RUN useradd --system --uid 10001 --no-create-home appuser

COPY --from=builder /app/inventory-service /usr/local/bin/inventory-service

USER 10001

EXPOSE 8082

ENTRYPOINT ["/usr/local/bin/inventory-service"]
