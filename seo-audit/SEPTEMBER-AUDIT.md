# September re-audit — core-asset-sol.com

Live-site audit **2026-09-21**. All 34 sitemap pages crawled and parsed.

**Headline:** the live site is essentially unchanged since 22 August. None of your local-host
work has shipped, and the three things most responsible for suppressing local visibility are
all still live. The good news is that every one of them is fixable today without touching the
content you are still writing.

---

## 1. Fix these first — they are actively suppressing you

### 1.1 Google cannot see your navigation. At all.

This is the single biggest technical problem on the site and it has two halves that combine
badly:

```
All 34 pages still contain:  <div id="header-placeholder"></div>
                             <div id="footer-placeholder"></div>
assets/app.js fetches:       /partials/header  and  /partials/footer
robots.txt still says:       Disallow: /partials/
```

Googlebot's first pass sees no navigation, because the header and footer are injected by
JavaScript. Its *rendering* pass would normally recover them — except `Disallow: /partials/`
forbids it from fetching those two files.

So Google sees neither. Not in the raw HTML, not after rendering. Your 32-link header and
33-link footer are invisible to search.

The measurable effect, from the live crawl:

| Page | Internal links Google can see |
|---|---|
| `/privacy` | 2 |
| `/sitemap` | 2 |
| `/terms` | 3 |
| `/schedule-pickup-form` | 4 |
| `/about/locations` | 7 |
| median across all 34 | 19 |

After inlining, those same pages carry 37–46 links. Your site architecture currently does not
exist as far as Google is concerned.

**Two fixes, both today.** Remove the `Disallow: /partials/` line, and inline the header and
footer. Section 6 has the exact procedure for your setup.

### 1.2 Thirty-two of your thirty-four pages have no business identity

| Business entity on the page | Pages |
|---|---|
| Complete (`RecyclingCenter`/`LocalBusiness`/`Organization` **with an address**) | **2** — the homepage and `/contact` |
| Bare `provider` stub (name + url, no address) | 17 |
| Nothing at all | 15 |

Every service page, every industry page, and `/about/locations` has no address, no geo
coordinates, no hours, and no phone in its structured data. They are trying to rank for
"… in Cincinnati" queries while carrying zero local signals.

This is the `_business-node.jsonld` work from August that never shipped. It is a copy-paste job:
the same block goes into all 34 pages verbatim.

### 1.3 Your Google Business Profile is not linked in structured data

You asked directly. The answer is no.

- `hasMap`: present on **0 of 34** pages.
- Only 2 pages reference Google Maps at all, and neither correctly:
  - `/contact` links `google.com/maps/search/?api=1&query=457+South+Cooper+Ave+Cincinnati+OH+45215` — a **search** URL, not your listing. It also says "Cincinnati", not "Lockland".
  - `/about/client-testimonials` links `maps.app.goo.gl/6ZMMUcFeerorg5u6A` — which resolves to your Google **reviews** page. Good link, wrong page, and it is the only GBP reference on the whole site.
- `/about/locations` — the page that most needs it — has **no Google Maps link at all**. It renders a custom Leaflet/MapLibre map from OpenFreeMap instead, and carries **no `PostalAddress`, no `telephone`, no `geo`** in structured data.

The good news buried in that: the short link confirms you **do** have a live Google Business
Profile. Its place identifier is `0xba60e4bf353866ec`. Section 7 covers how to wire it up.

### 1.4 Your address disagrees with itself

| Where | Value |
|---|---|
| Homepage schema `addressLocality` | **Lockland** |
| `/contact` schema `addressLocality` | **Cincinnati** |
| Visible text on `/contact` and `/about/locations` | "457 **South** Cooper Ave" |
| Schema `streetAddress` on both pages | "457 **S** Cooper Ave." |

Four different renderings of one address. NAP consistency is a foundational local ranking
factor, and Google cross-references your markup against your visible text and against your
Google Business Profile. Right now none of those three agree.

