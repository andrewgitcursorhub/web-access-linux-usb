# Structured data strategy — core-asset-sol.com

Audit and templates. Built from your **live markup as of 2026-08-22**, validated against the
official schema.org vocabulary (every type, property and enum in all five files: **0 issues**).

| File | Page |
|---|---|
| `_business-node.jsonld` | The shared business entity — goes on all 34 pages |
| `1-services-overview.jsonld` | `/services` |
| `2-industries-overview.jsonld` | `/industries-served` |
| `3-service-data-destruction.jsonld` | `/services/data-destruction` — pattern for all 7 service pages |
| `4-industry-healthcare.jsonld` | `/industries-served/healthcare` — pattern for all 8 industry pages |

---

## 1. Audit of what is live now

Your markup is valid JSON and the types are correct. The problems are structural, not syntactic.

| # | Finding | Where | Impact |
|---|---|---|---|
| 1 | `provider` is a 4-property stub pointing at an `@id` defined only on the homepage | all 22 service + industry pages | Those pages carry **no business entity at all** — no address, geo, or hours — while targeting "… in Cincinnati" queries |
| 2 | `areaServed` is a flat array of plain strings | all service + industry pages | Strings are legal but create no place entities. No regional coverage expressed anywhere |
| 3 | `numberOfItems: 6`, but 7 service pages exist | `/services` | `asset-tracking-reporting` is absent from the catalog entirely |
| 4 | Items typed `Service` on one hub, `WebPage` on the other | `/services` vs `/industries-served` | Two hubs, two models, for the same kind of thing |
| 5 | No `@id`, `description`, `isPartOf` or `breadcrumb` on the services `CollectionPage` | `/services` | The industries hub has all four. Inconsistent |
| 6 | No `image` in structured data on **any** page except the homepage | 33 pages | You have purpose-built hero images that nothing declares |
| 7 | `og:image` is the company logo on **every** page | all pages | Every share and preview looks identical |
| 8 | Zero compliance properties | all industry pages | HIPAA appears 11 times in healthcare copy and 0 times in its markup |
| 9 | `audience` is generic `Audience` with a prose string | industry pages | `MedicalAudience` exists and is far more specific |
| 10 | No `WebPage` node | `/services/data-destruction` | The healthcare page has one; the service pages do not |
| 11 | Hub label disagrees with destination | `/industries-served` item 8 | Labelled "Telecom & Aerospace", points at `/test-measurement-equipment` |
| 12 | No link between industry pages and the service pages they are built from | all | Google sees 15 unrelated pages instead of a services × sectors matrix |

Finding 1 is the big one. It is why your service pages have weak local signals despite good
local copy.

---

## 2. The architecture: one `@graph` per page

Every page emits a single `<script type="application/ld+json">` containing one `@graph` with:

```
@graph
├── RecyclingCenter   #organization    ← identical on all 34 pages
├── WebSite           #website         ← identical on all 34 pages
├── ImageObject       #primaryimage    ← per page
├── WebPage           #webpage         ← per page
├── BreadcrumbList    #breadcrumb      ← per page
├── Service / ItemList #service        ← per page
└── FAQPage           #faq             ← where applicable
```

**Why the business node must repeat on every page.** Google evaluates each page independently
and does **not** resolve `@id` references across pages. A bare `{"@id": ".../#organization"}` on
a service page resolves to nothing unless the full node is in that page's graph. That is the
single change that fixes finding 1.

Ship it from the same shared include that renders your header and footer — authored once,
appears everywhere, cannot drift.

### About the earlier `service-page-provider.jsonld` that confused you

You were right to be confused. That file was abbreviated and used stale values — it said
`457 South Cooper Ave.` and `addressLocality: "Cincinnati"`, and it omitted `geo`,
`knowsAbout`, `contactPoint` and `email`.

`_business-node.jsonld` supersedes it. It is built field-for-field from your live homepage,
every addition is marked `_ADDED_`, and the one field I deliberately did **not** change is
called out. Use that file as the source of truth and delete the old one from your working set.

---

## 3. Geographic strategy — local authority plus regional coverage

You have one facility and a service area reaching Columbus, Indianapolis and Louisville. These
are two different claims and they need two different mechanisms.

### The three-layer `areaServed` model

```jsonc
"areaServed": [
  { "@type": "GeoCircle", "geoRadius": "193121", … },   // 1. operational truth: 120-mile pickup radius
  { "@type": "State", "name": "Ohio" },                  // 3. broad coverage
  { "@type": "City",  "name": "Columbus", … },           // 2. named markets
]
```

1. **`GeoCircle`** — how far you actually drive. `geoRadius` is in **metres** unless wrapped in
   a `Distance`. 193121 m = 120 miles, which reaches all three metros from Lockland. Set it to
   your real radius; do not inflate it.
