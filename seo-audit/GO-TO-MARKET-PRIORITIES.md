# Getting found: priority order for a new ITAD provider in Cincinnati

Written 2026-08-22, after auditing your site and the actual Cincinnati search landscape.

---

## Who you are actually competing against

I looked. Your instinct about "companies in Texas" is precisely right, and it is worth seeing
the detail because it tells you exactly where you can and cannot win.

**STS Electronic Recycling** — headquartered in **Jacksonville, Texas**. 600,000 sq ft facility.
R2v3 and NAID AAA certified. They run at least four dedicated Cincinnati pages:

```
/cincinnati-itad
/cincinnati-oh
/cincinnati-certificate-of-destruction
/cincinnati-general-it-asset-guide
```

Those pages are very well built. They name Kroger, Procter & Gamble, Fifth Third Bank,
Cincinnati Children's Hospital, UC Health, TriHealth, Western & Southern, and the University of
Cincinnati — with employee counts. They name Hamilton, Butler, Clermont, Kenton and Boone
counties. They name Downtown, Over-the-Rhine, Blue Ash, Evendale, West Chester and Mason.

**CyberCrunch** — facility in **Greensburg, Pennsylvania**. R2v3 and NAID AAA. Runs
`/services/itad-services/cincinnati`.

Also present: Re-IT Shred, I.T. Supply Solutions, Cobalt ITAD, ShredTronics.

### Why they outrank you

Three reasons, and only one of them is about your website:

1. **Domain authority.** Older domains with years of accumulated links. You cannot close this
   quickly and you should not try.
2. **Volume of hyper-specific local content.** They have more Cincinnati pages than you do, and
   theirs are denser with verifiable local detail.
3. **Actual certifications.** R2v3 and NAID AAA, prominently. Yours are pending.

### The weakness you can exploit

**STS is in Texas. CyberCrunch is in Pennsylvania. Neither can appear in the Cincinnati local
pack.**

The local pack — the map results with three businesses — requires a verified physical location
in the area. It renders **above** the organic blue links for local-intent queries. A 600,000
sq ft facility in Jacksonville, Texas is structurally ineligible for it in Cincinnati.

You have a facility in Hamilton County. They do not. That is the entire wedge, and it is the one
place where a company nobody has heard of can appear above a national competitor within weeks
rather than years.

**You are currently not using it at all.** There is no Google Business Profile linked anywhere on
your site — no `hasMap`, no GBP URL, no reviews, on any page I checked.

---

## The positioning argument you are not making

STS's own page says equipment is "transported to our 600,000 sq ft facility" — in Texas.
CyberCrunch processes in Pennsylvania.

For a Cincinnati IT director or compliance officer, that means their drives leave Ohio and travel
roughly 900 miles before anything happens to them. Your facility is 15 miles from downtown
Cincinnati. A client can drive over and watch the destruction happen.

For a buyer whose actual anxiety is chain of custody, that is a strong argument, it is true, and
no out-of-state competitor can match it.

You are barely making it. Across your entire site, "we come to" appears **once** and "at your
facility" appears **once**. Your differentiator is described as "logistics coordination."

Three things to say plainly, everywhere:

- **Your equipment never leaves the region.** Name the distance. "Processed 15 minutes from
  downtown Cincinnati, not shipped out of state."
- **You can watch.** Witnessed destruction is only practical when the processor is local.
- **Speed.** You mentioned fast processing and resale turnaround. Same-week pickup and
  short time-to-report is a real operational advantage — say it with numbers.

One caution: STS names actual Cincinnati enterprises on their pages. Do not copy that pattern
with companies you do not serve. Talk about industries, corridors and business districts
honestly; name clients only with permission.

---

## Priority order

Ordered by *time to impact per unit of effort*, not by how interesting the work is.

### 1. Google Business Profile — do this first, this week

Highest leverage item available to you, and it is not really SEO.