My August check reported this as PASS. That was a gap in my harness — it compared
`streetAddress` only and never looked at `addressLocality`. I have fixed `verify.sh` so it now
compares every address field and also confirms the schema address appears verbatim in the
visible text.

### 1.5 `/faqs` declares 17 questions; 13 of the answers are not on the page

You spotted this and you are right. Measured on the live page:

```
FAQPage markup declares : 17 questions
Answer text actually in the rendered HTML : 4
Missing : 13
```

The 18 `<h3>` elements on that page are category headings — "Computing & Infrastructure",
"Mobile & Telecom", "Office Equipment", "Items We Do Not Accept" — not the questions.

This is a structured data guidelines violation: markup must describe content visible on the
page. Worth knowing it is **only `/faqs`**. I checked all 18 other FAQ blocks and every one has
all of its answers present in the HTML:

| Page | Questions | Answers visible |
|---|---|---|
| `/services/data-destruction` | 10 | 10 |
| `/services/decommissioning` | 9 | 9 |
| `/services/electronics-recycling` | 9 | 9 |
| all 8 industry pages | 7 each | 7 each |
| **`/faqs`** | **17** | **4** |

Your local-host rewrite (h3 = question, p = answer) fixes this. Until it ships, the safest
interim fix is to delete the `FAQPage` block from `/faqs` — the mismatched markup is worse than
no markup.

---

## 2. What is genuinely working better than in August

Real progress, worth recording:

| | Status |
|---|---|
| **www redirect** | **Fully fixed.** Was sending every www URL to a 404 via a literal `:splat`. Now 301s correctly with the path and query string preserved, on both HTTP and HTTPS. All 5 checks pass |
| **Sitemap** | 34 URLs, every one returns 200 directly, `lastmod` present, the three orphaned pages included |
| **Canonicals** | All 34 pages self-canonicalise correctly |
| **`RecyclingCenter` type** | Valid. The `"Recycling Center"` typo is gone |
| **`/specialty-equipment-we-handle`** | JSON-LD parses; the trailing comma and stray attribute are fixed |
| **Indexability** | 0 of 34 pages carry an accidental `noindex` |
| **Titles** | All 34 pages have a non-empty `<title>` |
| **Performance** | Genuinely good — 8–16 KB Brotli, 83–140 ms response. Not a problem |
| **FAQ answer visibility** | Correct on 18 of 19 FAQ pages |
| **Google Business Profile** | Exists and is live — a real improvement since August |

---

## 3. Still outstanding from last time

| # | Issue | Status |
|---|---|---|
| 1 | Header/footer client-side injected | **Not fixed** — all 34 pages |
| 2 | `Disallow: /partials/` blocking render | **Not fixed** — and it makes #1 worse |
| 3 | Business node not shipped site-wide | **Not fixed** — 2 of 34 |
| 4 | `hasMap` / GBP not linked | **Not fixed** — 0 of 34 |
| 5 | `sameAs` missing Facebook, Instagram, X | **Not fixed** — LinkedIn only, homepage only |
| 6 | `/404` returns HTTP 200 | **Not fixed** |
| 7 | `Certificate-Of-Destruction.pdf` 404s | **Not fixed** — still linked from `/industries-served/education` and `/healthcare` |
| 8 | 12 internal links point at redirects | **Not fixed** |
| 9 | `?ref=` returns 302 | **Not fixed** — low priority |
| 10 | Alt text | **Partly done.** `/industries-served/healthcare` 27/27 missing, `/industries-served` 12/12, `/services` 7/11, homepage 4/5. 51 of 56 sampled images still have none |
| 11 | `og:image` is the logo on every page | **Not fixed** |
| 12 | Hero images undersized and heavy | **Not fixed** |

## 4. Found this time that I had not flagged before

- **`addressLocality` mismatch** (Lockland vs Cincinnati) — my August check missed it.
- **Schema address does not match visible text** ("S" vs "South").
- **`/about/locations` has no address structured data whatsoever** — no `PostalAddress`, no
  `telephone`, no `geo`, no business entity. It is your location page with no location data.
  (`/contact` does carry a complete `Organization` with an address, nested inside its
  `ContactPage`. That is the second of the two pages in the table above.)
