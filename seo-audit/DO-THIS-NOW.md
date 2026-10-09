# Do this now — the three fixes, in order

2026-10-09. Everything here is independent of the content work you have in flight. Nothing
below requires you to finish the service or industry page rewrites.

---

## Your Google Business Profile — verified, not guessed

You were right to be suspicious. The link currently on your site is a **reviews** URL, not your
listing.

I resolved it properly. I requested the CID URL directly from Google's servers with a Googlebot
user agent and got back:

```
title   : Core Asset Solutions - Google Maps
address : 457 S Cooper Ave, Lockland, OH 45215
phone   : (513) 433-7818
```

**That is your real listing.** Here is the canonical link:

```
https://www.google.com/maps?cid=13429985598701594348
```

Open it yourself right now and confirm you land on your own profile. If you do, that string is
what goes in `hasMap`, and it is already in the shared node below.

| | Value |
|---|---|
| CID (decimal) | `13429985598701594348` |
| CID (hex) | `0xba60e4bf353866ec` |
| Canonical URL | `https://www.google.com/maps?cid=13429985598701594348` |
| Also works | `https://maps.google.com/?cid=13429985598701594348` |

**This also settles your address argument.** Google Business Profile holds
**`457 S Cooper Ave, Lockland, OH 45215`**. That exact string is now canonical — the GBP is the
source of truth, and everything else has to match it character for character.

Two things on your site contradict it and must be corrected:

| Where | Currently says | Must say |
|---|---|---|
| `/contact` schema `addressLocality` | `Cincinnati` | `Lockland` |
| Visible text, `/contact` and `/about/locations` | `457 South Cooper Ave` | `457 S Cooper Ave` |

Keep the reviews link on `/about/client-testimonials` — it is genuinely useful there for "leave
us a review". It is just not what belongs in `hasMap`.

---

## Fix 1 — paste the shared business node into all 36 pages

**File:** `SHARED-BUSINESS-NODE.html`

Copy everything from `<script type="application/ld+json">` to `</script>` and paste it into the
`<head>` of every page, right after your existing `<link rel="canonical">` line. Byte-identical
on all 36. Do not customise it per page.

**Leave all your existing JSON-LD alone.** Including the `provider` stubs on your service and
industry pages. They share the same `@id` as the node you are pasting, so JSON-LD merges them
into one entity automatically.

I proved this on your actual live pages rather than asserting it. I pulled each page, added the
shared node, and ran the result through a real JSON-LD processor:

| Page | Local-signal properties before | after |
|---|---|---|
| `/services/data-destruction` | 1 | **12** |
| `/industries-served/healthcare` | 1 | **12** |
| `/services/itad` | 1 | **12** |
| `/about/locations` | 0 | **12** |
| `/resources/reporting-esg` | 0 | **12** |
| `/faqs` | 0 | **12** |
| `/terms` | 0 | **12** |

The merged entity comes out as one node typed **both** `Organization` and `RecyclingCenter`,
carrying address, geo, hasMap, telephone, email, opening hours, areaServed, sameAs,
contactPoint, priceRange and the service catalog. Your `provider` stub stops being a dead
reference and starts resolving to a complete local business.

### The local signal you asked for

`areaServed` has 23 entries across three layers:

| Layer | Entries |
|---|---|
| Pickup radius | `GeoCircle`, 193,121 m (**120 miles**) from the Lockland facility |
| Cities and places | Cincinnati, Blue Ash, Mason, Lockland, Dayton, Columbus, Over-the-Rhine, Northern Kentucky |
| States | Ohio, Indiana, Kentucky |
| Counties (11) | Hamilton, Butler, Warren, Clermont, Montgomery, Greene, Franklin (OH); Boone, Kenton, Campbell (KY); Dearborn (IN) |

Over-the-Rhine is modelled as a `Place` inside Cincinnati rather than a `City`, because that is
what it is — a neighbourhood. Northern Kentucky is modelled as a `Place` inside Kentucky plus
its three constituent counties, since it is a colloquial region with no official boundary.

Validated against the official schema.org vocabulary: 15 types, 44 properties, **0 issues**.

### One honest expectation

`areaServed` tells Google what you cover. It does **not** by itself make you rank in Columbus or
Indianapolis — those need real pages with real local content. What it does do is fix the thing
that is genuinely broken today: 32 of your 34 pages currently have no address, no geo, no hours
and no service area at all, so they are competing for "… in Cincinnati" with zero local signals.
This gets every page to parity.

