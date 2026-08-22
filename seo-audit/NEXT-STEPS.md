# Remediation status and remaining steps

Re-verified against the live site **2026-08-22**. Harness: `./verify.sh`, which now reports
**15 passed / 25 failed**.

Do not read that against the original 2 passed / 35 failed — this run uses a stricter harness.
I split P0-4 into five separate assertions and P1-1 into nine after both produced misleading
results the first time, so the totals are not comparable. Compare the item table below instead.

Substantively: eleven items are now fixed, including three of the four P0s. The fourth (P0-4)
did not fail safely and needs attention first.

---

## Status at a glance

| Item | Status | Notes |
|---|---|---|
| P0-1 `Recycling Center` → `RecyclingCenter` | **Fixed** | Homepage now declares a valid `RecyclingCenter` |
| P0-2 Invalid JSON-LD on `/specialty-equipment-we-handle` | **Fixed** | All blocks parse |
| P0-3 `/sustainability` in sitemap | **Fixed** | 34 URLs, all return 200 directly |
| P0-4 `www` DNS + redirect | **BROKEN — new bug** | Redirects every URL to a literal `/:splat`, which 404s. See §1 |
| P1-1 Query-string 302s | **Overstated in my original report** | Only `?ref=` is affected, not all query strings. See §2 |
| P1-2 `/404` returns 200 | **Not fixed** | robots.txt block is a workaround, not a fix. See §3 |
| P1-3 `Certificate-Of-Destruction.pdf` 404 | **Not fixed** | Still 404s from two industry pages |
| P1-4 `/partials/` indexable | **Partly fixed — now causing a regression** | See §4 |
| P1-6 Orphan pages in sitemap | **Fixed** | `/privacy`, `/terms`, `/sitemap` all present |
| P1-7 Sitemap `lastmod` | **Fixed** | Present |
| P2-1 Client-side header/footer | **Not started** | Full steps in §5 |
| P2-2 `sameAs` social profiles | **Not fixed** | Still LinkedIn only; 3 missing |
| P2-3 NAP consistency | **Fixed** | Both pages now `457 S Cooper Ave.` |
| Canonical integrity | **Fixed** | All 34 sitemap URLs self-canonicalise |
| Internal links to redirects/404s | **Not fixed** | 13 links across 11 pages |

Sitemap and canonicals are clean. Good.

---

## §1 — P0-4 is not fixed. The www redirect sends everyone to a 404.

The CNAME worked: `www.core-asset-sol.com` resolves, TLS covers it (`*.core-asset-sol.com`),
and it returns a 301. But look at where the 301 points:

```
GET https://www.core-asset-sol.com/            ->  301  ->  https://core-asset-sol.com/:splat
GET https://www.core-asset-sol.com/contact     ->  301  ->  https://core-asset-sol.com/:splat
GET https://www.core-asset-sol.com/services/itad -> 301  ->  https://core-asset-sol.com/:splat

GET https://core-asset-sol.com/:splat          ->  404
```

`:splat` is being emitted **literally**. Every www URL — no matter the path — redirects to
the same nonexistent `/:splat` URL, which 404s.

This is why my first verification pass reported PASS: it only checked that the status was
301. That was a gap in my harness and I have fixed it — `verify.sh` now follows the redirect,
confirms the path is preserved, checks for uninterpolated placeholders, and confirms the
destination returns 200.

### Why it is happening

`:splat` is `_redirects` syntax. It only interpolates inside a Cloudflare Pages `_redirects`
file. Your www redirect is not running there — the response headers give it away:

| | www 301 response | a normal Pages response |
|---|---|---|
| `cf-cache-status` | absent | `DYNAMIC` |
| `access-control-allow-origin` | absent | `*` |
| `content-type` | `text/html; charset=UTF-8` | `text/html; charset=utf-8` |