- **`/faqs` schema-content mismatch** — 13 of 17 answers absent.
- **The only GBP link on the site sits on `/about/client-testimonials`.**
- **`contactPoint` exists on the homepage only**, with no `url` and a single contact type.

---

## 5. On the traffic and enquiry decline

I want to be straight with you about what I can and cannot tell from the outside.

**What I can say confidently:** the site's organic foundations have never been in place. Since
March, 33 of 34 pages have had no business entity, and Google has never been able to see your
navigation. It is not that SEO broke in August — it is that organic local search was very
unlikely to have been driving those spring and summer enquiries in the first place.

**The detail that points elsewhere:** Arcadis reached out from **Alliance, Ohio**. That is
roughly 200 miles from Cincinnati, up near Canton, far outside any local pack you could appear
in and outside your stated pickup radius. A Cincinnati local-search result would never have
surfaced to them. That enquiry almost certainly came from **GovDeals, Alignable, a referral, or
direct outreach** — not from Google organic.

So before attributing the decline to the website, check what actually changed in those channels.
Three specific candidates, in order of how likely I think they are:

1. **The Google Business Profile account change.** You moved the primary account from
   `will@` to `info@`, then removed access from `info@`. Ownership changes are the most common
   trigger for a profile going unverified or suspended, and a listing that drops out of the map
   takes its visibility with it. **Check this first** — sign in to the Business Profile and
   confirm it still says Verified and is publicly visible. This is the one that could produce a
   sharp, dated drop.
2. **The GovDeals and Alignable address updates.** If either listing was the actual lead source,
   editing it may have reset its standing, changed its service-area assignment, or triggered a
   re-review. Confirm both are live and that enquiry forms still route to a mailbox you read.
3. **The `info@core-asset-sol.com` mailbox itself.** You removed access to it as a Google
   account. It is also the address published in your structured data and on every contact page.
   **Send a test message to it from an outside address and confirm it arrives.** If that mailbox
   broke, enquiries would look exactly like "almost no one is reaching out."

**How to settle it properly.** In Search Console, compare Performance for 1 Mar–31 Jul against
1 Aug–21 Sep. If impressions and clicks are broadly flat and only enquiries fell, the problem is
a channel or a mailbox, not SEO. If impressions genuinely collapsed in August, tell me and I
will dig into that specifically. Also add one question to your intake form or first call: "how
did you find us?" You will learn more from ten answers than from any amount of analysis here.

---

## 6. Header and footer — the plan that fits how you actually work

You are right that for a site this size, having the header and footer literally in the HTML is
the better answer. It is what Google wants, it removes two network round-trips, and at under 50
pages the maintenance cost is trivial. Forget the build-pipeline approach — it assumed a GitHub
integration you do not have and are not going to set up.

Instead, run a script on your PC against your local folder, then upload. No GitHub, no Node, no
CI.

**`fixes/build/inline-partials.ps1`** — PowerShell, which is already on your Windows machine.

```powershell
# Preview what would change
.\inline-partials.ps1 -Source "C:\path\to\your\site" -Check

# Do it
.\inline-partials.ps1 -Source "C:\path\to\your\site"
```

I tested it against a real 6-page mirror of your live site:

```
Filled            : 6
Already inlined   : 0        (re-run -> Filled 0, Already 6: safe to run repeatedly)
JSON-LD blocks    : 15/15 still parse
Internal links    : index 30 -> 46,  /services 13 -> 40,  /contact 11 -> 41
<nav> / <footer>  : now present in the raw HTML
Wrapper divs      : preserved
```

**It fills the placeholder `<div>`s rather than removing them, deliberately.** `assets/app.js`
depends on both wrappers:

- `loadPartial()` starts with `getElementById('header-placeholder'); if (!el) return;` — delete
  the element and `initHeaderChrome()` never runs, which breaks your mobile menu button.
- `adjustFooter()` selects `'#footer-placeholder .site-footer'` — remove the wrapper and footer
  spacing silently stops working.

