package internal

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Answer is one of the two outcomes.
type Answer string

const (
	AnswerYes Answer = "yes"
	AnswerNo  Answer = "no"
)

func (a Answer) valid() bool { return a == AnswerYes || a == AnswerNo }

// Record is the shape persisted to answer.json.
type Record struct {
	Answer  Answer  `json:"answer"`
	At      string  `json:"at"`
	History []Entry `json:"history"`
}

// Entry is a single historical answer, kept so a "no" that later flips to "yes"
// is still legible after the fact.
type Entry struct {
	Answer Answer `json:"answer"`
	At     string `json:"at"`
}

// ErrLockedIn is returned when a "yes" is already on record: yes is final,
// there is no taking it back (and no reason to).
var ErrLockedIn = errors.New("already answered yes")

// Store is a mutex-guarded flat-file store for the single answer record.
type Store struct {
	mu   sync.Mutex
	path string
	rec  *Record
}

// NewStore opens (or prepares) the JSON store inside dir.
func NewStore(dir string) (*Store, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	s := &Store{path: filepath.Join(dir, "answer.json")}

	b, err := os.ReadFile(s.path)
	switch {
	case errors.Is(err, os.ErrNotExist):
		// no answer yet
	case err != nil:
		return nil, err
	default:
		var r Record
		if err := json.Unmarshal(b, &r); err != nil {
			return nil, err
		}
		if r.Answer.valid() {
			s.rec = &r
		}
	}
	return s, nil
}

// Current returns a copy of the stored record, or nil if unanswered.
func (s *Store) Current() *Record {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.rec == nil {
		return nil
	}
	cp := *s.rec
	cp.History = append([]Entry(nil), s.rec.History...)
	return &cp
}

// SetResult reports what a Set call did.
type SetResult struct {
	Record  *Record
	Changed bool // wrote something new
	FromNo  bool // this call flipped a prior "no" into a "yes"
}

// Set records an answer. Rules:
//   - first answer: stored as-is
//   - "no" already on record, new "yes": flip it (she changed her mind)
//   - "no" already on record, new "no": no-op
//   - "yes" already on record: ErrLockedIn
func (s *Store) Set(a Answer) (SetResult, error) {
	if !a.valid() {
		return SetResult{}, errors.New("invalid answer")
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC().Format(time.RFC3339)

	if s.rec != nil {
		switch {
		case s.rec.Answer == AnswerYes:
			cp := *s.rec
			return SetResult{Record: &cp}, ErrLockedIn
		case s.rec.Answer == AnswerNo && a == AnswerNo:
			cp := *s.rec
			return SetResult{Record: &cp, Changed: false}, nil
		}
	}

	fromNo := s.rec != nil && s.rec.Answer == AnswerNo && a == AnswerYes

	rec := &Record{Answer: a, At: now}
	if s.rec != nil {
		rec.History = append(rec.History, s.rec.History...)
		rec.History = append(rec.History, Entry{Answer: s.rec.Answer, At: s.rec.At})
	}

	if err := s.persist(rec); err != nil {
		return SetResult{}, err
	}
	s.rec = rec

	cp := *rec
	cp.History = append([]Entry(nil), rec.History...)
	return SetResult{Record: &cp, Changed: true, FromNo: fromNo}, nil
}

// persist writes the record atomically (temp file + rename).
func (s *Store) persist(r *Record) error {
	b, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return err
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, s.path)
}
