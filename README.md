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

- Directory: http://localhost:4000
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
mix precommit                             # compile, format, credo --strict, test
```

## Environment variables

- `GOOGLE_PLACES_API_KEY`: Places API (New). The field mask includes
  `websiteUri`/`nationalPhoneNumber`, which bill at the Text Search Enterprise SKU.
- `ADMIN_USERNAME` / `ADMIN_PASSWORD`: prod only.

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

## Domain: `ShipperDirectory.Directory`

- **Company**: `presence_status` (from the checker; `nil` = unchecked) and
  `status` (directory/CRM lifecycle). Dedupe key = normalized phone, else
  normalized name + address (`Normalize`). A company matches an existing one on
  either key.
- **Sighting**: raw record per source, upserted on `[source, external_id]`.
- **PresenceCheck**: append-only log of each check.
- **OutreachEvent**: CRM touchpoints (resource only, no UI yet).
- **DiscoveryRun**: one FMC import (params, counts, error).

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

Google keyword-grid discovery (dropped with the ToS decision), Yelp, public
search + SEO routes, claim flow, outreach CRM UI, leads.