---

## Fix 2 — delete one line from robots.txt

```
Disallow: /partials/
```

Delete it. Upload. One minute.

Right now Googlebot cannot see your navigation in the raw HTML (it is injected by JavaScript)
**and** cannot fetch the fragments to render it (this line forbids it). Removing the line
restores the rendering path immediately while you do Fix 3.

Keep the `X-Robots-Tag: noindex` on `/partials/*` in `_headers` — that part is right.

---

## Fix 3 — put the header and footer in the HTML

Full walkthrough in **`FIX-HEADER-FOOTER.md`**, with both a script and a by-hand option.

Short version: fill the two placeholder `<div>`s with the real partial contents, then add three
lines to `loadPartial` in `app.js` so the browser does not re-download what is now inlined.

**Do not delete the wrapper divs.** `loadPartial` bails out if `#header-placeholder` is missing
and your mobile menu stops working; `adjustFooter()` selects `#footer-placeholder .site-footer`
and footer spacing breaks. Fill them, keep them.

Measured effect on a mirror of your site: internal links visible to Google go from 30 → 46 on
the homepage, 13 → 40 on `/services`, 11 → 41 on `/contact`. Across the site the median goes
from 19 to the high 30s.

---

## On "we rank #1 for IT asset disposition Cincinnati but get no clicks"

Both halves of what you were told can be true at once, and the explanation is probably simpler
than it sounds.

Ranking #1 for a term nobody searches produces no clicks. That part of the advice is sound —
"IT asset disposition" is procurement vocabulary. The people with the problem search
*"electronics recycling near me"*, *"e-waste pickup Cincinnati"*, *"hard drive destruction"*,
*"computer disposal company"*. Check Search Console's Queries tab for what you actually get
impressions on; that list is more reliable than any keyword tool.

But impressions with zero clicks also points at something you can act on immediately. When
Google shows your result, the searcher sees your title, your description, and — for a local
query — whether you appear in the map pack with a rating, photos and hours. Today you have no
`hasMap`, no business entity on 32 of 34 pages, and no reviews showing. A result with no local
trust signals next to competitors who have them gets skipped even at position 1.

Three things worth checking this week, in order:

1. **Is the Google Business Profile still Verified and publicly visible?** You moved the primary
   account from `will@` to `info@` and then removed `info@` access. Ownership changes are the
   single most common trigger for a listing going unverified. A profile that drops out of the
   map takes your local clicks with it — and the timing lines up with your three-month decline.
   This is the first thing to check.
2. **Does `info@core-asset-sol.com` still receive outside mail?** It is the address in your
   markup and on every contact page, and it is the mailbox whose Google access you removed.
   Send yourself a test from a personal address. A broken inbox looks exactly like "nobody is
   contacting us."
3. **Reviews.** Even a handful of detailed B2B reviews is a differentiator in this industry.
   Ask every completed client. This moves map-pack clicks more than any markup change.

I cannot see your Search Console or your analytics, so I cannot tell you which of these caused
the decline. But I can tell you the site currently gives Google almost nothing to work with
locally, and the three fixes above change that.

---

## Order and effort

| | Fix | Time |
|---|---|---|
| 1 | Check GBP is still Verified | 10 min |
| 2 | Send a test email to `info@` from outside | 2 min |
| 3 | Delete `Disallow: /partials/` from robots.txt, upload | 1 min |
| 4 | Paste the shared node into all 36 pages, upload | 1–2 hrs |
| 5 | Fix `addressLocality` to `Lockland` on `/contact`, and `457 S Cooper Ave` in visible text | 15 min |
| 6 | Inline header and footer, patch `app.js`, upload | 1 hr |
| 7 | Add `hasMap` link + full address to `/about/locations` | 20 min |

Then run `.\verify.ps1`. You should see `P2-4` and `P2-5` pass and `P2-1` pass for the first
time.

### Verify it worked

```powershell
.\verify.ps1 -Only P2-5    # expect: all 34 pages carry a complete business entity
.\verify.ps1 -Only P2-4    # expect: homepage declares hasMap
.\verify.ps1 -Only P2-1    # expect: 40+ internal links in raw HTML
.\verify.ps1 -Only P2-3    # expect: addressLocality matches
```

Also run one page through <https://validator.schema.org/> and
<https://search.google.com/test/rich-results>. The Rich Results Test should now report
**Local business** eligibility, which it cannot today.
