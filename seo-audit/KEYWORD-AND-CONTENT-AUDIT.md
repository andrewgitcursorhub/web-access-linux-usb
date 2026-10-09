# Keyword, content and site-layout audit

Measured against live page text on **2026-08-22**. Counts are occurrences in rendered visible
text, scripts and styles stripped.

Note on titles and descriptions: you said your rewrites are not live yet, so the values below
are the old ones. I have not re-audited length — I have flagged only the parts that interact
with the strategy questions.

---

## 1. The headline finding: your regional footprint is invisible

You told me you serve Columbus, Indianapolis and Louisville. Here is where those words appear:

| Page | columbus | indianapolis | louisville | indiana | kentucky |
|---|---|---|---|---|---|
| `/` | – | – | – | – | – |
| **`/cincinnati-itad-electronics-recycling`** | **3** | **2** | **1** | **4** | **2** |
| `/services` | – | – | – | – | – |
| `/services/data-destruction` | – | – | – | – | – |
| `/services/electronics-recycling` | – | – | – | – | – |
| `/industries-served` | – | – | – | – | – |
| `/industries-served/healthcare` | – | – | – | – | – |
| `/about` | – | – | – | – | – |
| `/about/locations` | – | – | – | – | – |
| `/resources` | – | – | – | – | – |
| `/contact` | – | – | – | – | – |

**Twelve mentions total, all on one page.** Your homepage, every service page, every industry
page, your locations page and your contact page contain zero evidence that you operate outside
Cincinnati and Dayton. Your structured data says the same thing — `areaServed` stops at
Southern Ohio.

As far as Google is concerned you are a Cincinnati-and-Dayton company. That is the gap between
your stated goal and your site.

By contrast, primary geo is well covered:

| Page | cincinnati | dayton | ohio | lockland |
|---|---|---|---|---|
| `/` | 7 | 2 | 2 | – |
| `/cincinnati-itad-electronics-recycling` | 22 | 3 | 21 | – |
| `/services/data-destruction` | 12 | 2 | 5 | – |
| `/industries-served/healthcare` | 9 | 3 | 4 | – |
| `/about/locations` | 5 | 1 | 1 | – |

**"Lockland" appears zero times site-wide** while being the `addressLocality` in your schema.
Google cross-references markup against page content, and right now they disagree. Put the full
address in the footer and on `/about/locations`.

---

## 2. Keyword cannibalisation — four pages chasing one query

| Page | Title (live) |
|---|---|
| `/` | IT Asset Disposition and Secure Electronics Recycling **in Cincinnati** |
| `/services` | Services Overview \| Core Asset Solutions **Cincinnati** |
| `/services/electronics-recycling` | **Electronics Recycling in Cincinnati** |
| `/cincinnati-itad-electronics-recycling` | **Cincinnati Electronics Recycling** and IT Asset Disposition Programs |

The last two are competing head-on for "electronics recycling Cincinnati". When two pages
target one query, Google picks one and often picks the weaker one, and neither ranks as well as
a single consolidated page would.

`/services/data-destruction` mentions Cincinnati **12 times** — more than your homepage. Every
page is reaching for the same local term instead of owning a distinct intent.

### Recommended one-page-one-intent map

| Page | Primary target | Secondary |
|---|---|---|
| `/` | `IT asset disposition Cincinnati` | brand, ITAD company Ohio |
| `/cincinnati-itad-electronics-recycling` | `electronics recycling Cincinnati` | e-waste pickup Cincinnati |
| `/services` | `ITAD services` (non-geo hub) | electronics recycling services |
| `/services/electronics-recycling` | `business electronics recycling` + **pickup mechanics** | corporate e-waste pickup |
| `/services/data-destruction` | `NIST 800-88 data destruction` | certified data destruction, media sanitization |
| `/services/hard-drive-destruction` | `hard drive shredding` | on-site hard drive destruction |
| `/industries-served/healthcare` | `healthcare electronics recycling` | hospital ITAD, HIPAA data destruction |
| `/about/locations` | `electronics recycling drop off Cincinnati` | Lockland facility, near me |
| **new** `/service-area` | `ITAD service area Ohio` | regional coverage |
| **new** `/service-area/columbus` | `IT asset disposition Columbus Ohio` | electronics recycling Columbus |

The principle: **service pages own the service term, geo pages own the geo term.** Right now
your service pages are competing on geo, which is why `/services/data-destruction` says
"Cincinnati" twelve times.

Practical move: pull most of the Cincinnati repetition out of the service pages. One natural
mention plus the `areaServed` markup is enough. Let the Cincinnati page and the location pages
carry geo.

---

## 3. Your layout question: is the current split optimal?

Your plan — regional service area on `/cincinnati-itad-electronics-recycling`, facility
information on `/about/locations`.

**The instinct is right. Separating "where we serve" from "where we are" is exactly correct.**
The execution has two problems.