### The full sequence

1. Run the script on your local folder. It writes `.bak` files first.
2. Apply the three-line change to `assets/app.js` so the browser does not re-fetch what is now
   inlined (full explanation in `fixes/build/app.js.patch.md`):

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

3. Open a page locally. Confirm the mobile menu opens and footer spacing looks right.
4. **Remove `Disallow: /partials/` from `robots.txt`.**
5. Delete the `.bak` files. Do not upload them.
6. Upload to Cloudflare Pages.
7. Verify: `.\verify.ps1 -Only P2-1`

**One trade-off to accept consciously:** the header and footer are now copied into every page.
Editing `partials/header.html` no longer updates the site by itself — you re-run the script and
re-upload. That is the correct trade at 34 pages. Re-evaluate if you pass roughly 100.

---

## 7. Google Maps, Apple Maps, and linking them properly

### Google Business Profile

You have one. The site just does not point at it.

**Step 1 — confirm the profile is healthy.** Before any markup, sign in and check:

- Status says **Verified**, not "Suspended" or "Pending verification"
- Primary category is **Electronics recycling company** (this is the biggest local ranking
  factor after proximity — get it right before anything cosmetic)
- The address matches whatever you settle on in section 8, character for character
- Service area covers Cincinnati, Dayton, and outward toward Columbus, Indianapolis, Louisville
- Ownership is clean after the `will@` / `info@` change

**Step 2 — get the canonical link.** In the Business Profile, use **Share** → copy link. That
gives you a `maps.app.goo.gl/...` or `g.page/...` URL for the **profile**, which is different
from the reviews link currently on your testimonials page.

Derived from the CID I found, this should also resolve to your listing — open it and confirm
before using it:

```
https://www.google.com/maps?cid=13429985598701594348
```

**Step 3 — wire it into the site:**

```jsonc
"hasMap": "PASTE_THE_SHARE_LINK_HERE"
```

in the business node, on all 34 pages. Then:

- `/about/locations` gets a real Google Maps embed plus a "Get directions" link to the profile.
  Keep your Leaflet/OpenFreeMap map if you like the look, but the Google link needs to be there.
- `/contact` should link the **profile**, not the current `maps/search/?api=1&query=...` URL.
- Keep the reviews link on `/about/client-testimonials` — it is genuinely useful there, just no
  longer the only GBP reference on the site.

**On "completing" the profile to 100%:** you cannot, and it does not matter. Google's completion
meter includes prompts for Ads and for attributes that do not apply to a B2B processor. Nothing
in local ranking depends on hitting 100%. What does matter, in order: correct primary category,
consistent NAP, real photos, genuine reviews, and regular posts. Ignore the meter.

### Apple Maps

You have **zero** Apple presence — no `maps.apple.com` link anywhere on the site, and no listing
that I can see.

Apple Business Connect is free and entirely separate from Google. It matters more than people
expect for B2B: it is what Siri and Apple Maps surface by default on every iPhone, and a
meaningful share of executives are on iPhones.

1. Register at **businessconnect.apple.com**, claim or create the place, verify.
2. Use the identical NAP. Apple cross-references against other sources, so consistency helps
   you get verified faster.
3. Add categories, hours, photos, and your website URL.
4. Optionally add an Apple Maps link on `/about/locations` next to the Google one:
   `https://maps.apple.com/?address=<your+address>` or the place link Apple gives you.

### Best practice for linking maps to the site

| Where | What |
|---|---|
| Business node, all pages | `hasMap` → Google Business Profile share link |
| `/about/locations` | Embedded map, "Get directions" → GBP, Apple Maps link, full NAP in visible text **and** in `PostalAddress` markup |
| `/contact` | Link the profile, not a maps search URL |
| `/about/client-testimonials` | Keep the reviews link; add "leave a review" |
| Footer, every page | Full address in visible text, matching the schema exactly |

---

## 8. Address, `contactPoint`, and social profiles — direct answers

### Which address is canonical?