- Claim and verify the listing at your real physical address.
- Primary category: most likely **Electronics recycling company**. Secondary: computer service,
  waste management service, recycling center. The primary category is the single biggest local
  ranking factor after proximity.
- Set the **service area** to cover Cincinnati, Dayton, and outward toward Columbus,
  Indianapolis and Louisville.
- Add real photos: the building, the dock, the processing floor, the shredder, trucks, the team.
  Listings with genuine photos convert dramatically better than stock imagery.
- Fill in hours, services, and a description.
- **Start collecting reviews immediately.** Even a handful of detailed B2B reviews is a strong
  differentiator, because most ITAD competitors have very few. Ask every completed client.
- Post regularly. Pickups completed, certifications progress, e-waste events.

Realistic timeline: verification takes days to a couple of weeks; local pack movement follows
within weeks. Nothing else on this list is that fast.

Then add the GBP share URL to `hasMap` in your business node — the placeholder is already there.

### 2. Fix the certification language — before you push for visibility

This is a risk, and it is worth handling before you succeed at getting found.

You told me certifications are pending. Your site currently says:

| Page | "certified" | "R2v3" | "pending" / "in progress" |
|---|---|---|---|
| `/` | 5 | 2 | **0** |
| `/services` | 4 | 2 | **0** |
| `/services/electronics-recycling` | 5 | **8** | **0** |

Including phrases like *"Certified IT recycling for all types of business IT equipment"* and
*"certified data destruction services"*, with no qualifier anywhere on the site.

You may mean "we issue a certificate of destruction" rather than "we are a certified company."
An enterprise procurement reviewer will not read it that way, and they will ask for your R2v3
certificate number. Discovering the gap at that point costs you the deal and the reputation.

What to do:

- Say **"R2v3 certification in progress"** with a target date. That is honest, and against a
  competitor set that leads with certification it is far better than silence.
- Keep claiming **NIST 800-88r2 alignment**. That is a *standard*, not a certification — you can
  legitimately say you follow it, and you already describe it well.
- Be precise about "certificate of destruction" (a document you issue) versus "certified"
  (an accreditation you hold). Those are different words doing different work.
- **Delete the `hasCertification` block from `_business-node.jsonld`** until you are certified.
  I flagged this in the file, but it matters more now that I know the status.
- The moment R2v3 lands, it becomes a launch moment: press, LinkedIn, the SERI directory
  listing (a genuinely good link), and a site-wide update.

### 3. Resolve your address — you currently have two

| Source | Address |
|---|---|
| Your schema and site | 457 S Cooper Ave., **Lockland**, OH **45215** |
| Your Alignable listing | **West Chester**, OH |
| Your former `/service-area` page (now redirected) | "located in West Chester, Ohio", "100-mile radius of West Chester" |

Lockland (45215) and West Chester (45069) are different municipalities. NAP consistency is a
foundational local ranking factor, and right now the web has two different answers for where you
are.

Pick the one that is your real operating address, make the Google Business Profile match it
exactly, and then correct every other listing. Do this **before** building citations, or you will
propagate the conflict.

### 4. Finish the outstanding technical fixes — a few hours

These are already documented in `NEXT-STEPS.md` and they are cheap:

- **The www redirect still sends every visitor to a 404** (the literal `:splat` bug). Anyone
  typing or linking `www.core-asset-sol.com` hits an error page.
- **Remove `Disallow: /partials/`** — it is currently blocking Google from discovering your
  navigation.
- Fix the 404ing PDF and the internal links pointing at redirects.

None of this makes you rank. All of it removes friction that is actively costing you.

### 5. Ship the business node and regional coverage across all 34 pages

From `structured-data/_business-node.jsonld`. This is the fix that gives your service and
industry pages a real business entity and local signals, and it adds Columbus, Indianapolis,
Louisville, Indiana and Kentucky to markup where they currently appear **nowhere**.

Note: you previously had a `/service-area` page and redirected it into `/about/locations`, which
is now 106 words with no images. That consolidation went the wrong way. Rebuild the service-area
content — it is exactly what communicates the Ohio/Kentucky/Indiana footprint you asked about.