2. **`City` nodes** — the specific markets, each with `containedInPlace`.
3. **`State` nodes** — Ohio, Indiana, Kentucky.

Your live markup has layer 3 partially and layer 2 for Cincinnati/Dayton only. Columbus,
Indianapolis, Louisville, Indiana and Kentucky appear **nowhere** in your structured data.

### The address stays "Lockland"

Your live homepage now says `addressLocality: "Lockland"`, which is correct — that is the real
municipality. **Do not change it to Cincinnati.** NAP must match your Google Business Profile
exactly, and inconsistent NAP costs more than the keyword gains.

Cincinnati authority comes from three other places: `areaServed`, page content, and your GBP
(where the service-area setting, not the address, defines coverage).

One gap this creates: **"Lockland" appears 0 times in the visible text of every page** while
being your schema `addressLocality`. Google cross-references markup against page content. Put
the full address in your footer and on `/about/locations` so the two agree. Phrase it naturally
— "our Lockland, Ohio processing facility, minutes from downtown Cincinnati off I-75" gets both
terms in honestly.

### What structured data will and will not do

`areaServed` helps Google understand your entity. It will **not** put you in the local pack in
Columbus, Indianapolis or Louisville — that requires a physical presence in those cities.

What you *can* win there is organic (blue-link) ranking for queries like "IT asset disposition
Columbus Ohio". That needs dedicated pages with genuinely distinct content, not markup. See
`../KEYWORD-AND-CONTENT-AUDIT.md` §4 for the page plan.

---

## 4. Compliance as structured data

This is your differentiator and it is currently invisible to machines. Healthcare copy mentions
HIPAA 11 times and HITECH 3 times; the healthcare markup mentions neither.

Three mechanisms, used together:

**`additionalProperty`** — flat, factual name/value pairs any parser can read:

```jsonc
{ "@type": "PropertyValue", "name": "Primary regulatory framework",
  "value": "HIPAA Security Rule (45 CFR Part 164 Subpart C)" }
```

**`about` → `DefinedTerm`** — the stronger signal. Links your service to the actual published
standard at an authoritative URL rather than to a keyword string:

```jsonc
{ "@type": "DefinedTerm", "name": "HIPAA Security Rule",
  "url": "https://www.hhs.gov/hipaa/for-professionals/security/index.html",
  "inDefinedTermSet": { "@type": "DefinedTermSet", "url": "https://www.hhs.gov/hipaa/" } }
```

**`audience`** — the narrowing. `MedicalAudience` for healthcare, `EducationalAudience` for
education, `BusinessAudience` elsewhere. All are real schema.org types.

### The per-industry compliance matrix

| Page | `audience` | Regulatory regime |
|---|---|---|
| healthcare | `MedicalAudience` | HIPAA Security Rule, HITECH |
| financial-services | `BusinessAudience` | GLBA, PCI DSS, SOX |
| government | `BusinessAudience` | FISMA, NIST 800-171 |
| education | `EducationalAudience` | FERPA, COPPA |
| it-data-center | `BusinessAudience` | SOC 2, ISO 27001 |
| media-entertainment | `BusinessAudience` | MPA content security |
| industrial-equipment | `BusinessAudience` | ITAR where applicable, EPA |
| test-measurement | `BusinessAudience` | ITAR / EAR where applicable |

NIST 800-88r2 and R2v3 are common to all — they belong on the service pages. The regime above
is what makes each industry page genuinely distinct rather than a near-duplicate.

### Language accuracy

Avoid "HIPAA compliant" as a vendor claim. HIPAA has no certification body, so no vendor is
certified compliant. "HIPAA-aligned" and "supports your HIPAA compliance obligations" are
accurate and defensible. The healthcare template uses that phrasing.

One entry worth highlighting: `"Business Associate Agreement": "BAA executed prior to
engagement"`. For a healthcare buyer that is frequently the first procurement question, and
almost no competitor states it in markup.

---

## 5. Enterprise and Fortune 500 targeting

Be clear-eyed: **there is no structured data property for "Fortune 500".** Schema.org has no
mechanism to target a company tier, and Google has no rich result for it.

What structured data *can* do is describe the buyer:

```jsonc
"audience": {
  "@type": "BusinessAudience",
  "audienceType": "Multi-site health system IT, HIM, compliance and privacy officers",
  "numberOfEmployees": { "@type": "QuantitativeValue", "minValue": 500 }
}
```

`BusinessAudience` supports `numberOfEmployees`, `yearlyRevenue` and `yearsInOperation`. Use
`numberOfEmployees.minValue` to signal enterprise scale.