### Problem 1: a Cincinnati-named URL is the wrong host for regional content

`/cincinnati-itad-electronics-recycling` has "Cincinnati" in the URL, the title, the H1 and 22
times in the body. Every signal says *Cincinnati page*. Putting Columbus, Indianapolis and
Louisville content there fights the page's own signals — and it is why those 12 regional
mentions are doing nothing for you.

A page cannot be the Cincinnati page and the regional page at once.

### Problem 2: `/about/locations` is far too thin to anchor local authority

106 words. **Zero images.** One mention of "pickup". No regional mentions. No structured data
beyond a bare `WebPage` and breadcrumb. This should be one of your strongest local assets and
it is currently one of your weakest pages.

### Recommended structure

```
/about/locations          → THE FACILITY PAGE  (local authority anchor)
                            Full NAP matching GBP exactly, including "Lockland"
                            Hours, embedded map, driving directions from I-75
                            Photos of the facility, dock, secure processing area
                            What happens on site: intake, sanitization, R2v3 processing
                            Drop-off instructions and appointment info
                            Carries the full LocalBusiness node
                            Target: "electronics recycling drop off Cincinnati"

/cincinnati-itad-electronics-recycling
                          → THE CINCINNATI MARKET PAGE
                            Stays purely Cincinnati. Remove the regional content.
                            Target: "electronics recycling Cincinnati"

/service-area             → NEW. THE REGIONAL HUB
                            Map of the 120-mile pickup radius
                            Drive-time bands and scheduling expectations by distance
                            Named metros with links to city pages
                            Carries the GeoCircle + full areaServed markup
                            Target: "ITAD service area Ohio"

/service-area/columbus    → NEW. City pages, one per metro.
/service-area/dayton         Each needs genuinely distinct content: local industry
/service-area/indianapolis   mix, named corridors and business parks, real drive
/service-area/louisville     times, relevant state e-waste regulations.
```

**On the city pages, one honest caveat.** Without a physical location in Columbus,
Indianapolis or Louisville you will not enter the local pack there — that requires a real
address. What you can win is organic ranking for "IT asset disposition Columbus Ohio" style
queries, which for enterprise B2B is often the more valuable traffic anyway, because those
searchers are researching vendors rather than looking for a drop-off point.

Do **not** generate these by templating one page and swapping the city name. Near-duplicate
doorway pages are a spam policy violation and they do not rank. Four genuinely researched pages
beat twenty templated ones.

---

## 4. Your pickup question: where should the on-site pickup message live?

First, the measurement — this message is barely present:

| Page | pickup | on-site | "we come to" | "at your facility" | logistics |
|---|---|---|---|---|---|
| `/` | 9 | 1 | – | – | – |
| `/cincinnati-itad-electronics-recycling` | 5 | 3 | – | – | 12 |
| `/services` | 3 | 3 | – | – | 1 |
| `/services/electronics-recycling` | **13** | – | – | – | 6 |
| `/services/data-destruction` | 2 | 10 | – | **1** | – |
| `/industries-served` | 3 | 3 | **1** | – | 1 |
| `/industries-served/healthcare` | 1 | 1 | – | – | 6 |
| `/about/locations` | 1 | – | – | – | – |

"We come to" appears **once** site-wide. "At your facility" appears **once**. The single
clearest statement of your core differentiator is essentially absent, and it is phrased in
abstractions — "logistics", "collection" — instead of the plain language a buyer searches with.

### Answer: `/services/electronics-recycling`, as the explainer — with a repeated module everywhere else

**`/services/electronics-recycling` gets the full mechanics.** It already carries the strongest
pickup signal (13 mentions) and it is the natural intent match. Build out: how scheduling works,
lead times, what you bring, whether you palletize and wrap, minimum volumes, insurance and
liability, what the client needs to prepare, what documentation arrives afterward. You already
have `/resources/Pickup_Checklist.pdf` — link it prominently.

**The homepage states it in the hero and links out.** It is your primary conversion message, not
a place for depth.

**Every service and industry page gets a short repeated module** — three or four sentences
confirming on-site pickup applies to that service or sector, linking to the explainer. Consistent
wording, not reworded per page.

**Geo-modified pickup queries belong to the geo pages.** "E-waste pickup Columbus" is a job for
`/service-area/columbus`, not for the electronics recycling page.

**Do not create a separate `/pickup` page.** It would cannibalise
`/services/electronics-recycling`, which is exactly the problem identified in §2.

### Say it in plain language

Use the words buyers actually type. "We come to your facility," "we pick it up," "no cost to
you," "you don't move anything." Currently the site says "logistics coordination" and
"collection programs" — accurate, but nobody searches that way.

### And say it in the markup

```jsonc
"providerMobility": "dynamic"
```

That is the schema.org way of stating the provider travels to the customer. It belongs on every
service you perform on site. Both service templates include it, plus an explicit
`additionalProperty` entry: `"On-site service available": "Yes — …"`.

