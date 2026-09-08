# prom 🌹

A one-question website: asks Harley to prom, and pings Discord the moment she answers.

- **`web/`** — Next.js 15 (App Router, TS), Tailwind v4, `motion`. Hand-rolled components, no shadcn.
- **`server/`** — Go (stdlib only). Checks the password, records the answer to a flat JSON file, fires the Discord webhook.

The frontend proxies `/api/*` to the Go service, so everything is same-origin and the unlock cookie just works.

## Screens

1. **Gate** — password. Wrong = gentle shake. Right = signed cookie, on to the ask.
2. **Ask** — "Harley, … Will you be my date to *prom?*"
   - **Yes, of course ♡** → yes outcome.
   - **I need a little time to think** → the button slips away from the cursor and shrinks; on the **3rd** try it gives up, registers the soft-no, plays `sad.mp3`, and shows the "I respect your decision" screen.
   - The no screen has a faint *"…wait, I changed my mind ♡"* link back to the ask. Yes is final once given.
3. **Yes** — "You said YES! ♡", the date (`13 November 2026`), a little note card, drifting hearts.
4. **No** — "That's okay… I respect your decision.", sad track, broken-heart mark.

Reloading always lands on the right screen (the server remembers).

## Run it locally

Two terminals:

```bash
# 1) backend  (http://localhost:8080)
cd server
SITE_PASSWORD=hiharley DISCORD_WEBHOOK_URL=... go run .

# 2) frontend (http://localhost:3000)
cd web
pnpm install
pnpm dev
```

Open http://localhost:3000. With no `DISCORD_WEBHOOK_URL` set, answers are still recorded — the webhook post is just skipped and logged.

The answer lives in `server/data/answer.json`. Delete it to reset and answer again.

## Config (environment)

| var | what | default if empty |
| --- | --- | --- |
| `SITE_PASSWORD` | the gate password | `hiharley` |
| `DISCORD_WEBHOOK_URL` | Discord Incoming Webhook URL | webhook skipped, answer still saved |
| `DISCORD_MENTION_ID` | your friend's Discord user ID, so the ping notifies him | no ping, embed only |
| `COOKIE_SECRET` | signs the unlock cookie — any long random string | random per boot (cookies reset on restart) |
| `PORT` | backend port | `8080` |
| `DATA_DIR` | where `answer.json` is written | `./data` (compose: `/data` volume) |
| `SERVER_ORIGIN` | where `web` reaches the backend | `http://localhost:8080` (compose sets `http://server:8080`) |

### Getting the Discord webhook

Server Settings → Integrations → Webhooks → **New Webhook** → pick the channel → **Copy Webhook URL**. Treat it like a password. For the ping: Discord → Settings → Advanced → **Developer Mode** on, then right-click your friend → **Copy User ID** → that's `DISCORD_MENTION_ID`.

## Deploy (Coolify)

1. New resource → **Docker Compose** → point at this repo. It builds `web` and `server`.
2. Set `SITE_PASSWORD`, `DISCORD_WEBHOOK_URL`, `DISCORD_MENTION_ID`, `COOKIE_SECRET` in the **Environment** tab.
3. Route your domain to the **`web`** service, port **3000**. Coolify handles TLS.
4. The `prom-data` volume keeps `answer.json` across redeploys.

Or plain Docker: `cp .env.example .env`, fill it in, `docker compose up -d --build`.

## Assets to drop in (all gitignored)

- **`web/public/audio/sad.mp3`** — the sad song for the no screen. [NCS](https://ncs.io) tracks are free **with attribution** — if you use one, credit it (e.g. in a code comment / the repo). No file → the screen just stays quiet.
- **`web/public/images/{gate,ask,yes,no}.jpg`** — real photos to replace the gradient backdrops. When you have them, swap the `.stage-*` classes in `web/components/Stage.tsx` for `style={{ backgroundImage: "url(/images/gate.jpg)" }}` etc. (keep the `bokeh` / `grain` / `vignette` layers for depth).

## Copy / date

Wording is lifted from the mockup. To change the prom date, edit `PROM_DATE` in `web/components/YesResult.tsx`. Screen text lives in `Ask.tsx`, `Gate.tsx`, `YesResult.tsx`, `NoResult.tsx`.