I cannot tell from outside which is current. The live site says **457 S Cooper Ave., 45215**,
with the city given as Lockland on the homepage and Cincinnati on `/contact`. You mentioned
updating Alignable and GovDeals "to our new address", which suggests the site may be stale.

**Decide this before anything else in this document**, because every other local fix depends on
it. Then make all of these identical, character for character:

- Google Business Profile
- Apple Business Connect
- Website structured data (`streetAddress`, `addressLocality`, `addressRegion`, `postalCode`)
- Website visible text — footer, `/contact`, `/about/locations`
- Alignable, GovDeals, and every other directory

Two specific rules given what I found:
- Pick **"S Cooper"** or **"South Cooper"** and use that one form everywhere. Match your GBP.
- Pick **one** city name. If the postal city for 45215 is Cincinnati, use Cincinnati everywhere.
  If your GBP says Lockland, use Lockland everywhere. Do not mix.

### Is `contactPoint` correct?

Partly, and only on one page. Here is exactly what is live:

```json
"contactPoint": {
  "@type": "ContactPoint",
  "contactType": "customer service",
  "telephone": "+1-513-433-7818",
  "email": "info@core-asset-sol.com",
  "availableLanguage": "English"
}
```

The phone and email are correct and correctly formatted (E.164 with the `+1`). What is missing:

- It exists on the **homepage only**. `/contact` has no `contactPoint` at all.
- No `url` property, so nothing connects it to `/contact` or your forms.
- One contact type only. A separate `sales` entry pointing at
  `/schedule-consultation-form` helps Google route intent.
- No `areaServed`.

Corrected version is in `structured-data/_business-node.jsonld`, which already has two contact
points with `url` and `areaServed`.

One flag: `info@core-asset-sol.com` is the email in your markup, on every contact page, and is
the mailbox whose Google account access you removed. Confirm it still receives external mail
(section 5).

### Are the social profiles connected?

**No.** You believed these were done; they are not live.

| Profile | In `sameAs` |
|---|---|
| `linkedin.com/company/coreassetsolutions` | Yes — homepage only |
| `facebook.com/CoreAssetSolutions` | **No** |
| `instagram.com/coreassetsolutions` | **No** |
| `x.com/coreassetsol` | **No** |

All four are live and all four are already linked from your footer HTML — they are simply absent
from the structured data. `sameAs` is how Google reconciles your website with your social
entities for knowledge panel consolidation, so listing one of four discards most of that signal.
All four are in `_business-node.jsonld`.

---

## 9. Do this in this order

Everything here is independent of the content you are still writing.

| # | Action | Effort |
|---|---|---|
| 1 | Confirm the Google Business Profile is still Verified and publicly visible after the account change | 10 min |
| 2 | Send a test email to `info@core-asset-sol.com` from outside and confirm it arrives | 5 min |
| 3 | Decide the one canonical address and city name | — |
| 4 | Remove `Disallow: /partials/` from robots.txt | 1 min |
| 5 | Run `inline-partials.ps1`, apply the `app.js` patch, upload | 1 hour |
| 6 | Ship `_business-node.jsonld` into all 34 pages, with the canonical address, all four `sameAs`, both contact points, and `hasMap` | 2–3 hours |
| 7 | Fix `addressLocality` and the "S" vs "South" mismatch everywhere | 30 min |
| 8 | Add `PostalAddress` + `geo` + Google Maps link to `/about/locations` | 30 min |
| 9 | Delete the `FAQPage` block from `/faqs` until your rewrite ships | 5 min |
| 10 | Fix the `Certificate-Of-Destruction.pdf` link on two pages (underscores, not hyphens) | 5 min |
| 11 | Point the 12 internal links at their final destinations | 20 min |
| 12 | Register on Apple Business Connect | 30 min |
| 13 | Alt text on the industry pages (27 and 12 missing) | 1 hour |

Items 1–3 before anything else. Items 4–6 are the ones that will actually change what Google can
see.

Then re-run `.\verify.ps1` and you should be at or near a clean sheet on everything except the
content work you already have in flight.
