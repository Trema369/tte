package internal

import (
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"net/http"
)

// The cookie value is a fixed marker plus its HMAC, so we can verify it came
// from us without any server-side session storage.
const cookieMarker = "unlocked.v1"

func sign(secret []byte, msg string) string {
	m := hmac.New(sha256.New, secret)
	m.Write([]byte(msg))
	return base64.RawURLEncoding.EncodeToString(m.Sum(nil))
}

func cookieValue(secret []byte) string {
	return cookieMarker + "." + sign(secret, cookieMarker)
}

func validCookie(secret []byte, value string) bool {
	want := cookieValue(secret)
	return subtle.ConstantTimeCompare([]byte(value), []byte(want)) == 1
}

// setUnlockCookie writes the signed unlock cookie onto w.
func (c Config) setUnlockCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     c.CookieName,
		Value:    cookieValue(c.CookieSecret),
		Path:     "/",
		MaxAge:   60 * 60 * 24 * 30, // 30 days
		HttpOnly: true,
		Secure:   c.Prod,
		SameSite: http.SameSiteLaxMode,
	})
}

// isUnlocked reports whether the request carries a valid unlock cookie.
func (c Config) isUnlocked(r *http.Request) bool {
	ck, err := r.Cookie(c.CookieName)
	if err != nil {
		return false
	}
	return validCookie(c.CookieSecret, ck.Value)
}

// passwordOK does a constant-time comparison of the submitted password.
func (c Config) passwordOK(submitted string) bool {
	return subtle.ConstantTimeCompare([]byte(submitted), []byte(c.Password)) == 1
}
