# --- build ---
FROM golang:1.26-alpine AS build
WORKDIR /src

# No external deps, but keep the layer cache friendly.
COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/prom-server .

# --- run ---
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata wget \
  && adduser -D -u 10001 app \
  && mkdir -p /data && chown app:app /data
USER app
WORKDIR /app
COPY --from=build /out/prom-server /app/prom-server

ENV PORT=8080
ENV DATA_DIR=/data
VOLUME ["/data"]
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/api/health || exit 1

ENTRYPOINT ["/app/prom-server"]