The real levers are content, not markup, and right now they are absent: "Fortune 500" appears
**0 times** across your entire site, "Fortune 1000" once (on `/about`), and "headquarters" only
on the Cincinnati page. See `../KEYWORD-AND-CONTENT-AUDIT.md` §5.

---

## 6. Per-page images

You asked how to specify each page's image correctly. Three things must agree:

1. The `ImageObject` in the graph, referenced by `WebPage.primaryImageOfPage` **and** `Service.image`
2. The `<meta property="og:image">` tag
3. The actual `<img>` in the page body

```jsonc
{
  "@type": "ImageObject",
  "@id": "https://core-asset-sol.com/services/data-destruction#primaryimage",
  "url":        "https://core-asset-sol.com/assets/.../data-destruction-service-hero.png",
  "contentUrl": "https://core-asset-sol.com/assets/.../data-destruction-service-hero.png",
  "width": 811, "height": 541,
  "caption": "NIST 800-88r2 data destruction and media sanitization …",
  "representativeOfPage": true
}
```

`representativeOfPage: true` marks it as the page's main image rather than decoration. Declaring
it as a node with an `@id` means both the page and the service reference one image rather than
duplicating the URL.

### Your current image state

| Page | Hero file | Dimensions | Size |
|---|---|---|---|
| `/services` | `services-overview-hero.png` | 848 × 565 | 521 KB |
| `/industries-served` | `industry-overview-hero.png` | 912 × 632 | 610 KB |
| `/services/data-destruction` | `data-destruction-service-hero.png` | 811 × 541 | 481 KB |
| `/industries-served/healthcare` | `industries-healthcare-hero.png` | **453 × 302** | 314 KB |
| logo | `logo_website_final_cropped2.png` | 402 × 372 | 100 KB |

Three problems:

- **Every one is undersized.** 1200 px on the long edge is the working target for
  image-bearing results, and 1200 × 630 is the standard for `og:image`. The healthcare hero at
  453 × 302 is well below anything useful.
- **They are very heavy for their pixel count.** 314 KB for a 453 × 302 PNG is roughly 20× what
  it should be. Re-export as WebP at 1200 × 630 and you will get a much larger image at a
  fraction of the weight.
- **`og:image` points at the logo everywhere.** Point each page at its own hero.

The logo at 402 × 372 is fine — Google's minimum for `Organization.logo` is 112 × 112.

---

## 7. Rich result eligibility by page type

| Page type | Available today | Available with work |
|---|---|---|
| Homepage | Organization, Local business | — |
| `/about/locations` | Local business | — |
| Service pages | Breadcrumb | **Video** (data-destruction, hard-drive-destruction) |
| Industry pages | Breadcrumb | — |
| Collection pages | Breadcrumb | — |
| `/resources/*` | Breadcrumb | Article |

Honest summary: **Breadcrumb, Organization and Local business are the only rich results these
page types can produce**, plus Video once you add it. `Service`, `CollectionPage`, `ItemList`,
`FAQPage` and `DefinedTerm` produce no SERP enhancement.

That does not make them worthless. They are what makes the site machine-readable for AI
Overviews and LLM retrieval, and they are how Google understands that you are an entity that
does data destruction for healthcare organizations in the Ohio Valley. Ship them for
comprehension, not for pixels.

Two notes:
- **`ItemList` carousels** only apply to Recipe, Course list, Restaurant and Movie. Your hub
  pages will not produce a carousel.
- **`FAQPage`** — Google removed the FAQ rich result for all sites on 7 May 2026. Keep the
  markup; expect nothing in the SERP from it.

---

## 8. Order of implementation

1. **Ship `_business-node.jsonld` on all 34 pages** via the shared include. Single biggest win —
   it fixes the provider stub, adds local signals to all 22 service and industry pages, and adds
   the regional footprint everywhere at once.
2. **Fix `/services`** — the missing 7th service, the `@id`/`description`/`isPartOf`/`breadcrumb`,
   and the image.
3. **Fix `/industries-served`** — retype items to `Service`, add `audience` and compliance,
   resolve the "Telecom & Aerospace" label mismatch.
4. **Roll template 3 across all 7 service pages**, template 4 across all 8 industry pages.
5. **Re-export the hero images** at 1200 × 630 WebP and repoint `og:image` per page.
6. **Add `VideoObject`** to the data destruction page when the video is live.

Validate each with the [Rich Results Test](https://search.google.com/test/rich-results) and the
[Schema Markup Validator](https://validator.schema.org/). The first shows Google eligibility;
the second shows every entity you emitted, which is what you want for the non-rich-result types.

Strip all `_README` and `_comment` keys before shipping. They are inert — JSON-LD drops terms
that are not in the `@context` — but they are documentation, not markup.
