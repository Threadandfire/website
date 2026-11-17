# Thread & Fire · working prototype

## Run
Requires Node.js 18 or newer. No npm packages, paid services, or API keys.

```bash
node server.js
```
Open http://localhost:3000

## What works
- Responsive dark editorial homepage, category navigation, article reader, ad placeholders.
- Server-side live GDELT DOC 2.0 discovery for five sections; fallback to clearly labeled sample articles if source is unavailable.
- Studio panel: discover source headlines, inspect editorial outlines, save drafts and mark as published.
- Basic HTML escaping, request timeout, external links, no API keys.

## Important limitations
- The article body is a **template-based editorial outline**, not AI-generated verified reporting. It deliberately does not invent facts from a headline.
- Drafts are in server memory only, and reset on restart. No user accounts or persistence.
- Live GDELT availability depends on their rate limits and network. No TikTok integration yet: official endpoints require business permissions.
- Ads are **placements only**, not a live ad-network integration. Newsletter is intentionally disabled.
- The prototype is not production hardened: add a database, authentication, moderation, attribution, rate limiting, proper SEO, privacy/cookie policies and editorial review before launch.
- GDELT returns links and metadata, not licensing to reproduce publishers' full text or images. Verify rights before public commercial use.

## Suggested next phase
Cloudflare Pages/Workers or a small Node host, Supabase/Postgres for durable content, admin login, scheduled ingestion, deduplication and source clustering, LLM-assisted drafts based on licensed/accessible source facts with citations, human approval, then ads.

Data attribution: https://www.gdeltproject.org/

## Version 0.2: persistent editorial workflow
- Saved articles persist in `data/articles.json` across server restarts (local JSON store, not a hosted database).
- Article statuses: `draft → approved → published`; reject and unpublish actions are supported.
- Edit article headline/body in Studio. A placeholder outline cannot be approved unchanged.
- `/api/published` serves only published articles. The homepage shows published stories plus clearly labeled demonstration/source discovery content.
- Server binds to `127.0.0.1` by default. **Do not expose this server publicly**: there is no admin authentication, CSRF protection, or production-ready access control. Build authentication before deploying or connecting a mobile approval app.
- No AI generation, autonomous publishing, real ad network, or phone app yet. No paid services.
