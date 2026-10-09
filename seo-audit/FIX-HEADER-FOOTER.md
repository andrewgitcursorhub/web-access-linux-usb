# Making your header and footer visible to Google

No server rendering. No GitHub. No build pipeline. This is the version that fits how you
actually work.

---

## What is actually wrong (plain English)

Your pages ship this and nothing else where the navigation should be:

```html
<div id="header-placeholder"></div>
...
<div id="footer-placeholder"></div>
```

`assets/app.js` then fetches `/partials/header` and `/partials/footer` in the browser and drops
the markup in. A human sees a full navigation. **Googlebot's first pass sees two empty divs.**

Google *can* run JavaScript and recover that — except your `robots.txt` currently says:

```
Disallow: /partials/
```

which forbids it from fetching the two files it would need. So it fails both ways:

| | Can Google see your nav? |
|---|---|
| Raw HTML (first pass) | No — the divs are empty |
| After rendering JavaScript | No — robots.txt blocks the fetch |

That is why your 32 header links and 34 footer links are invisible. Measured on the live site
right now, this is what Google can actually see per page:

| Page | Internal links visible |
|---|---|
| `/privacy` | 2 |
| `/sitemap` | 2 |
| `/terms` | 3 |
| `/schedule-pickup-form` | 4 |
| `/about/locations` | 7 |
| median across all 34 | 19 |

Once the nav is in the HTML those same pages carry **37–46**. Your site structure effectively
does not exist to Google today.

I checked both partials and they are completely safe to inline: no `<script>`, no `<style>`,
no relative paths, no `<html>/<head>/<body>` wrappers, 8 unique IDs in the header and none in
the footer so nothing collides, and all 35 nav links return HTTP 200 directly.

---

## Step 1 — one line, one minute, do it right now

Open `robots.txt` and delete this line:

```
Disallow: /partials/
```

Leave the rest alone. Upload.

That single edit lets Google render the nav again. It is not the full fix — rendering is queued,
delayed, and unreliable on a small site — but it gets you most of the way back today while you
do Step 2. **Do not skip it just because Step 2 is coming.**

Keep the `X-Robots-Tag: noindex` on `/partials/*` in `_headers`. That part is correct: it stops
the fragments being indexed as junk pages while still letting Googlebot fetch them.

---

## Step 2 — put the header and footer in the HTML

### Option A — run the script (recommended, ~2 minutes)

PowerShell is already on your Windows machine. Nothing to install.

1. Put `inline-partials.ps1` in the folder that contains your site (the one with `index.html`
   and the `partials` subfolder).
2. Open PowerShell in that folder: shift-right-click the folder → "Open PowerShell window here".
3. If Windows blocks scripts, run this first — it only affects this one window:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Preview, then run:
   ```powershell
   .\inline-partials.ps1 -Source . -Check
   .\inline-partials.ps1 -Source .
   ```

It writes a `.bak` next to every file it touches. It is safe to run twice — a page that is
already inlined gets skipped, so you will never end up with two headers.

Tested against a 6-page mirror of your live site: 6/6 filled, re-run reported 0 filled and 6
already done, all 15 JSON-LD blocks still parsed, and internal links went 30 → 46 on the
homepage, 13 → 40 on `/services`, 11 → 41 on `/contact`.

### Option B — do it by hand

36 pages, two edits each. Tedious but completely safe, and it is exactly what the script does.

On every page, find this:

```html
<div id="header-placeholder"></div>
```

and change it to this, pasting the entire contents of `partials/header.html` in the middle:

```html
<div id="header-placeholder">
  ...paste everything from partials/header.html here...
</div>
```

Then the same for the footer:

```html
<div id="footer-placeholder">
  ...paste everything from partials/footer.html here...
</div>
```

If your local partials have drifted from what is live, I saved known-good copies pulled from
your site on 2026-10-09:

```
fixes/partials/header-to-inline.html   (20,247 bytes)
fixes/partials/footer-to-inline.html   (11,837 bytes)
```

### The one rule that matters either way

**Keep the wrapper `<div>`s. Fill them, do not replace them.**

Two things in `app.js` depend on those wrappers existing. I pulled the exact live code:

```js
function loadPartial(id, url, callback) {
    const el = document.getElementById(id);
    if (!el) return;              // <-- delete the div and this bails out
    ...
}

function adjustFooter() {
    const footer = document.querySelector('#footer-placeholder .site-footer');
    if (!footer) return;          // <-- needs the wrapper to still be there
    ...
}
```

If you delete `<div id="header-placeholder">`, `loadPartial` returns early, `initHeaderChrome()`
never runs, and **your mobile menu button stops working**. If you delete the footer wrapper,
`adjustFooter()` stops and footer spacing breaks on short pages. Filling the divs avoids both.

---

## Step 3 — stop the browser re-downloading what is now in the page

Without this the pages work, but every visitor still fetches both partials and `app.js`
overwrites the nav you just inlined. Two wasted round-trips per page load.

In `assets/app.js`, find `loadPartial` and add the middle block. Everything else stays:

```js
function loadPartial(id, url, callback) {
    const el = document.getElementById(id);
    if (!el) return;

    // Already inlined in the HTML. Skip the fetch, but still run the callback
    // so initHeaderChrome() and adjustFooter() wire up exactly as before.
    if (el.children.length > 0) {
      if (typeof callback === 'function') callback(el);
      return;
    }

    fetch(url)
      .then((res) => res.text())
      .then((html) => {
        el.innerHTML = html;
        if (typeof callback === 'function') callback(el);
      })
      .catch((err) => console.error('Error loading', url, err));
  }
```

This degrades safely. If the inlining ever fails to run, the divs arrive empty,
`el.children.length` is 0, and the old fetch path runs exactly as today. You cannot end up with
a page that has no navigation.

---

## Step 4 — check it before you upload

Open any page locally in a browser and confirm:

- Navigation renders
- **Mobile menu button opens and closes** (this is what breaks if you delete the wrappers)
- Footer sits correctly on a short page like `/terms`
- Right-click → View Source, and search for a nav link such as `/services/data-destruction`.
  It must appear in the **source**, not just in DevTools' Elements panel. Elements shows the
  rendered DOM; View Source shows what Googlebot gets first.

Then upload and run:

```powershell
.\verify.ps1 -Only P2-1
```

You want the homepage reporting 40+ internal links in raw HTML.

---

## The trade-off, stated plainly

After this, the header and footer are copied into all 36 pages. Editing `partials/header.html`
no longer updates the site by itself — you re-run the script (or re-paste) and re-upload.

At 36 pages that is the right trade: a two-minute script run buys you a navigation Google can
actually see. Revisit it if you pass roughly 100 pages.

---

## Why this is worth doing before anything else

Internal linking is how PageRank moves through a site and how Google learns which of your pages
matter. With the nav invisible, every page looks nearly orphaned, your hub-and-spoke structure
through `/services` and `/industries-served` does not exist, and `/faqs` — your single biggest
content asset at 2,842 words — has **one** inbound link that Google can see.

That is not a ranking tweak. It is the difference between having a site architecture and not
having one.