That is a **Cloudflare Redirect Rule** executing at the edge, before Pages is reached. And it
could not have been in `_redirects` anyway — Cloudflare Pages explicitly does not support
domain-level redirects there, because `_redirects` cannot match on hostname.

So: `_redirects`-style syntax was pasted into a Cloudflare Redirect Rule set to **Static**,
and a static target is emitted verbatim.

### The fix

Cloudflare dashboard → select the `core-asset-sol.com` zone → **Rules** → **Redirect Rules** →
edit the www rule.

**If** (custom filter expression):
```
(http.host eq "www.core-asset-sol.com")
```

**Then** — change the type from *Static* to **Dynamic**, and use this expression:
```
concat("https://core-asset-sol.com", http.request.uri.path)
```

- Status code: **301**
- Preserve query string: **ON**

Setting it to Dynamic is the whole fix. `concat()` builds the target per-request from the
actual path; a Static URL cannot.

### Also fix: `http://www` returns 522

```
http://www.core-asset-sol.com/   ->  522   (Cloudflare connection timed out)
http://core-asset-sol.com/       ->  301   (correct, this is the apex)
```

Port 80 on www is not matching the rule, so Cloudflare falls through to an origin that is not
there. Make sure the rule's expression matches on hostname only — do **not** add a
`ssl`/scheme condition — and confirm the www DNS record is **proxied** (orange cloud), not
DNS-only. Then verify with:

```bash
curl -sSI http://www.core-asset-sol.com/  | grep -iE '^(HTTP|location)'
curl -sSI https://www.core-asset-sol.com/contact | grep -iE '^(HTTP|location)'
```

You want `301` and `location: https://core-asset-sol.com/contact` — the real path, not
`:splat`.

> **Priority note.** Fix this before anything else in this document. Right now www resolves,
> so Google *will* crawl it, follow the 301, and index a 404 where previously it just saw a
> DNS failure. A broken redirect that resolves is more harmful than a hostname that does not.

---

## §2 — P1-1: I overstated this. Correcting it.

My original report said "33 query-string URLs return 302 instead of 301." That generalised
from a single `?ref=x` probe, and it was wrong. Retested across a spread of parameters:

| Query string | Status |
|---|---|
| `?ref=x` | **302** |
| `?REF=x`, `?Ref=x` | 200 |
| `?utm_source=g` | 200 |
| `?utm_source=g&utm_medium=cpc` | 200 |
| `?gclid=abc` | 200 |
| `?fbclid=xyz` | 200 |
| `?msclkid=q` | 200 |
| `?page=2`, `?id=1`, `?a=1&b=2` | 200 |
| `?referrer=`, `?referer=`, `?source=`, `?src=`, `?from=`, `?aff=`, `?campaign=`, `?r=` | 200 |

**Only the exact lowercase parameter `ref` triggers a redirect.** Everything else — including
every ad-platform click ID and all your `utm_*` campaign tracking — already returns 200 with a
correct self-referencing canonical. That is exactly the behaviour you want, and it is already
working.

The rule is surgical: it strips only `ref` and preserves everything else.

```
?ref=x               ->  302  ->  /services
?a=1&ref=x&b=2       ->  302  ->  /services?a=1&b=2
?utm_source=g&ref=x  ->  302  ->  /services?utm_source=g
```

### So what should you actually do?

**Downgrade this to low priority.** Real-world impact is close to zero unless something
external links to you with `?ref=`. It is a cleanup item, not an SEO problem.

### How to decide the right fix (you asked for the method)

The decision rule for any query parameter:

| Does the parameter change the page content? | Correct handling |
|---|---|
| **No** — tracking only (`utm_*`, `gclid`, `fbclid`, `ref`) | **Serve 200 + self-referencing canonical.** Never redirect |
| **Yes** — pagination, filters, search (`?page=2`) | Serve 200, canonical to *itself*, not the bare URL |
| Parameter is genuinely dead/retired | 301 to the clean URL |

