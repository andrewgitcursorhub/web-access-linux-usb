# Rich Results Roadmap — core-asset-sol.com

Verified 2026-08-17 against Google's official
[structured data gallery](https://developers.google.com/search/docs/appearance/structured-data/search-gallery)
(26 supported features) and the
[LocalBusiness](https://developers.google.com/search/docs/appearance/structured-data/local-business)
reference.

---

## Part 1 — Should the 22 service pages use `RecyclingCenter` instead of `Organization`?

**Short answer: no — and doing the straight rename would actively make things worse.** The type name is not
what is broken on those pages.

### Why `Organization` is not the bug

`RecyclingCenter` is a *subtype* of `LocalBusiness`, which is itself a subtype of `Organization`:

```
Thing > Organization > LocalBusiness > RecyclingCenter
```

So `Organization` is not wrong on the service pages. It is simply less specific, and for a `provider`
reference that is a perfectly normal thing to be.

The actual defect is that `provider` is a **stub that points at a node which does not exist on that page**:

```json
"provider": {
  "@id": "https://core-asset-sol.com/#organization",
  "@type": "Organization",
  "name": "Core Asset Solutions",
  "url": "https://core-asset-sol.com/"
}
```

`https://core-asset-sol.com/#organization` is defined **only on the homepage**, and **Google does not resolve
`@id` references across pages.** Each page is evaluated on its own. So on all 22 service and industry pages,
the provider collapses to a two-property stub. The address, phone, hours, service areas, and social profiles
never reach those pages.

### Why the naive rename is a trap

Google requires exactly two properties for LocalBusiness rich result eligibility:

| Required | |
|---|---|
| `name` | Text |
| `address` | PostalAddress |

If you change `"@type": "Organization"` to `"@type": "RecyclingCenter"` and leave the stub as-is, you have
just declared a local business on 22 pages **with no `address`**. That is an incomplete LocalBusiness, and the
Rich Results Test will report a missing-required-field error on every one of them. A bare `Organization` stub
with `name` + `url` is at least valid and error-free.

So the rename alone converts 22 silently-weak pages into 22 loudly-invalid ones.

### What to do instead

Emit the **complete** business node on every page inside a single `@graph`, and have the `Service` reference it
locally. Then the `@id` resolves on the page where it is used, and `RecyclingCenter` carries the `address` it
needs.

```json
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "RecyclingCenter",
      "@id": "https://core-asset-sol.com/#organization",
      "name": "Core Asset Solutions",
      "url": "https://core-asset-sol.com/",
      "telephone": "+1-513-433-7818",
      "priceRange": "$$",
      "address": {
        "@type": "PostalAddress",
        "streetAddress": "457 South Cooper Ave.",
        "addressLocality": "Cincinnati",
        "addressRegion": "OH",
        "postalCode": "45215",
        "addressCountry": "US"
      }
    },
    {
      "@type": "Service",
      "@id": "https://core-asset-sol.com/services/data-destruction#service",
      "name": "Data Destruction",
      "provider": { "@id": "https://core-asset-sol.com/#organization" }
    }
  ]
}
```

Note that `provider` is now a **pure reference** (`@id` only) because the full node is present in the same
graph. That is the correct JSON-LD idiom and it is what your current markup was reaching for.

The practical way to ship this: the business node is identical on all 34 pages, so make it a shared include
emitted by the same mechanism that will server-render your header and footer (audit item P2-1). Author once,
appears everywhere, never drifts.

Full working file: [`fixes/schema/service-page-provider.jsonld`](fixes/schema/service-page-provider.jsonld).

### One thing not to change

Keep `"@type": "Service"` for the service itself. The page is *about a service*; the *provider* is the
business. Do not retype the `Service` node as `RecyclingCenter` — that would claim each service page is a
separate physical recycling facility, which is false and would fragment your entity.

### Summary

| | Verdict |
|---|---|
| Rename `Organization` → `RecyclingCenter` on the 22 stubs and stop | **No.** Creates 22 missing-`address` errors |
| Leave the stubs exactly as they are | Acceptable, but wastes the opportunity |
| Emit the full `RecyclingCenter` node in a `@graph` on every page | **Do this** |
| Retype the `Service` nodes to `RecyclingCenter` | **No.** Actively wrong |

---

## Part 2 — Which rich results can this site actually win?

Google supports 26 structured data features. Most are irrelevant to an ITAD company (Recipe, Movie, Math
solver, Vacation rental). Here is the honest filter.

### Tier 1 — Fix what you already have. No new content required.

| Rich result | Pages | Status |
|---|---|---|
| **Breadcrumb** | all 34 | Working on 33. Broken on `/specialty-equipment-we-handle` (invalid JSON) |
| **Organization** | `/` | Blocked by the `Recycling Center` typo. Wins logo + knowledge panel |
| **Local business** | `/`, `/contact`, `/about/locations` | Blocked by the same typo. **Highest value result available to you** |

For local business, `name` and `address` are required; add `geo` (5+ decimal places), `telephone`,
`openingHoursSpecification`, `priceRange` (under 100 chars), `url`, and `image`. You already have hours on
`/contact` — they just need to live on a valid entity.

Be clear-eyed about the ceiling here: LocalBusiness markup and your Google Business Profile are separate
systems reconciled separately. The markup reinforces GBP; it does not substitute for it. Valid markup earns
*eligibility*, never a guarantee.

### Tier 2 — New content that unlocks genuinely new rich result types. Highest ROI.

**1. Job posting → build `/careers`**

`/careers` currently returns 404. `JobPosting` markup produces a dedicated rich result *and* enters listings
into Google's job search experience, which is a separate, much less contested surface. For a growing ITAD
firm hiring technicians, drivers, and warehouse staff, this is the single biggest untapped rich result on this
list. Required: `title`, `description`, `datePosted`, `hiringOrganization`, `jobLocation`. Add
`baseSalary` and `employmentType` — they materially improve match quality. Remove or set `validThrough` when
a role closes; stale postings are the most common cause of losing this result.

Example: [`fixes/schema/examples/job-posting.jsonld`](fixes/schema/examples/job-posting.jsonld)

**2. Event → build `/events`**

This is the most natural fit on the list for a recycling business and almost nobody in your vertical does it.
Community e-waste collection days, business drop-off events, shred events, and campus collection drives all
qualify. `Event` rich results are visually prominent and they generate exactly the local-relevance signals
that support your Cincinnati and Dayton rankings. Required: `name`, `startDate`, `location`. Use
`eventAttendanceMode` and `eventStatus`, and mark up **one `Event` per event**, not one per calendar page.

Example: [`fixes/schema/examples/event.jsonld`](fixes/schema/examples/event.jsonld)

**3. Video → add process videos to your top service pages**

A facility tour, a hard-drive shredding demonstration, or a chain-of-custody walkthrough on
`/services/hard-drive-destruction` and `/services/data-destruction`. `VideoObject` puts a thumbnail in the
results and makes the page eligible for the Video tab — a meaningful click-through lever for a service where
buyers want proof. Required: `name`, `description`, `thumbnailUrl`, `uploadDate`. Add `duration`,
`contentUrl`, and a transcript.

Example: [`fixes/schema/examples/video-object.jsonld`](fixes/schema/examples/video-object.jsonld)

### Tier 3 — Supporting markup. Modest rich result value, real E-E-A-T value.

**4. Article** on `/resources/itad-circular-economy` and `/resources/reporting-esg`

These are currently typed `WebPage`. They are genuine editorial content and should be `Article` (or
`BlogPosting`). The rich result upside for a non-news site is modest and worth being honest about, but
`author`, `datePublished`, and `dateModified` are real quality signals for a compliance-driven service where
expertise is the product.

Example: [`fixes/schema/examples/article.jsonld`](fixes/schema/examples/article.jsonld)

**5. Profile page** for team bios

`ProfilePage` + `Person` on an `/about/team` page. Named people with real credentials (R2v3 lead auditor,
NAID-certified technicians) is one of the strongest E-E-A-T signals available to a business selling regulatory
compliance.

Example: [`fixes/schema/examples/profile-page.jsonld`](fixes/schema/examples/profile-page.jsonld)

### Conditional

**Product** — only if `/services/remarketing` ever lists actual refurbished units with prices and
availability. Do not add `Product` to a service page; it needs real inventory with `offers`.

**Dataset** — your ESG report data could technically qualify for Google Dataset Search. Niche, high effort,
and Dataset Search traffic is academic rather than commercial. Low priority.

### Do not build these

| | Why |
|---|---|
| **Review / AggregateRating on your own business** | Google: "If the entity that's being reviewed controls the reviews about itself, their pages that use LocalBusiness or any other type of Organization structured data are ineligible for star review feature." Applies to embedded third-party widgets too. `/about/client-testimonials` is the trap. No stars, and fabricated markup risks a manual action |
| **More FAQPage** | Rich result fully removed 7 May 2026 for all sites. Keep what you have; build no more |
| **HowTo** | Removed from Search 14 Sept 2023 |
| **Sitelinks search box / `SearchAction`** | Discontinued globally 21 Nov 2024 |
| **Carousel** | Only combines with Recipe, Course list, Restaurant, or Movie. None apply |
| **Course list, Q&A page, Discussion forum, Speakable, Recipe, Movie, Math solver, Vacation rental, Software app** | Not applicable to this business |
| **Employer aggregate rating** | For platforms aggregating ratings *about* employers, not for the employer's own site |

---

## Suggested order of work

1. Fix `Recycling Center` → `RecyclingCenter` and fix the two invalid JSON-LD blocks (audit P0-1, P0-2).
   Unlocks Organization + Local business, repairs the last broken breadcrumb. **Highest impact, smallest edit.**
2. Move the full business node into a shared `@graph` include on all 34 pages. Fixes the dangling `@id` and
   makes every subsequent addition trivial.
3. Build `/careers` with `JobPosting`. New rich result type, low competition.
4. Build `/events` with `Event`. New rich result type, strong local signal.
5. Add `VideoObject` to the two highest-intent service pages.
6. Retype the two resource pages to `Article`; add `/about/team` with `ProfilePage`.

After each step, run the [Rich Results Test](https://search.google.com/test/rich-results) on the affected URL.
It is the authoritative eligibility check — if it reports eligible, Google's systems agree. Errors block rich
results outright; warnings are worth fixing but do not block.

Verified 2026-08-17: `/careers`, `/events`, and `/about/team` all currently return 404, so those paths are
free to use.

### Two notes on using the example files

**Strip the `_comment` keys before deploying.** JSON-LD processors drop keys that do not map to a term in the
`@context`, so `_comment` is harmless, but it is documentation for you and should not ship.

**Every `REPLACE_WITH_*` token is deliberate.** Geo coordinates, dates, salaries, durations, and credentials
have to be real values. Placeholder or invented data in structured data is a guidelines violation, and on a
compliance vendor's site fabricated credentials are a problem well beyond SEO.