### 6. LinkedIn — parallel with everything above

Your buyers are IT directors, compliance officers and procurement managers. They are all on
LinkedIn, and for enterprise B2B this will likely produce recognisable contacts faster than
organic search will.

- Build out the company page properly. It is already in your `sameAs`.
- Have the team post about actual work: a decommission completed, how NIST Purge differs from a
  format, what a certificate of destruction should contain.
- Connect with IT and facilities leadership at Cincinnati and Dayton employers.
- This also feeds your entity signals — the `sameAs` and `Person` markup in templates 5 and 6
  exist partly to connect your site to those profiles.

### 7. Write the content you can actually win

Do not fight for "electronics recycling Cincinnati" first. STS has four pages, a decade of
authority and real certifications aimed at it. You will lose that fight for a while.

Go where they are weak — queries where *being local* is the answer:

- "same week e-waste pickup Cincinnati"
- "witnessed hard drive destruction Cincinnati"
- "data center decommissioning Cincinnati"
- "on-site hard drive shredding Dayton"
- "local electronics recycler Ohio" / "ITAD vendor near me"
- "electronics recycling Lockland / Blue Ash / Evendale / Mason / West Chester"

Lower volume, much lower competition, and the traffic is qualified. A buyer searching "witnessed
destruction Cincinnati" is telling you they want a local processor — that is your customer, and a
Texas facility is a poor answer to that query.

Then build the city pages: Dayton, Columbus, Indianapolis, Louisville. Genuinely researched,
not templated.

### 8. Local citations and links

- Cincinnati USA Regional Chamber, Dayton Area Chamber, local manufacturing and IT associations
- Ohio EPA and county solid-waste district recycler directories
- Local business directories with consistent NAP
- Sponsor or run a community e-waste collection event — you mentioned you started with e-waste
  drives. That is a local-news story and a natural link, and it is `Event` markup on your site.
- After certification: the SERI R2 directory

For a local business, a modest number of genuinely local links outperforms volume.

### 9. Head terms — the long game

"Electronics recycling Cincinnati" and similar. Twelve months plus, contingent on everything
above. Worth pursuing, not worth building the plan around.

---

## The honest part

For enterprise B2B ITAD, the website is usually not what generates first contact. A Fortune 1000
IT director does not typically Google a disposal vendor — they get a referral, or procurement
issues an RFP, or a peer names someone. The site's job is to make you look credible and
substantial when someone checks you out after hearing your name.

Yours already does that job reasonably well. The technical writing is genuinely good — the
NIST 800-88r2 Clear/Purge/Destroy explanation and the circular economy piece show real subject
matter expertise, which is rarer than it should be in this industry.

So run two tracks:

- **Demand capture** (items 1, 4, 5, 7, 8) — be findable when someone looks.
- **Demand generation** (items 2, 3, 6, plus direct outreach) — make people look in the first
  place.

If nobody knows you exist yet, the second track moves faster. The first track makes sure the
second one converts. Get the Google Business Profile live this week, fix the certification
language before anyone important reads it, and treat SEO as the compounding asset it is rather
than the thing that will produce a client next month.

---

## The first two weeks, concretely

| | Action |
|---|---|
| 1 | Decide the canonical address — Lockland or West Chester |
| 2 | Claim and verify the Google Business Profile at that address |
| 3 | Correct the certification language site-wide; add "R2v3 in progress" |
| 4 | Fix the www Redirect Rule (Dynamic + `concat()`), remove `Disallow: /partials/` |
| 5 | Add GBP photos, hours, categories, service area; publish the first post |
| 6 | Ask every completed client for a Google review |
| 7 | Correct the Alignable listing and any other directory to the canonical NAP |
| 8 | Ship the shared business node with regional `areaServed` on all 34 pages |
| 9 | Rebuild `/about/locations` into a real facility page with photos |
| 10 | Add the "processed locally, never leaves the region" message to the homepage hero |
