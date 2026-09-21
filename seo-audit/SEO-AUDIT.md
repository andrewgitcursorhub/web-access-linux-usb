# Full SEO Audit — core-asset-sol.com

**Audit date:** 2026-08-17
**Method:** Live crawl as Googlebot (45 linked URLs), XML sitemap reconciliation, 135-URL variant sweep,
JSON-LD extraction and validation against the official schema.org vocabulary (schemaorg-current-https.jsonld,
979 types), DNS/HTTP header inspection.
**Platform detected:** Cloudflare Pages (confirmed by the `Cloudflare Pages Analytics` beacon and CF edge headers).

---

## The headline answer

Your "34 indexed / 100+ not indexed" split is not a content problem. It is an arithmetic result of how the
site's URL space is built:

| | Count |
|---|---|
| Live, indexable HTML pages | **34** |
| Alternate URL forms of those same 34 pages that resolve | **135** |
| Total crawlable URL surface | **169** |

The site has exactly **34** real pages, and Google has indexed exactly **34** pages. Indexation of your live
content is *already working*. The 100+ "not indexed" URLs are overwhelmingly the alternate forms — `.html`,
trailing slash, double slash, and query-string variants — which correctly return redirects and therefore get
filed under **"Page with redirect."** That report is Google telling you what it did, not what is broken.

So the real work is not "get 100 pages indexed." It is:

1. Fix the small number of genuine errors hiding inside that 135 (listed as P0/P1 below).
2. Stop generating avoidable variant URLs so the report gets quiet and crawl budget goes to real pages.
3. Fix the structured data, which is where you are actually losing rich results today.

### Reconciling the six "not indexed" reasons

Based on what the crawl found, your six buckets are almost certainly:

