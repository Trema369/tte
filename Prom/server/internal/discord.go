package internal

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

const (
	colorRose  = 0xC2415F // "yes"
	colorSlate = 0x6B6B78 // "no"
	colorGold  = 0xE6C79C // changed her mind
)

type discordPayload struct {
	Content        string              `json:"content,omitempty"`
	Username       string              `json:"username,omitempty"`
	AllowedMention map[string][]string `json:"allowed_mentions,omitempty"`
	Embeds         []discordEmbed      `json:"embeds,omitempty"`
}

type discordEmbed struct {
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
	Color       int    `json:"color"`
	Timestamp   string `json:"timestamp"`
}

// Notifier posts answer notifications to a Discord webhook.
type Notifier struct {
	url       string
	mentionID string
	client    *http.Client
}

func NewNotifier(webhookURL, mentionID string) *Notifier {
	return &Notifier{
		url:       webhookURL,
		mentionID: mentionID,
		client:    &http.Client{Timeout: 10 * time.Second},
	}
}

// Notify fires the webhook for the given outcome. It never returns an error to
// the caller's critical path — failures are logged and retried once. Safe to
// call in a goroutine.
func (n *Notifier) Notify(res SetResult) {
	if n.url == "" {
		log.Printf("discord: webhook not configured, skipping (answer=%s changed=%v)", res.Record.Answer, res.Changed)
		return
	}

	var title, desc string
	var color int
	switch {
	case res.FromNo:
		title, color = "💖 Harley changed her mind", colorGold
		desc = "She came back and said **Yes, of course ♡**"
	case res.Record.Answer == AnswerYes:
		title, color = "💌 Harley said yes!", colorRose
		desc = "**Yes, of course ♡** — prom is on."
	default:
		title, color = "💭 Harley needs time to think", colorSlate
		desc = "She picked *\"I need a little time to think\"*. Give her space ♡"
	}

	payload := discordPayload{
		Username: "Prom Night",
		Embeds: []discordEmbed{{
			Title:       title,
			Description: desc,
			Color:       color,
			Timestamp:   time.Now().UTC().Format(time.RFC3339),
		}},
	}
	if n.mentionID != "" {
		payload.Content = fmt.Sprintf("<@%s> the answer is in 👀", n.mentionID)
		payload.AllowedMention = map[string][]string{"parse": {"users"}}
	}

	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false) // keep "<@id>" readable rather than "<@id>"
	if err := enc.Encode(payload); err != nil {
		log.Printf("discord: marshal: %v", err)
		return
	}
	body := buf.Bytes()

	for attempt := 1; attempt <= 2; attempt++ {
		if err := n.post(body); err != nil {
			log.Printf("discord: attempt %d failed: %v", attempt, err)
			time.Sleep(2 * time.Second)
			continue
		}
		log.Printf("discord: notified (%s)", res.Record.Answer)
		return
	}
	log.Printf("discord: gave up after 2 attempts")
}

func (n *Notifier) post(body []byte) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, n.url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := n.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)

	if resp.StatusCode >= 300 {
		return fmt.Errorf("discord returned %s", resp.Status)
	}
	return nil
}
