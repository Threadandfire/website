# Spool & Ember: first data-backed prototype

Contains a static site and 10 normalized TikTok trend signals from the supplied Apify export. No external TikTok video files are stored. No articles or claims have been independently verified.

To run locally: `python3 -m http.server 8000` inside this folder, then visit http://localhost:8000. Or upload both index.html and feed.json to GitHub Pages / Cloudflare Pages.

The original source URLs are constructed from the TikTok usernames and video IDs. Source images are omitted because signed CDN URLs can expire.