> **Correction (verified 2026-08-17 against Google's official structured data gallery):** an earlier revision
> of this report described FAQ rich results as "restricted since Aug 2023 to well-known government and health
> sites." That was true from August 2023 but is now out of date. **Google fully removed the FAQ rich result on
> 7 May 2026**, including for the gov/health sites that had retained it. `FAQPage` no longer appears anywhere
> in Google's supported-features list. The Search Console report and Rich Results Test support were dropped in
> June 2026 and Search Console API support ends this month (August 2026). See P2-5 for the corrected guidance.

| GSC reason | Approx. count | Verdict |
|---|---|---|
| Page with redirect | ~134 | Benign by design, but see P1-1 (the 33 `302`s are wrong) and P0-3 (`/sustainability` is in your sitemap) |
| Alternate page with proper canonical tag | varies with `?utm_*` traffic | Benign — working as intended |
| Not found (404) | small | **Real bug** — see P1-3, a linked PDF is 404ing |
| Crawled – currently not indexed | small | **Real** — `/partials/header`, `/partials/footer`, thin pages |
| Discovered – currently not indexed | small | Low-value variants; resolves once variants stop being generated |
| Soft 404 / Excluded by 'noindex' tag | 2 | **Real bug** — see P1-2, `/404` returns HTTP 200 |

---

# Priority-ordered fix list

## P0 — Critical. These are actively costing you rich results and traffic.

### P0-1. The homepage schema type is invalid, so you have **no** valid business entity anywhere on the site

`https://core-asset-sol.com/` declares:

```json
{ "@type": "Recycling Center", "@id": "https://core-asset-sol.com/#organization", ... }
```

`Recycling Center` **is not a schema.org type.** Schema.org type names never contain spaces. The correct token
is `RecyclingCenter` (verified against the official vocabulary: `RecyclingCenter` exists, `Recycling Center`
does not). Google cannot resolve the token, so it discards the entire entity — including the address, phone,
`areaServed`, `sameAs`, `logo`, and `contactPoint` you carefully filled in.

This is the single highest-impact defect in the audit. Consequences:

- **No Organization / logo rich result.** Your logo will not appear next to your listing.
- **No local business eligibility.** For a Cincinnati ITAD company competing on "electronics recycling near me,"
  this is the most valuable rich result available to you and you are currently ineligible.
- **No knowledge panel entity consolidation**, so your social profiles are not tied to the business.
- **Cascading breakage:** every service and industry page references `provider: {"@id": ".../#organization"}`.
  That target is now undefined, so all 22 `Service` blocks point at a broken reference.

**Fix:** change the token to `RecyclingCenter`. Corrected, expanded markup is in
[`fixes/schema/homepage-organization.jsonld`](fixes/schema/homepage-organization.jsonld).

### P0-2. `/specialty-equipment-we-handle` has two JSON-LD blocks that are invalid JSON

Both fail to parse, so both entities are dropped entirely. The page currently emits **no** `WebPage` and
**no** breadcrumb.

**Block 1** — a copy-paste artifact left an HTML attribute fragment inside a JSON string value, and the page
name was copied from a different page:

```json
"name": "Client Testimonials",
"description": "Structured disposition for non-standard and specialty equipment ... infrastructure." name="description"",
```

Two defects: the trailing `" name="description""` is a syntax error, and `"name"` says *Client Testimonials*
on the specialty-equipment page.

**Block 2** — trailing comma after the final array element, which is invalid JSON:

```json
      {
            "@type": "ListItem",
            "position": 2,
            "name": "Specialty Equipment",
            "item": "https://core-asset-sol.com/specialty-equipment-we-handle"
      },      <-- this comma is illegal before the closing bracket
]
```

**Fix:** corrected file at [`fixes/schema/specialty-equipment-we-handle.jsonld`](fixes/schema/specialty-equipment-we-handle.jsonld).

### P0-3. `/sustainability` is in your XML sitemap but 301-redirects

```
GET /sustainability  ->  301  ->  /resources/reporting-esg
```

A sitemap is a declaration of canonical, indexable URLs. Listing a redirecting URL is a direct contradiction
and is reported in GSC as an error against the sitemap. It also makes `/sustainability` your only orphan
sitemap entry (zero internal links).

**Fix:** remove `/sustainability` from `sitemap.xml`. Keep the 301 itself — it is correct. Corrected sitemap
at [`fixes/sitemap.xml`](fixes/sitemap.xml).

### P0-4. `www.core-asset-sol.com` does not resolve at all

```
dig www.core-asset-sol.com  ->  (no record)
curl https://www.core-asset-sol.com/  ->  Could not resolve host
```

There is no A, AAAA, or CNAME record for `www`. Anyone who types, links, or cites the `www` form — and for a
local business, directory listings and citations frequently do — gets a hard browser failure, not a redirect.
This also silently kills any link equity from those citations.

**Fix:** add `www` as a CNAME to the apex in Cloudflare DNS (proxied), then add a redirect rule
`https://www.core-asset-sol.com/*` → `https://core-asset-sol.com/:splat` at **301**. Never leave `www`
unresolvable.

---

## P1 — High. Real errors inside the "not indexed" report.

### P1-1. 33 query-string URLs return **302 (temporary)** instead of 301

Every page does this:

```
GET /services/data-destruction?ref=x   ->  302  ->  /services/data-destruction
```

A 302 tells Google "the original URL is the real one, come back later." It does not consolidate signals to the
destination and it keeps the source URL in the crawl rotation indefinitely. That is a meaningful chunk of your
"Page with redirect" count that will never clear.

Note the handling is also inconsistent: `?utm_source=...` returns **200** with a correct self-referencing
canonical (fine), while `?ref=...` returns **302**. Two different behaviours for the same class of URL.

**Fix (preferred):** stop redirecting on query strings entirely. Serve 200 and rely on the self-referencing
canonical you already emit correctly — that is exactly the case `rel=canonical` exists for, and it preserves
campaign tracking parameters that your analytics needs. If you keep the redirect, make it 301.

### P1-2. `/404` and `/404.html` return HTTP 200 — a textbook soft 404

```
GET /404       ->  200 OK   (title: "Page Not Found | Core Asset Solutions")
GET /404.html  ->  308      ->  /404  ->  200 OK
```

Your error *handling* is correct — genuine junk URLs like `/this-page-does-not-exist-12345` properly return
404. The problem is that the error *template* is itself reachable at a real URL that returns 200. Google sees
a page saying "Page Not Found" served with a success status, which is the definition of a soft 404.

The page does carry `<meta name="robots" content="noindex,follow,noarchive">`, so it will not be indexed — but
it will keep appearing in your report and consuming crawl budget.

**Fix:** make `/404` and `/404.html` return a real `404` status, or block both in `robots.txt`. Included in
[`fixes/robots.txt`](fixes/robots.txt).

### P1-3. A linked PDF returns 404 from two industry pages

```
/resources/Certificate-Of-Destruction.pdf   ->  404
```

Linked from `/industries-served/education` and `/industries-served/healthcare`. The correct file exists at
`/resources/Certificate_Of_Destruction.pdf` — note **underscores**, not hyphens. This is a plain typo shipping
a broken link from two of your highest-intent commercial pages.

**Fix:** correct the two `href`s. Also add a 301 from the hyphenated form in case it has been shared.

### P1-4. `/partials/header` and `/partials/footer` are indexable HTML fragments

```
GET /partials/header  ->  200, no noindex, no canonical  (20 KB of nav markup)
GET /partials/footer  ->  200, no noindex, no canonical  (11.7 KB)
```

These are your navigation fragments, exposed as crawlable pages with no robots directive. They are headless
markup with no `<title>` and no content, which is exactly what lands in "Crawled – currently not indexed."
Their `.html` forms add two more 308s on top.

**Fix:** block `/partials/` in `robots.txt` **and** send `X-Robots-Tag: noindex` via `_headers`. Both included
in the fixes directory. Use both, because robots.txt alone does not remove an already-indexed URL.

### P1-5. Nine pages link to a redirecting PDF; two more link to redirecting pages

| Link target | Status | Linked from |
|---|---|---|
| `/resources/sample-certificate-of-media-sanitization.pdf` | 301 → `/resources/Certificate_Media_Sanitization.pdf` | 9 pages |
| `/industries` | 301 → `/industries-served` | `/industries-served/government` |
| `/privacy.html` | 301 → `/privacy` | `/schedule-consultation-form` |
| `/schedule-consultation.html` | 301 | `/assets/app.js` |

Internal links should always point at the final destination. Every internal link to a redirect wastes a hop,
dilutes the signal, and keeps the redirect source alive in Google's crawl queue.

**Fix:** update all 12 `href`s to the final URLs. Leave the redirects in place for external links.

### P1-6. Three live pages are missing from the XML sitemap and two are fully orphaned

| Page | In sitemap | Internal links (raw HTML) |
|---|---|---|
| `/privacy` | No | 1 |
| `/terms` | No | 0 |
| `/sitemap` | No | 0 |

`/terms` and `/sitemap` are reachable only through the JavaScript-injected footer (see P2-1). In raw HTML they
have zero inbound links and are absent from the sitemap, so their only discovery path depends on Google
rendering your JS.

**Fix:** add all three to `sitemap.xml` (done in [`fixes/sitemap.xml`](fixes/sitemap.xml)).

### P1-7. The XML sitemap has no `<lastmod>` on any URL

All 32 entries carry only `<loc>`. `lastmod` is the primary signal Google uses to prioritise recrawls, and
Google has confirmed it uses it when it is consistently accurate. Without it, every recrawl decision is a
guess.

**Fix:** emit a real `<lastmod>` per URL at build time. Do not fake it — a sitemap where everything changed
today gets the signal ignored entirely.

---

## P2 — Structural. This is what caps your ranking ceiling.

### P2-1. Your entire primary navigation and footer are injected by JavaScript

This is the most consequential structural finding in the audit.

```html
<body class="page--home">
  <div id="header-placeholder"></div>   <!-- 32 nav links, fetched client-side -->
  <main> ... </main>
  <div id="footer-placeholder"></div>   <!-- 33 footer links, fetched client-side -->
```

`/assets/app.js` fetches `/partials/header.html` and `/partials/footer.html` at runtime and injects them.
The raw HTML that Googlebot receives on the first pass contains **zero** navigation links. There is no
`<nav>` element and no `<footer>` element anywhere in the served markup.

Why this matters:

- Google's initial crawl pass sees only in-body contextual links. Your site architecture — the deliberate
  hub-and-spoke structure through `/services`, `/industries-served`, `/resources` — is invisible until the
  renderer runs, which is a separate, slower, resource-constrained queue.
- PageRank flow through the header and footer is delayed and unreliable.
- It explains the internal link counts measured from raw HTML: `/faqs` has **1** inbound link despite being
  your single largest content asset at 2,860 words. `/about/client-testimonials` has 1. `/terms` and
  `/sitemap` have 0.
- Two extra network round-trips on every page load, both of which **currently 308-redirect** because the
  `.html` stripping rule catches your own partials:
  `fetch('/partials/header.html')` → `308` → `/partials/header`.

**Fix:** server-side render or build-time inline the header and footer into every page's HTML. On Cloudflare
Pages the natural options are a static-site-generator include or a Pages Function. This is the highest-value
structural change available and it is a prerequisite for the internal-linking improvements below.

**Interim fix (5 minutes, do it regardless):** change the two fetch URLs in `app.js` to `/partials/header`
and `/partials/footer` to kill the redirect hop.

### P2-2. Your `sameAs` lists one social profile; four are live

The footer links to four working profiles (all verified 200):

```
https://www.facebook.com/CoreAssetSolutions/
https://www.instagram.com/coreassetsolutions/
https://www.linkedin.com/company/coreassetsolutions/
https://x.com/coreassetsol
```

The homepage `sameAs` contains only the LinkedIn URL. `sameAs` is how Google reconciles your website with your
social entities for knowledge panel consolidation. Listing one of four throws away most of that signal.

**Fix:** all four are included in `fixes/schema/homepage-organization.jsonld`.

### P2-3. NAP inconsistency between the homepage and the contact page

```
Homepage:     "streetAddress": "457 South Cooper Ave."
Contact page: "streetAddress": "457 S Cooper Ave."
```

Name/Address/Phone consistency is a foundational local ranking factor. The two forms must be byte-identical
across the site, your Google Business Profile, and every directory citation.

**Fix:** pick one form (match your Google Business Profile exactly) and use it everywhere.

### P2-4. Cross-page `@id` references are dangling

Every service and industry page references `provider: { "@id": "https://core-asset-sol.com/#organization" }`,
but that node is only *defined* on the homepage. **Google does not resolve `@id` references across pages.** On
each service page the provider therefore collapses to a stub with only `name` and `url`.

**Fix:** emit the full `Organization`/`RecyclingCenter` node in a `@graph` on **every** page, not just the
homepage. That is how the corrected homepage file is structured — reuse the pattern site-wide.

### P2-5. Understand what you can and cannot win in rich results

You currently emit a lot of markup that produces no rich result. Measured inventory:

| Type | Instances | Google rich result status |
|---|---|---|
| `Question` / `Answer` | 153 each | **Dead.** Google removed the FAQ rich result entirely on 7 May 2026 |
| `FAQPage` | 19 | **Dead.** No longer in Google's supported-features list for any site |
| `Service` | 22 | **Not a rich result type in Google Search** |
| `BreadcrumbList` | 30 | **Eligible — this is your one working rich result** |
| `Organization` | 18 | Eligible, but broken by P0-1 |
| `Recycling Center` | 1 | **Invalid token — see P0-1** |
| `ListItem` | 102 | Supporting only |

The honest picture: **the only rich result you are currently eligible for is breadcrumbs**, and that is broken
on `/specialty-equipment-we-handle`. Once P0-1 is fixed you add Organization/logo and local business
eligibility, which for a Cincinnati ITAD firm is the valuable one.

**On the FAQ markup.** Google removed the FAQ rich result for everyone on 7 May 2026 — this is a full
deprecation, not the 2023 gov/health restriction. Do not delete the markup anyway: `FAQPage` is still a valid
schema.org type, Google has confirmed it still parses it for page comprehension, other engines still consume
it, and your 153 Q&A pairs are a genuine content asset. Just stop treating it as a rich-result lever and
reallocate the effort. One thing that *does* still matter: make sure the Q&A text is visible in the rendered
HTML rather than hidden behind a JS-only accordion.

**Do not** add `AggregateRating` or `Review` markup for your own business. Google's review snippet policy is
explicit: "If the entity that's being reviewed controls the reviews about itself, their pages that use
LocalBusiness or any other type of Organization structured data are ineligible for star review feature." This
applies to embedded third-party widgets too. `/about/client-testimonials` is exactly the page where this
temptation arises — resist it. It earns no stars and fabricated or misleading markup risks a manual action.

For the full page-by-page plan of which rich results you *can* still win, see
[`RICH-RESULTS-ROADMAP.md`](RICH-RESULTS-ROADMAP.md).

### P2-6. `/industries-served` and `/services` hub pages carry stub `ListItem` entries

The `ItemList` blocks contain `ListItem` entries with `position` and `item` but no `name`. `ItemList` and
`DigitalDocument` are both valid types, but the entries are thinner than they need to be.

**Fix:** add `"name"` to each `ListItem`.

---

## P3 — On-page quality.

### P3-1. 28 of 34 titles exceed 60 characters

Google truncates around 55-60 characters (roughly 600px). Worst offenders:

| Page | Length |
|---|---|
| `/about/process` | **119** |
| `/industries-served` | 92 |
| `/` | 90 |
| `/cincinnati-itad-electronics-recycling` | 89 |
| `/services/decommissioning` | 86 |

A 119-character title means roughly half of it is never shown. Rewrite front-loading the primary keyword.

### P3-2. 14 meta descriptions exceed 160 characters; one page has an unusually short one

Over-length: `/industries-served` (235), `/about` (218), `/services/hard-drive-destruction` (211),
`/services` (210). Under-length: `/services/electronics-recycling` (64).

### P3-3. 256 of 301 images (85%) have no `alt` text

Concentrated on the industry pages — `/industries-served/education`, `/financial-services`, `/healthcare`,
`/industrial-equipment`, and `/test-measurement-equipment` each have **27 of 27** images with no alt text.
This is an accessibility defect first and an image-search and on-page relevance loss second.

### P3-4. Thin pages

| Page | Words |
|---|---|
| `/about/client-testimonials` | **86** |
| `/about/locations` | **106** |
| `/schedule-pickup-form` | 159 |
| `/resources` | 293 |

`/about/locations` at 106 words is the notable one: for a local business, the locations page should be a
primary local ranking asset carrying full NAP, hours, service-area detail, and an embedded map.

### P3-5. Heading structure

- `/schedule-consultation-form` has **two** `<h1>` elements ("Schedule an ITAD Consultation" and
  "Schedule a Consultation").
- `/privacy` has **no** `<h1>`.

### P3-6. Core Web Vitals risks

Delivery is genuinely good — Brotli compression, 54-136 ms TTFB, 8-16 KB compressed HTML. Two risks remain:

- **No `width`/`height` on any homepage image** (0 of 5). This is the classic CLS trigger. Every `<img>` needs
  explicit dimensions or a reserved aspect-ratio box.
- **13 render-blocking resources** in `<head>`: 9 stylesheets and 4 scripts, including two third-party origins
  (`cdnjs.cloudflare.com` for Font Awesome, `unpkg.com` for `model-viewer`) with **no `preconnect`**. The
  homepage also loads a `.glb` 3D model and an `.hdr` environment map, which is heavy for an LCP-critical
  viewport.

**Fix:** concatenate the 8 first-party CSS files, add `<link rel="preconnect">` for both third-party origins,
self-host Font Awesome (or subset it), and defer `model-viewer` until after LCP.

### P3-7. Minor

- `<meta name="keywords">` is present on every page. Google has ignored it since 2009. Harmless, but it is
  dead weight and it advertises the keyword list to competitors.
- No `theme-color` meta.
- Root double slash `//` returns **200** — a genuine duplicate of the homepage. It does self-canonicalise, so
  it is low severity, but normalise it to a 301.
- No `hreflang` — correct for a single-region US site. No action.

---

# How to fix redirects properly

You asked specifically about 301 vs 404 vs 410 and pages redirecting to the homepage. The good news: **the
audit found no blanket redirect-to-homepage behaviour.** Junk URLs correctly return 404. That specific fear is
unfounded.

Use this decision table:

| Situation | Correct response | Why |
|---|---|---|
| Page moved, close equivalent exists | **301** | Permanently consolidates signals to the new URL |
| URL variant of a live page (`.html`, trailing slash, `//`) | **301 / 308** | Already correct on your site |
| Query-string variant (`?utm_*`, `?ref=`) | **200 + self-canonical** | Preserves tracking; canonical handles dedup. Your current 302 is wrong |
| Page deleted, no equivalent, may return | **404** | Google retries periodically |
| Page deleted permanently and intentionally | **410** | Google drops it roughly twice as fast as a 404 |
| Temporary outage / maintenance | **503** | Never 404 a temporary problem |

**Rules that matter for your site:**

1. **Never redirect a deleted page to the homepage.** Google treats an irrelevant redirect as a soft 404 and
   it is worse than a clean 404, because it wastes crawl budget and pollutes your report.
2. **Only 301 to a genuinely equivalent page.** `/sustainability` → `/resources/reporting-esg` is a good
   redirect. A hypothetical `/old-blog-post` → `/` would not be.
3. **Never chain redirects.** Every chain should be exactly one hop. Your chains are currently clean — keep
   them that way by updating internal links (P1-5) rather than adding rules.
4. **Use 410 sparingly and deliberately.** Reach for it only when you are certain a URL is gone forever.
   For your site, nothing in the current inventory needs a 410 — you have no mass-deleted legacy section.
5. **Redirects are not permanent infrastructure, but keep them at least a year.** Google needs repeated
   confirmation before it fully transfers signals.

---

# How to get every live page canonicalised and indexed

This is the part of your setup that is already in good shape. Verified across the crawl: **all 34 live pages
emit a correct, absolute, self-referencing `rel=canonical`.** The only canonical "mismatch" the audit found is
`/sustainability`, and that is not a live page — it is a 301 to `/resources/reporting-esg`, so inheriting the
destination's canonical is the correct behaviour. Its only defect is being listed in the sitemap (P0-3).

Keep the following invariants true and canonicalisation stays healthy.

1. **Every indexable page self-canonicalises** to its absolute HTTPS non-`www` extensionless no-trailing-slash
   form. Already true. Do not let a template regression break it.
2. **The XML sitemap contains only 200-status, self-canonical, indexable URLs.** Fix P0-3 and P1-6.
3. **One URL form is canonical and everything else redirects to it once.** Already true.
4. **Never mix signals.** A URL must not be simultaneously in the sitemap and redirecting (your
   `/sustainability` bug), or canonical to itself while carrying `noindex`.
5. **Internal links point only at canonical URLs.** Fix P1-5.
6. **Nothing important depends on JavaScript for discovery.** Fix P2-1.

### Verification sequence after deploying

1. Deploy the corrected `sitemap.xml`, `robots.txt`, `_redirects`, and `_headers`.
2. In Search Console → Sitemaps, resubmit `https://core-asset-sol.com/sitemap.xml`.
3. Run **URL Inspection → Test Live URL** on `/` and `/specialty-equipment-we-handle`, confirm the structured
   data now parses, then **Request Indexing** on both.
4. Run the [Rich Results Test](https://search.google.com/test/rich-results) on `/` — you should now see
   *Breadcrumbs* **and** *Local business* / *Organization*, where before you saw neither on that page.
5. Run the [Schema Markup Validator](https://validator.schema.org/) on `/specialty-equipment-we-handle` and
   confirm zero parse errors.
6. Wait 2-4 weeks, then recheck Page Indexing. Expect: "Page with redirect" to *stay high* (that is fine and
   expected), "Not found," "Soft 404," and "Crawled – currently not indexed" to drop to near zero.

**Set expectations on the numbers.** After these fixes you should still expect roughly 34 indexed and roughly
100+ not indexed, because the `.html` and trailing-slash redirects are permanent and correct. Do not chase the
"not indexed" number to zero — it is not a health metric. The metrics that matter are: zero *errors*, 34/34
live pages indexed, and rich results validating.

---

# How to actually rank on page one

Fixing the above gets you technically clean, which is table stakes, not a ranking. For a local B2B ITAD firm
in Cincinnati, the ranking levers in order of impact:

1. **Google Business Profile.** For "electronics recycling Cincinnati" style queries the map pack sits above
   the organic results and is won primarily through GBP, not your website. Claim and fully complete it,
   matching your on-site NAP exactly (P2-3), post regularly, and build genuine reviews. Your `RecyclingCenter`
   schema (P0-1) reinforces GBP but does not replace it.
2. **Local citations.** Consistent NAP across directories. This is also why P0-4 (`www` not resolving) matters
   more than it looks — citations frequently use the `www` form.
3. **Build out `/about/locations`.** At 106 words it is your weakest local asset. It should be your strongest:
   full NAP, hours, service-area map, driving directions, and dedicated sections for Cincinnati and Dayton.
4. **You already have the content depth.** Pages at 1,200-1,700 words with genuine technical specificity
   (NIST 800-88r2 Clear/Purge/Destroy, R2v3, chain of custody) are the right approach — this is real
   subject-matter expertise, which is what E-E-A-T rewards. Add named authors with credentials, certification
   badges with proof, and case studies with real numbers.
5. **Fix the internal linking** (P2-1). Your best content asset, `/faqs` at 2,860 words, has one raw-HTML
   inbound link. Server-rendering the nav plus adding contextual cross-links is a large, free gain.
6. **Earn links.** Local business associations, Cincinnati and Dayton chambers of commerce, sustainability and
   R2 certification directories, university and hospital vendor pages. For a local B2B service, a modest
   number of genuinely relevant local links outperforms volume.

---

# Files in this directory

| File | Purpose |
|---|---|
| `fixes/robots.txt` | Adds sitemap, blocks `/partials/` and the `/404` template |
| `fixes/sitemap.xml` | Removes the redirecting `/sustainability`; adds `/privacy`, `/terms`, `/sitemap`; adds `lastmod` placeholders |
| `fixes/_redirects` | Cloudflare Pages redirect rules — `www`, the 404-ing PDF, double-slash normalisation |
| `fixes/_headers` | `X-Robots-Tag: noindex` on `/partials/*` |
| `fixes/schema/homepage-organization.jsonld` | Corrected + expanded homepage entity graph (fixes P0-1) |
| `fixes/schema/specialty-equipment-we-handle.jsonld` | Corrected JSON-LD (fixes P0-2) |
| `verify.sh` | Re-runs every check in this audit against the live site |
