# Caribbean Shipper Directory

A directory of Caribbean barrel and freight shippers operating out of US metros.
Companies with a working website of their own are published. Those without one
(no site, social-only, dead site) go into a private prospect pipeline for
outreach. Full spec: [`docs/spec.md`](docs/spec.md).

## Stack

Elixir, Phoenix LiveView, Ash 3 + AshPostgres, Oban, Req, Floki, Postgres.

## Setup

```
mix setup                       # deps, assets
mix ash.setup                   # create db, run migrations
mix run priv/repo/seeds.exs     # import seed CSV + run presence checks
mix phx.server
```

- Directory: http://localhost:4000 (search), `/ship-barrel` (routes),
  `/shippers/:slug` (company pages)
- Admin: http://localhost:4000/admin (dev basic auth `admin` / `admin`; prod uses
  `ADMIN_USERNAME` / `ADMIN_PASSWORD`)

The seed script makes HTTP requests to each company's site. Use
`SKIP_PRESENCE_CHECK=1 mix run priv/repo/seeds.exs` when offline, or every site
would be classified as dead.

## Tasks

```
mix directory.import_seed [path.csv]      # idempotent CSV import
mix directory.check_presence [slug ...]   # run presence checks now, print verdicts
mix directory.import_fmc [--metros brooklyn,queens|all] [--file list.xlsx]
mix directory.google_lookup [--limit N]   # needs GOOGLE_PLACES_API_KEY
mix directory.refresh_search_keys         # after changing Metros/Destinations aliases
mix precommit                             # compile, format, credo --strict, test
```

## Environment variables

- `GOOGLE_PLACES_API_KEY`: Places API (New). The field mask includes
  `websiteUri`/`nationalPhoneNumber`, which bill at the Text Search Enterprise SKU.
- `ADMIN_USERNAME` / `ADMIN_PASSWORD`: prod only.
- `TOKEN_SIGNING_SECRET`: prod only, signs owner sign-in tokens.
- `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM_NUMBER`: prod
  phone codes (dev/test log them instead; see `Claims.PhoneSender.Log`).
- `MAIL_FROM`: sender address for claim codes, sign-in links, and the digest.
  Prod also needs a Swoosh adapter configured in `config/runtime.exs`
  (e.g. Postmark or Resend). Dev mail shows at `/dev/mailbox`.
- `ADMIN_EMAIL`: receives the daily follow-up digest.
- `LEAD_PRICE_CENTS`: price per delivered quote request (default 0 = free beta).

## Discovery (P1)

Decision (2026-09-29): **FMC first, Google only for enrichment, no Yelp.**
Google's Places terms allow storing only `place_id` indefinitely, and Yelp's
allow only 24h caching, so neither is used as a source of stored contact data.

1. **FMC OTI list** (`Discovery.Fmc`, weekly cron + "Import FMC list" button).
   This is public data. It's downloaded from the "download the list of all
   active…" button on https://www2.fmc.gov/oti/NVOCC.aspx (an .xlsx, about
   9,800 rows).
   - Cross-reference: existing companies matching a licensee by phone or exact
     normalized name/DBA get `fmc_license_no` and fill blank fields.
   - Discovery: every licensee in the requested metros (`Discovery.Metros`,
     by ZIP prefix; default NYC) becomes a company. Names with a Caribbean
     keyword are auto-confirmed. The rest go to **Triage** (most NYC licensees
     are general or air-cargo forwarders, and a name can't tell you which are
     Caribbean).
2. **Google Places lookup** (`Discovery.GooglePlaces`, `:google` queue, 2 at a
   time). Runs for confirmed companies without a website. Stores only the
   `place_id` plus our derived `google_has_website` flag:
   - no website on Google → prospect (`presence_status: none`)
   - Google lists a website → review queue, where an admin opens the Maps link,
     enters the URL, and the presence checker verifies it
   - not found / permanently closed → review queue
3. **Dedupe** (`Directory.Ingest`): same source record → phone → name + address
   (street words abbreviated). A same-name company in a compatible state is
   flagged as a possible duplicate unless both records have different phones
   and addresses. The **Duplicates** tab merges (`Directory.Merge`) or dismisses.

Triage "Not Caribbean" sets status `excluded`. The company and its sightings
are kept so reruns don't recreate it.

## Public directory (P2)

Only `status: published` companies are ever shown. The `:search` read action
filters on it, and company pages and route pages 404 for everything else.

| Path | What |
| --- | --- |
| `/?from=brooklyn&to=guyana&service=barrel` | `DirectoryLive`: search. Filters live in the URL. |
| `/shippers/:slug` | Company page with contact, destinations, services, sailing schedule, FMC license, verified date, and `LocalBusiness` JSON-LD |
| `/ship-barrel` | Every route, grouped by origin |
| `/ship-barrel/:metro-to-:destination` | SEO route page. Exists only when at least one published company serves the route (no thin pages). |
| `/sitemap.xml`, `/robots.txt` | Generated. robots.txt disallows `/admin` and points at the sitemap. |

Routes come from canonical slugs derived on every save (`SetSearchKeys`):
`metro_slugs` from city/origin metros via `Metros` aliases ("Lauderhill" →
`broward`; "Jamaica" → `queens` only when the state is NY), and
`destination_slugs` via `Destinations` aliases ("T&T" →
`trinidad-and-tobago`). A generic "Caribbean" maps to no destination.
`/admin/companies/:id` edits a company and shows which metros and
destinations it maps to.

Canonical and sitemap URLs come from the endpoint's `url` config, so set
`PHX_HOST` in production.

## Claims and owners (P3)

