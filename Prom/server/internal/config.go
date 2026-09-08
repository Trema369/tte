package internal

import (
	"crypto/rand"
	"encoding/hex"
	"log"
	"os"
	"strings"
)

// Config is the runtime configuration, all sourced from the environment.
type Config struct {
	Port            string
	DataDir         string
	Password        string
	WebhookURL      string
	MentionID       string
	CookieSecret    []byte
	Prod            bool
	CookieName      string
	MaxUnlockTries  int
	UnlockWindowSec int
}

// LoadConfig reads configuration from the environment, applying the same
// defaults the README documents.
func LoadConfig() Config {
	c := Config{
		Port:            envOr("PORT", "8080"),
		DataDir:         envOr("DATA_DIR", "./data"),
		Password:        strings.TrimSpace(os.Getenv("SITE_PASSWORD")),
		WebhookURL:      strings.TrimSpace(os.Getenv("DISCORD_WEBHOOK_URL")),
		MentionID:       strings.TrimSpace(os.Getenv("DISCORD_MENTION_ID")),
		Prod:            truthy(os.Getenv("PROD")),
		CookieName:      "prom_unlock",
		MaxUnlockTries:  12,
		UnlockWindowSec: 600,
	}

	if c.Password == "" {
		c.Password = "hiharley"
		log.Println("config: SITE_PASSWORD empty, using fallback \"hiharley\"")
	}

	if s := strings.TrimSpace(os.Getenv("COOKIE_SECRET")); s != "" {
		c.CookieSecret = []byte(s)
	} else {
		b := make([]byte, 32)
		if _, err := rand.Read(b); err != nil {
			log.Fatalf("config: cannot generate cookie secret: %v", err)
		}
		c.CookieSecret = []byte(hex.EncodeToString(b))
		log.Println("config: COOKIE_SECRET empty, generated a random one (unlock cookies reset on restart)")
	}

	if c.WebhookURL == "" {
		log.Println("config: DISCORD_WEBHOOK_URL empty, answers will be recorded but not posted to Discord")
	}

	return c
}

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func truthy(s string) bool {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "1", "true", "yes", "on":
		return true
	}
	return false
}
