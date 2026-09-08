package internal

import (
	"encoding/json"
	"log"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

type api struct {
	cfg      Config
	store    *Store
	notifier *Notifier
	limiter  *limiter
}

// Routes builds the HTTP handler for the whole backend.
func Routes(cfg Config, store *Store) http.Handler {
	a := &api{
		cfg:      cfg,
		store:    store,
		notifier: NewNotifier(cfg.WebhookURL, cfg.MentionID),
		limiter:  newLimiter(cfg.MaxUnlockTries, time.Duration(cfg.UnlockWindowSec)*time.Second),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) { writeJSON(w, 200, map[string]string{"status": "ok"}) })
	mux.HandleFunc("GET /api/state", a.handleState)
	mux.HandleFunc("POST /api/unlock", a.handleUnlock)
	mux.HandleFunc("POST /api/answer", a.handleAnswer)
	return logging(mux)
}

// --- GET /api/state -------------------------------------------------------

func (a *api) handleState(w http.ResponseWriter, r *http.Request) {
	resp := map[string]any{
		"unlocked": a.cfg.isUnlocked(r),
		"answered": nil,
	}
	if rec := a.store.Current(); rec != nil {
		resp["answered"] = rec.Answer
		resp["answeredAt"] = rec.At
	}
	writeJSON(w, 200, resp)
}

// --- POST /api/unlock ---------------------------------------------------

func (a *api) handleUnlock(w http.ResponseWriter, r *http.Request) {
	ip := clientIP(r)
	if !a.limiter.allow(ip) {
		writeErr(w, 429, "Too many tries. Give it a minute and breathe ♡")
		return
	}

	var body struct {
		Password string `json:"password"`
	}
	if err := decode(r, &body); err != nil {
		writeErr(w, 400, "Bad request.")
		return
	}

	if !a.cfg.passwordOK(strings.TrimSpace(body.Password)) {
		writeErr(w, 401, "That's not it… try again ♡")
		return
	}

	a.limiter.reset(ip)
	a.cfg.setUnlockCookie(w)
	writeJSON(w, 200, map[string]bool{"ok": true})
}

// --- POST /api/answer -------------------------------------------------

func (a *api) handleAnswer(w http.ResponseWriter, r *http.Request) {
	if !a.cfg.isUnlocked(r) {
		writeErr(w, 401, "Locked.")
		return
	}

	var body struct {
		Answer string `json:"answer"`
	}
	if err := decode(r, &body); err != nil {
		writeErr(w, 400, "Bad request.")
		return
	}

	ans := Answer(strings.ToLower(strings.TrimSpace(body.Answer)))
	if ans != AnswerYes && ans != AnswerNo {
		writeErr(w, 400, "Unknown answer.")
		return
	}

	res, err := a.store.Set(ans)
	if err == ErrLockedIn {
		// Yes is already locked in — just echo it back happily.
		writeJSON(w, 200, map[string]any{"answer": res.Record.Answer, "at": res.Record.At, "changed": false})
		return
	}
	if err != nil {
		log.Printf("answer: store error: %v", err)
		writeErr(w, 500, "Something went wrong saving that.")
		return
	}

	if res.Changed {
		go a.notifier.Notify(res)
	}

	writeJSON(w, 200, map[string]any{
		"answer":  res.Record.Answer,
		"at":      res.Record.At,
		"changed": res.Changed,
	})
}

// --- helpers ---------------------------------------------------------

func decode(r *http.Request, dst any) error {
	defer r.Body.Close()
	dec := json.NewDecoder(http.MaxBytesReader(nil, r.Body, 4<<10))
	return dec.Decode(dst)
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}

func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		first, _, _ := strings.Cut(xff, ",")
		return strings.TrimSpace(first)
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start).Round(time.Millisecond))
	})
}

// --- tiny per-IP rate limiter --------------------------------------

type limiter struct {
	mu     sync.Mutex
	hits   map[string][]time.Time
	max    int
	window time.Duration
}

func newLimiter(max int, window time.Duration) *limiter {
	return &limiter{hits: map[string][]time.Time{}, max: max, window: window}
}

func (l *limiter) allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-l.window)
	kept := l.hits[key][:0]
	for _, t := range l.hits[key] {
		if t.After(cutoff) {
			kept = append(kept, t)
		}
	}
	if len(kept) >= l.max {
		l.hits[key] = kept
		return false
	}
	l.hits[key] = append(kept, now)
	return true
}

func (l *limiter) reset(key string) {
	l.mu.Lock()
	delete(l.hits, key)
	l.mu.Unlock()
}