`/shippers/:slug/claim` (`ClaimLive`, `ShipperDirectory.Claims`): the owner of
a published, unclaimed listing proves control with a 6-digit code sent to
- an email **at the website's domain** (webmail like Gmail is refused), or
- the **listed phone**, by voice call (works for landlines) or SMS.

Codes are stored only as bcrypt hashes. They expire after 15 minutes, 5
wrong guesses lock the claim, and a listing allows 3 claims per hour. On
success the claimant's email becomes a `User` who owns the company, and a
magic sign-in link (AshAuthentication) goes to that email. Owners edit at
`/my/listings/:slug`. They can't change the business name or internal
notes, and a changed website is re-verified at once (a dead one hides the
listing). Admins see the owner and claim attempts on the company edit page
and can remove an owner.

## Outreach CRM (P3)

`/admin/prospects` (`ProspectsLive`): prospects filtered by metro, sorted by
fit (`Crm.Fit`, with reasons) or follow-up date, with one-click call
outcomes (no answer +2 days, left message +3, interested +2, not
interested) and a panel for custom events and history. Logging
(`Changes.ApplyOutreachOutcome`) moves status (prospect → contacted,
not interested → declined, customer, do-not-contact) and enforces:
- the **suppression list**: nothing can be logged for `do_not_contact`, and
  suppressed companies never appear in the CRM or the CSV export
- **TCPA**: SMS/WhatsApp can be logged only after an `opted_in_messaging`
  outcome records consent

`FollowUpDigestWorker` emails `ADMIN_EMAIL` the due follow-ups daily at 12:00 UTC.
The app doesn't send cold outreach itself. When it does (CAN-SPAM), add a
physical address and an unsubscribe link.

## Leads and placements (P4)

**Pay-per-lead** (`ShipperDirectory.Leads`, `/quote`): "Get free quotes" on
route pages and "Get a quote" on company pages open one form that goes to up
to 3 shippers **the consumer picks**. The consent text naming exactly those
shippers is built on the server and stored on the `Lead`.
- Only published, claimed listings whose owner turned on "Receive quote
  requests" (`accepts_leads`, with the price shown) get leads, so nobody is
  billed without agreeing. Buttons only appear when someone can receive.
- Each `LeadDelivery` locks in `LEAD_PRICE_CENTS` when it's sent. The shipper
  gets an email, works the request at `/my/leads`, and can dispute it. An
  admin accepting a dispute marks it `credited`.
- `/admin/leads`: disputes, a monthly ledger per company (credited and free
  deliveries excluded) with CSV export for invoicing, and recent requests.
- Abuse: honeypot field, at most 3 requests per email/phone per day.

**Sponsored placements** (`ShipperDirectory.Placements`, `/admin/placements`):
admin-recorded slots (sold and invoiced offline) for one route or every route
from a metro, with dates and price. Active sponsors show in a block labeled
"Sponsored" above organic results on route pages and metro searches, and
aren't repeated below. A metro-wide sponsor only shows on routes it serves.
Max 2 overlapping per slot.

Not built: online payment (Stripe) for leads or placements, click/impression
reporting for sponsors, and booking commission (9.4).

## Domain: `ShipperDirectory.Directory`

- **Company**: `presence_status` (from the checker; `nil` = unchecked) and
  `status` (directory/CRM lifecycle). Dedupe key = normalized phone, else
  normalized name + address (`Normalize`). A company matches an existing one on
  either key.
- **Sighting**: raw record per source, upserted on `[source, external_id]`.
- **PresenceCheck**: append-only log of each check.
- **OutreachEvent**: CRM touchpoints (resource only, no UI yet).
- **DiscoveryRun**: one FMC import (params, counts, error).
- **Claim**: one claim attempt (method, destination, code hash, attempts, status).
- **Lead** / **LeadDelivery**: a consumer quote request and its per-shipper,
  priced deliveries.
- **Placement**: a sponsored slot (metro, optional destination, dates, price).

`ShipperDirectory.Accounts`: `User` (listing owners, magic link only) and `Token`.

### Presence checker (`Directory.Presence`)

`classify/2` is pure apart from the HTTP call (stubbed with `Req.Test` in
tests). `check/2` records a `PresenceCheck` and applies `transition/3`:

| Verdict | Result |
| --- | --- |
| `listed` | published (from discovered / verified / prospect) |
| `needs_review` | review queue; a published company is unpublished |
| `dead_site` / `social_only` / `none` | prospect (from discovered / verified / published) |

CRM statuses (`contacted`, `customer`, `declined`, `do_not_contact`) are never
changed by the checker. Companies with `hold_for_review` (seed rows marked
`verify`) stay in review whatever the verdict, until an admin approves or
rejects them.

A daily Oban cron (`PresenceRecheckScheduler`, 06:00 UTC) re-queues every
company not checked in 30 days, so dead sites get demoted automatically.

## Seed results (2026-09-29)

| Outcome | Companies |
| --- | --- |
| Published (9) | A2 Global, Carib Ocean Freight, Chrisdan, Dennis, FCS, Laparkan, SSMC Xpress, Safari, USG |
| Prospects (5) | Barrel-It, D.A.D, Medas, T&T Shippers, Williams |
| Review queue (3) | Quality One (domain is NXDOMAIN), Caribbean Shipping Freight (flagged in seed list), Trans Caribe (returns 403 to non-browser clients) |

FMC import for NYC on the same day: 389 new companies (Brooklyn 54, Queens 253,
Manhattan 51, Staten Island 17, Bronx 16, minus the seed matches). 4 new ones were auto-confirmed Caribbean and
385 are waiting in triage. 5 seed companies were matched to their FMC license
(Dennis, D.A.D, Quality One, Safari, Trans Caribe).

## Not built yet

Google keyword-grid discovery (dropped with the ToS decision), Yelp, online
payments, sponsor analytics, booking commission.