`ref` falls in the first row, so the ideal handling is 200 + canonical — which is what every
other parameter already does. Redirecting is worse than not redirecting, because it discards
the referral data before your analytics can read it and adds a round-trip.

### To remove it

Cloudflare dashboard → zone → **Rules** → **Redirect Rules**. Look for a rule referencing
`ref` — likely a dynamic expression using `http.request.uri.query`. Also check
**Bulk Redirects** and **Transform Rules → Rewrite URL**.

- **Preferred:** delete the rule. `ref` then behaves like `utm_source` — 200 with a
  self-canonical, no signal loss, and referral data reaches your analytics.
- **If you deliberately want `ref` stripped** (some teams do, to keep it out of analytics),
  change the status code from **302 to 301**. Keep the parameter-preserving behaviour.

Either is defensible. Deleting it is simpler and more consistent with how the other 20+
parameters already behave.

---

## §3 — P1-2: making `/404` return a real 404

Your custom error page is already wired up correctly. Unknown URLs return a genuine 404 with
your branded page — I diffed `/404` against `/definitely-not-a-real-page-zzz` and the bodies
are identical except for the Cloudflare Analytics beacon, which is only injected on 200
responses. That part is right.

The only defect: the template is *also* directly addressable at `/404`, where it returns 200.

### Why robots.txt is not the fix

You currently have:

```
Disallow: /404
Disallow: /404.html
```

This hides the symptom rather than fixing it, and it has a side effect: a `Disallow` stops
Googlebot from fetching the URL at all, so Google can never observe the 404 status that would
tell it to drop the URL. Blocked URLs move from the "Soft 404" bucket to the "Blocked by
robots.txt" bucket — still "not indexed", just filed differently.

### Why `_redirects` cannot do it

Cloudflare Pages supports only **301, 302, 303, 307 and 308** in `_redirects`. A line like
`/404 /404 404` is silently ignored — no warning, no error. Status codes outside 3xx require a
Pages Function.

### The fix

Add [`fixes/functions/404.js`](fixes/functions/404.js) to your repo at `functions/404.js`
(project root, alongside your source — not inside the build output directory).

**Critical: do not make this a catch-all.** From Cloudflare's docs: *"Redirects defined in the
`_redirects` file are not applied to requests served by Pages Functions, even if the Function
route matches the URL pattern."* If you name it `functions/[[path]].js` it intercepts every
request and your entire `_redirects` file stops working — including all your `.html` redirects.
Naming it `functions/404.js` scopes it to the single `/404` route.

Then **remove** `Disallow: /404` and `Disallow: /404.html` from robots.txt. Once the URL
returns a real 404, the block is unnecessary and counterproductive.

`/404.html` will continue to 308 to `/404`, which will then return 404. A 308 landing on a 404
is fine and needs no further handling.

Verify:
```bash
curl -sSI https://core-asset-sol.com/404 | head -1     # want: HTTP/2 404
curl -sSI https://core-asset-sol.com/nope-xyz | head -1 # want: HTTP/2 404
```

---

## §4 — P1-4: partly fixed, and currently causing a regression

Both halves are confirmed live:

```
/partials/header  ->  200,  x-robots-tag: noindex, nofollow
/partials/footer  ->  200,  x-robots-tag: noindex, nofollow
robots.txt        ->  Disallow: /partials/
```

**But doing both at once is self-defeating, and right now it is actively hurting you.**

### Problem 1 — the two directives cancel out

`Disallow` prevents Googlebot from **fetching** the URL. If it never fetches, it never sees the
`X-Robots-Tag: noindex` response header. The noindex is inert. Already-indexed partial URLs can
persist as URL-only listings that you now have no mechanism to remove.

This is my fault — my original `_headers` file said to deploy noindex first and add the
Disallow only after Google had dropped the URLs, but that sequencing note was easy to miss.
The ordering is the whole point.

### Problem 2 — this is the serious one

