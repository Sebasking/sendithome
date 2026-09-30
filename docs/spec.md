# Caribbean Shipper Directory: Technical Spec (for Claude Code)

## 1. Goal
Build a directory of Caribbean barrel and freight shippers operating out of US metros (NYC first, then NJ, CT, FL, Boston).
- Company **has an online presence** (own working website) -> publish in the public directory.
- Company **lacks one** (no site, Facebook-only, dead site) -> keep out of the public directory, add to a private **prospects** pipeline for outreach.

The prospects list is the business. The directory is the funnel and credibility asset.

## 2. Stack
Elixir, Phoenix LiveView, Ash Framework (AshPostgres), Oban for jobs, Req for HTTP, Floki for HTML parsing, Postgres. Deploy target: Fly.io or similar.

## 3. Data model (Ash resources)
**Company**
- name, slug, phone, email, address, city, state, lat, lng
- website_url, facebook_url, instagram_url, yelp_url, google_place_id, fmc_license_no
- presence_status enum: `listed`, `social_only`, `dead_site`, `none`, `needs_review`
- status enum: `discovered`, `verified`, `published`, `prospect`, `contacted`, `customer`, `declined`, `do_not_contact`
- services (array: barrel, box, vehicle, container, air, pickup, delivery), origin_metros, destinations (array of islands)
- source (array), last_checked_at, notes

**Sighting**: raw record per source (source, external_id, raw_payload jsonb, company_id). Dedupe key = normalized phone, else normalized name + address.

**PresenceCheck**: company_id, checked_at, url, http_status, final_url, is_parked, is_placeholder, has_contact_info, has_ssl, verdict.

**OutreachEvent**: company_id, channel (call, sms, whatsapp, email, in_person), outcome, notes, next_action_at.

**Lead** (later phase): consumer quote requests routed to a company.

## 4. Discovery pipeline (Oban workers)
1. **Google Places API** text search: "barrel shipping Brooklyn", "Caribbean shipping Queens", etc., per metro x keyword grid. Pull `websiteUri`, phone, address, place_id. A missing `websiteUri` is a strong prospect signal.
2. **Yelp Fusion** search for the same queries. Yelp often lists small shippers that have no site.
3. **FMC licensed NVOCC/OTI list**: cross-reference to confirm legitimacy and add license numbers (verify the current FMC data source and format first).
4. **Seed CSV** (`shipper_seed_list.csv`): import first.
5. Manual sources later: Facebook pages, carnival and diaspora community directories, referrals from family contacts.

Respect each API's terms of service. Do not scrape sites that forbid it.

## 5. Presence check (classification)
For each company with any known URL:
- Request the URL with Req (follow redirects, 10s timeout, 2 retries).
- `listed`: 2xx, real content, shows the company name or phone, not parked.
- `dead_site`: DNS failure, 4xx/5xx, parked-domain page, or a `business.site` URL (Google shut that product down, so treat as dead).
- `social_only`: only facebook/instagram/yelp URLs, no own domain.
- `none`: no URL from any source.
- `needs_review`: ambiguous, or the domain doesn't match the company (see Quality One in the seed list). Route to an admin review queue.
Recheck published companies every 30 days; demote automatically if they go dead.

## 6. Public directory (LiveView)
- Home: search by origin metro + destination island + service.
- Company page: contact, services, destinations, sailing schedule if known, link out to their site.
- SEO: server-rendered pages like `/ship-barrel/brooklyn-to-guyana`.
- Claim flow: owners verify by phone code or email at the domain, then edit their listing.
- No public star ratings in v1 (see risks).

## 7. Admin and prospect CRM
- Admin review queue for `needs_review` and duplicates.
- Prospects table: filter by metro, sort by fit, one-click log of outreach events, follow-up reminders.
- Export prospects to CSV.
- Suppression list honored everywhere (`do_not_contact`).

## 8. Compliance
- SMS/WhatsApp outreach needs prior consent under TCPA. Use calls, email, and in-person for cold outreach; WhatsApp only after they opt in.
- Email follows CAN-SPAM (physical address, unsubscribe).
- Store only business contact data.

## 9. Monetization hooks to build for (later phases)
1. Featured/sponsored placement per route.
2. Pay-per-lead quote requests.
3. Prospect services: simple website plus booking page, WhatsApp shipment-status bot (ties to the barrel-tracking idea), tracking page, subscription pricing.
4. Booking commission, if payments are added.

## 10. Phases
- **P0 (weekend)**: Ash resources, CSV import, presence checker, admin table.
- **P1**: Google Places + Yelp discovery, dedupe, review queue.
- **P2**: Public directory with search and SEO routes.
- **P3**: Claim flow, outreach CRM.
- **P4**: Lead routing and paid placements.

## 11. Acceptance criteria (P0-P1)
- Importing the seed CSV creates 17 companies, deduped on rerun.
- Presence checker correctly classifies the 12 sites and the 5 prospects (spot-check by hand).
- Discovery run for "Brooklyn" returns at least 30 unique companies after dedupe.
- Every published company has a verified working URL and a `last_checked_at` under 30 days.

## 12. Risks
- Reviews of shippers are often angry (lost barrels, stuck containers). Public ratings invite disputes and defamation claims. Start without them.
- "No website" is a spectrum. Many shippers run on Facebook, phone, and WhatsApp. Some are fine with that.
- Data goes stale as small operators close or rebrand.