---

## 5. Enterprise and Fortune 500 targeting

| Page | fortune 500 | fortune 1000 | headquarters | enterprise | multi-site |
|---|---|---|---|---|---|
| `/` | – | – | – | 2 | 1 |
| `/cincinnati-itad-electronics-recycling` | – | – | 2 | 3 | 5 |
| `/services` | – | – | – | 2 | – |
| `/services/data-destruction` | – | – | – | 3 | 1 |
| `/industries-served/healthcare` | – | – | – | 1 | 3 |
| `/about` | – | **1** | – | 2 | 1 |
| `/about/locations` | – | – | – | – | – |
| `/resources` | – | – | – | – | – |

**"Fortune 500" appears zero times on your entire website.** "Fortune 1000" appears once.
"Headquarters" appears only on the Cincinnati page.

This is your stated primary target and there is no content supporting it.

Worth knowing: your service radius covers an unusually dense concentration of large corporate
headquarters — Cincinnati, Columbus, Indianapolis and Louisville between them host a
substantial number of Fortune 500 and Fortune 1000 head offices. That is a genuinely strong
regional story and you are telling none of it.

What to add:

1. **A section on `/service-area`** describing enterprise headquarters coverage across the four
   metros. Name the corridors and business districts. This is where the Fortune 500 language
   belongs.
2. **An enterprise-scale block on each industry page** — multi-site coordination, consolidated
   reporting across locations, master service agreements, vendor onboarding and security
   review, insurance certificates. These are the things large-company procurement asks about
   and they are absent.
3. **Content proving you can operate at that scale** — volume handled, sites served
   simultaneously, turnaround on a full floor decommission. Use real numbers only.
4. **In markup**, `BusinessAudience.numberOfEmployees.minValue` as shown in template 4.

Set expectations honestly: markup will not win Fortune 500 business. Procurement teams read the
site, check certifications and ask for references. The structured data supports the story; the
content has to carry it.

---

## 6. Compliance coverage — this part is working

| Page | hipaa | hitech | nist 800-88 | r2v3 | glba | ferpa | fisma | soc 2 |
|---|---|---|---|---|---|---|---|---|
| `/services/data-destruction` | 2 | – | **9** | – | – | 1 | 1 | 1 |
| `/industries-served` | 3 | – | 2 | 2 | 1 | 2 | – | – |
| `/industries-served/healthcare` | **11** | **3** | 6 | 2 | – | – | – | – |

This is genuinely good. Healthcare concentrates HIPAA and HITECH; data destruction concentrates
NIST 800-88. The differentiation you asked about already exists in the copy.

**The problem is that none of it is in the structured data.** The healthcare page mentions HIPAA
eleven times in prose and zero times in markup. Template 4 fixes that — see
`structured-data/README.md` §4.

Two gaps worth closing:

- **R2v3 is thin on `/services/data-destruction`** (0 mentions) despite being your core
  certification. It should appear on every service page.
- **GLBA, FISMA and SOC 2 barely appear anywhere.** Each should be concentrated on its industry
  page the way HIPAA is on healthcare.

---

## 7. Other content observations

**`/resources` has zero geographic mentions** — no Cincinnati, no Ohio, nothing. It is
completely disconnected from your local strategy. The guides are good assets; give them local
framing where honest.

**`/about/locations` has zero images.** For a facility page this is the most obvious gap on the
site. Photos of the building, the dock, the secure processing area, and the shredder do more for
buyer trust than another paragraph.

**Alt text is in progress.** Current state: `/industries-served/healthcare` 27 of 27 images
missing alt, `/industries-served` 12 of 12, `/services` 7 of 11. The Cincinnati page is nearly
done at 1 of 9 — so the work is clearly underway, just not finished on the industry pages.

**Hero images are undersized and heavy.** All four are under 1000 px wide, and the healthcare
hero is 453 × 302 at 314 KB. Re-export at 1200 × 630 WebP. Details in
`structured-data/README.md` §6.

---

## 8. Priority order

1. **Fix the regional gap.** Ship the expanded `areaServed` on all 34 pages, then build
   `/service-area` plus city pages. This is the largest gap between your goal and your site.
2. **Rebuild `/about/locations`** into a real facility page with photos, full NAP including
   Lockland, hours and a map.
3. **Resolve the cannibalisation** between `/services/electronics-recycling` and
   `/cincinnati-itad-electronics-recycling`, and pull surplus geo out of the service pages.
4. **Build out the pickup explainer** on `/services/electronics-recycling` in plain language,
   plus the repeated module elsewhere.
5. **Ship the compliance markup** from templates 3 and 4 across all 15 service and industry pages.
6. **Add enterprise and Fortune 500 content**, anchored on `/service-area`.
7. **Finish alt text**, re-export heroes at 1200 × 630 WebP, repoint `og:image` per page.
