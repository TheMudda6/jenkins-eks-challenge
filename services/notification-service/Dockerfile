FROM golang:1.22-bookworm AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /app/notification-service .

FROM debian:bookworm-slim

RUN useradd --system --uid 10001 --no-create-home appuser

COPY --from=builder /app/notification-service /usr/local/bin/notification-service

USER 10001

EXPOSE 8084

ENTRYPOINT ["/usr/local/bin/notification-service"]