Your header and footer are **still** client-side injected. Confirmed live: `header-placeholder`
and `footer-placeholder` are both present, and the served HTML contains **zero** `<nav>` and
**zero** `<footer>` elements.

Googlebot's renderer was the *only* remaining way it could discover your navigation — it would
run `app.js`, fetch `/partials/header` and `/partials/footer`, and see the nav links.

**`Disallow: /partials/` now blocks that fetch.**

So as of today Google sees no navigation at all: not in the raw HTML, and not after rendering
either. Before this change, rendering at least worked. This is a regression.

### The fix, in order

**1. Right now — remove the Disallow, keep the noindex.**

```diff
  User-agent: *
  Allow: /
- Disallow: /partials/
  Disallow: /cdn-cgi/
```

Keep `X-Robots-Tag: noindex` in `_headers`. That combination is correct: Googlebot *can* fetch
the partials (so rendering works and nav links stay discoverable) and *will* see the noindex
header (so the fragment URLs get dropped from the index). Blocking crawl is the one thing you
do not want here.

**2. Then ship P2-1 (§5).** Once the header and footer are inlined at build time, nothing
fetches `/partials/*` at runtime.

**3. Then delete the partials from the build output entirely.** Once they are inlined and
`app.js` no longer fetches them, `/partials/header` and `/partials/footer` should not be
published URLs at all. `inline-partials.mjs` already excludes `partials/` from the output
directory, so this happens automatically. At that point the URLs return 404 and P1-4 is fully
closed — no robots.txt rule and no `X-Robots-Tag` needed, because there is nothing to crawl.

**So: is it fully fixed?** No. And the best fix is not robots.txt or noindex — it is removing
the URLs from existence via P2-1. The noindex is the correct interim step; the Disallow should
come off today.

---

## §5 — P2-1: server-rendering the header and footer

This is the highest-value remaining item and it is smaller than it sounds. You do not need a
framework migration or a Pages Function. Your site is hand-authored static HTML with one
header and one footer, and every page uses identical placeholder markup:

```html
<div id="header-placeholder"></div>
<div id="footer-placeholder"></div>
```

Verified identical across `/`, `/services`, `/services/itad`, `/faqs`, `/contact`,
`/about/locations`, `/privacy`, and `/terms`. That consistency makes build-time inlining
straightforward and reliable.

### The approach

Add a build step that fills those two divs with the real partial contents before Cloudflare
Pages publishes. You keep your current workflow exactly — edit `partials/header.html` once,
every page picks it up — but the navigation ships in the HTML.

I wrote and tested the script:
[`fixes/build/inline-partials.mjs`](fixes/build/inline-partials.mjs)

### Two details that matter

I tested against a local mirror of your live site and found two things that would have broken
the site if handled naively.

**1. Fill the div, do not replace it.** `adjustFooter()` in `app.js` selects
`'#footer-placeholder .site-footer'`. Replace the wrapper and that selector stops matching and
footer spacing silently dies. The script fills the div and leaves the wrapper in place.

**2. The callbacks must still run.** `loadPartial()` starts with:

```js
const el = document.getElementById(id);
if (!el) return;
```

so it no-ops safely if the div is gone — but then `initHeaderChrome()` never runs and **your
mobile menu button stops working**. The companion patch handles this. It is three lines:

```js
function loadPartial(id, url, callback) {
  const el = document.getElementById(id);
  if (!el) return;

  // Already inlined at build time. Skip the fetch, still run the callback.
  if (el.children.length > 0) {
    if (typeof callback === 'function') callback(el);
    return;
  }

  fetch(url) /* ...unchanged... */
}
```

Full explanation: [`fixes/build/app.js.patch.md`](fixes/build/app.js.patch.md). It degrades
safely — if the build step ever fails to run, the placeholders arrive empty and the old fetch
path runs exactly as it does today. You cannot end up with a page that has no navigation.

### Steps

