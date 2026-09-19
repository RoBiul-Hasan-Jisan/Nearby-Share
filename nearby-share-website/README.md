# Nearby Share website

One-page Next.js (App Router, TypeScript) site that explains what the app does, plus a privacy policy page at `/privacy`.

## Run it

```bash
npm install
npm run dev        # http://localhost:3000
npm run build && npm start
```

Needs Node 18.18+ and an internet connection the first time (fonts are fetched from Google Fonts at build time).

## Edit it

- `lib/config.ts`: app name, **Google Play link** (paste it when published; the button switches automatically), **contact email**, policy date.
- `app/page.tsx`: all the copy (steps, features, FAQ).
- `app/privacy/page.tsx`: privacy policy. A plain-language starting point, not legal advice. Update it if you ever add analytics, ads or a server.
- `app/globals.css`: colors and spacing are the variables at the top.

## Deploy (free)

Push to GitHub, then import the repo at vercel.com. No settings needed. Add your own domain there if you have one.
Google Play needs the public URL of `/privacy` when you submit the app.
