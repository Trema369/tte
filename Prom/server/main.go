// Command server is the tiny Go backend for the prom-posal site.
//
// It does three things:
//   - checks the gate password and hands back a signed "unlocked" cookie
//   - records Harley's answer to a flat JSON file (once)
//   - pings a Discord webhook when the answer comes in
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"prom/server/internal"
)

func main() {
	cfg := internal.LoadConfig()

	store, err := internal.NewStore(cfg.DataDir)
	if err != nil {
		log.Fatalf("store: %v", err)
	}

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           internal.Routes(cfg, store),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf("listening on %s (data dir: %s)", srv.Addr, cfg.DataDir)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("listen: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("shutdown: %v", err)
	}
	log.Println("bye")
}
