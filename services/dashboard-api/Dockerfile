FROM golang:1.22-bookworm AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
COPY static ./static

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /app/dashboard-api .

FROM debian:bookworm-slim

RUN useradd --system --uid 10001 --no-create-home appuser

COPY --from=builder /app/dashboard-api /usr/local/bin/dashboard-api

USER 10001

EXPOSE 8086

ENTRYPOINT ["/usr/local/bin/dashboard-api"]