1. Copy `inline-partials.mjs` into your repo at `build/inline-partials.mjs`.
2. Apply the three-line `loadPartial` change to `assets/app.js`.
3. Test locally:
   ```bash
   node build/inline-partials.mjs --src . --out dist
   npx serve dist        # click through, check the mobile menu and footer spacing
   ```
4. In the Cloudflare Pages dashboard → your project → **Settings** → **Builds & deployments**:
   - Build command: `node build/inline-partials.mjs --src . --out dist`
   - Build output directory: `dist`
5. Deploy to a preview branch first and verify:
   ```bash
   curl -s https://<preview>.pages.dev/ | grep -c 'id="header-placeholder"></div>'  # want 0
   curl -s https://<preview>.pages.dev/ | grep -c '<nav'                            # want > 0
   ```
6. Promote to production, then remove `Disallow: /partials/` per §4.
7. Optional CI guard — fails the build if a placeholder is ever left empty:
   ```bash
   node build/inline-partials.mjs --src dist --check
   ```

### Tested results

Run against a 21-page local mirror of your live site:

```
HTML files    21
Injected into 21
header.html   20247 bytes
footer.html   11837 bytes
```

| Page | Internal links before | after |
|---|---|---|
| `/` | 30 | **46** |
| `/services` | 13 | **40** |
| `/faqs` | 23 | **44** |
| `/contact` | 11 | **41** |
| `/privacy` | 3 | **38** |
| `/terms` | 3 | **37** |

Also verified: 0 placeholders left unfilled, `<nav>` and `<footer>` elements now present,
`aria-current="page"` correctly marks the active nav item, all **53** JSON-LD blocks still
parse, and re-running the build injects 0 (idempotent, safe in CI).

`/terms` and `/privacy` going from 3 to 37+ inbound-link-bearing pages is the headline. Those
pages were effectively orphaned; after this they are properly wired into the site.

### Files the script does not touch

`assets/`, PDFs, `robots.txt`, `sitemap.xml`, `_redirects`, and `_headers` are copied through
unchanged. `partials/` is deliberately excluded from the output.

---

## §6 — Smaller items still open

**P1-3 — the 404ing PDF.** Still live, still linked from `/industries-served/education` and
`/industries-served/healthcare`:

```
/resources/Certificate-Of-Destruction.pdf   ->  404   (hyphens)
/resources/Certificate_Of_Destruction.pdf   ->  200   (underscores — the real file)
```

Fix the two `href` values. The `_redirects` rule I supplied catches anything already shared
externally, but the internal links should point at the real file.

**P2-2 — `sameAs` still lists only LinkedIn.** Facebook, Instagram, and X are all live (all
return 200) and all linked from your footer. Add all four to the homepage `RecyclingCenter`
node — they are already in
[`fixes/schema/homepage-organization.jsonld`](fixes/schema/homepage-organization.jsonld).

**Internal links pointing at redirects.** 13 links across 11 pages:

| Target | Status | Count |
|---|---|---|
| `/resources/sample-certificate-of-media-sanitization.pdf` | 301 | 9 pages |
| `/resources/Certificate-Of-Destruction.pdf` | 404 | 2 pages |
| `/industries` | 301 | 1 page |
| `/privacy.html` | 301 | 1 page |

Point each at its final destination. Keep the redirects for external links.

---

## Suggested order

1. **§1 — fix the www Redirect Rule.** Today. It currently sends every www visitor and
   crawler to a 404.
2. **§4 step 1 — remove `Disallow: /partials/`.** One line, reverses the nav-discovery
   regression immediately.
3. **§5 — build-time inlining.** The big structural win.
4. **§6 — the PDF link, `sameAs`, and the redirect-pointing internal links.** All quick.
5. **§3 — the `/404` Pages Function.** Low impact, do it when convenient.
6. **§2 — the `ref` rule.** Lowest priority; near-zero real impact.

Re-run `./verify.sh` after each step.
