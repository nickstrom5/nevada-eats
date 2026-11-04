# Nevada Eats (nv-eats) — notes for Claude Code sessions

Started 2026-10-27 from `../state-prompts/NEVADA_PROMPT.md` and `../STATE_EATS_PLAYBOOK.md` (read both). Pipeline and app ported from
`../nc-eats/` (tn-eats lineage); `link_blocklist.py`, `tracking_params.py`, `injection.py` identical to fl-eats/co-eats; website blocklist =
nc-eats' union (882). Never modify another state's folder. Leaderboard artifact link in `LOCAL.md`.

- Brand (Nick, 2026-10-27, `playbook/05-naming.md`): "Nevada Eats: Restaurants", Home Screen "Nevada Eats"; icon = silver-dollar pancakes on
  Valley of Fire sandstone #C1440E (`scripts/icon-concepts.swift` `pancakes()`, copied into `scripts/make-brand.swift`); palette flag cobalt
  #0047AB + sandstone (gold #F2B705 / silver #A7A9AC fills only, sagebrush #5C6E52 in the ridgeline); header = Basin and Range ridgeline.
  Washoe inspections: records request first (`playbook/records-requests.md`, Nick sends).
- Sources: `playbook/12-sources.md`. Only the Southern Nevada Health District (all of Clark County) publishes inspections: grade cards
  A/B/C/X with demerits, shown as published, never derived. Permits are grouped into outlets (`pipeline/official.py` `load_snhd`): resort
  facilities split by the outlet in the permit name. Licenses: Clark County, Las Vegas, Henderson, Reno (frozen 2025-10-01) → `loffs`,
  "serves alcohol" from an own active on-premises liquor license only. An X closure with no inspection for 30+ days removes the place.
  Adult venues: `pipeline/build_adult.py` builds `data/research/adult_venues.json` from adult-cabaret/adult-store licenses and the City
  of Las Vegas Erotic Dance, Topless Club and Adult Nightclub licenses (Active or Collections); hand-checked entries in that file survive
  a rebuild (Treasures' Highland Dr frontage, Foxy Girls at Scores' address; QA NV-1, 2026-10-28). nevada.py also drops places whose
  website is a club's (`webs` pattern); the app's testBundledDataGuards checks names and websites (DataGuards.adultNames/adultSites).
- Rebuild: `cd pipeline && ../.venv/bin/python fetch_official.py` (SNHD zip + 4 license layers), `fetch_overture.py`, `fetch_extras.py`, then
  `../.venv/bin/python listings.py && ../.venv/bin/python geocode_official.py && ../.venv/bin/python calibrate.py && ../.venv/bin/python build_adult.py
  && ../.venv/bin/python nevada.py && NV_APP=1 ../.venv/bin/python nevada.py`, then `cd .. && .venv/bin/python scripts/make-leaderboard.py` and republish
  `site/index.html` with nevada.json, nv_detail.json, nv_shapes.json. Copy `data/app/places.json data/app/detail-*.json` into `NevadaEats/Resources/`.
  The app export asserts no Google-style key anywhere (google|gmap|in21|rating|review|price...).
- Link check: `cd pipeline && CHECK_WORKERS=4 ../.venv/bin/python check_websites.py [--retry-transient]` (detached; saves every 500,
  atomic); Nevada casino-resort hosts are in `injection.CASINO_HOSTS_OK` and `check_websites.CASINO_PLACE`. Back up
  `data/nv/website_check.json` before stopping one; re-export the app after.
- Research: `data/research/michelin.json` (24 places, read 2026-10-27), `jbf.json` (Peppermill, Bob Taylor's, Lotus of Siam x2, Casa
  Playa), `pipeline/build_research.py` (21 hand-checked places: basque 4, buffets 4, chinatown 5, plate lunch 6, steak 2, oldest 5;
  casino classics and saloons still empty), leads in `data/research/app/LEADS.md`. Tag bits: basque 1, classic 2, buffet 4,
  chinatown 8, plate 16, steak 32, saloon 64, oldest 128.

## App (ported 2026-10-27 from nc-eats)
- `NevadaEats/` (bundle com.nevadaeats.ios, Home Screen "Nevada Eats"); `xcodegen generate`; build with
  `DEVELOPER_DIR="/Applications/Xcode 1.app/Contents/Developer"` (27.1, 27A9275 on 2026-10-27: check it's a public release before any
  archive), `-derivedDataPath DerivedData`. Tests 2026-10-28 on iOS 27.0: iPhone 17 Pro Max 52 unit + 6 UI pass; iPad Pro 13" (M5)
  52 unit + 5 UI pass (Bib Gourmand skips on iPad by design). After QA NV-1 (2026-10-28 evening): iPhone 52 unit + 7 UI pass (launch
  5.07 s at load 15.9), iPad 52 unit + 5 UI pass (launch 4.84 s at load 8.7). Earlier the same day launch read 6.0-6.8 s at load 6-14
  against the 6 s bar (DC 4.5-4.7 s); the bundle load is 0.32 s (PerformanceTests): re-measure before submission. Simulators are deleted after each run (create "iPhone 17 Pro Max"/"iPad Pro 13-inch (M5)" on iOS 27.0).
  An iOS 27.1 "iPhone Duo" shows the app on its cover screen (SmokeUITests `tab(_:)`, `SCREEN=1 bash scripts/capture-screenshots.sh`).
- Names: research names follow the place's own spelling (JT Basque, Unko Frank's Hawaiian BBQ); `tidy()` writes "Bbq" as BBQ;
  SNHD corner codes stay upper case ("NWC St Rose & Maryland"). Follow-up: 434 listing addresses lack a street type ("3575 S Decatur
  101 &102"); prefer the official address when the house number matches.
- Same place twice (QA P1, 2026-10-28): SNHD's own points can be 2-33 km off (Red Robin, CPK, Shake Shack, the St Rose Pkwy and
  Downtown Summerlin strips), so a permit missed its listing and stood as a second place. Fixed at the cause: `official.street_key`
  reads SAINT as ST, FT as FORT, MT as MOUNT and drops a suite run into a typeless street ("Lavender Hill 8B3", "Decatur 101-102");
  `listings_util.official_match` takes a same-name, same-address match beyond 2 km (to 30 km) when town or zip agree and the street
  directions don't conflict, allows one spelling slip in a long street name, and no longer counts a cuisine word ("Hawaiian") as a
  shared name word; nevada.py merges two copies of a name holding one license record at one street address, keeps the listing's
  point over a far SNHD point, but moves a listing to its SNHD point when a county/Henderson/Reno license point backs that one (Taco
  Boom); the early brand dedup keys on the street too (UNLV's Starbucks at 4505 S Maryland Pkwy vs 4505 E Charleston Blvd).
  "x" ids came from names norm_name empties ("Cafe 86"): `name_key` falls back to the name's letters and digits. Websites ship only
  as one clean address (`one_url`/`shipped_url`: a listing's link with a space ships the checked page it landed on).
- Cuisine buckets: "European" (not the template's "German & European": Nevada's European places are mostly French).
- SNHD inspections: core `in` = [jur, grade index (A,B,C,X), date, demerits]; detail `in` = {n, p (permit), h: [[date, grade, demerits,
  itype]], i: [[id, demerits, text]], o: [[label, permit, grade, date, demerits]]}.

## Website (ported 2026-10-27)
- `scripts/make-site.py` (BASE /nevada-eats; `NV_DOMAIN=nevada.eatsranked.com` once Nick's CNAME resolves), `scripts/explore.js`
  (storage prefix `nveats-`, SNHD cards + demerits, Nevada outline/map), `scripts/qa-site.py` (`--static` in seconds; the full run
  drives Chrome at 375 and 1280 px). A guide gets a web page at 4 places (steak has 2: app only). One city page so far (Las Vegas).
- App data for OTA: `python3 scripts/publish_app_data.py` writes `docs/data/app/` (`.gitignore` anchors `/data/`, so it's committable).
- Listing: `scripts/make-listing.py` writes `playbook/06-app-store-listing.md`, `13-app-review-reply.md`, `app-store/listing.json`.

## Still to do
1. Link check: done 2026-10-27 (first pass 4,184 ok; `--retry-transient` added 20 -> 4,204). App, site, OTA data and the leaderboard
   artifact (v3) carry it. Re-run both (`--recheck-ok` before a submission) after the next data refresh.
2. Screenshots done 2026-10-28: `playbook/app-store/iphone` (8, 1320x2868) and `ipad` (6, 2064x2752), framed by
   scripts/appstore-screenshots.py from `app-store/raw/`; landing page uses the iPhone 17 Pro Max captures. The iPad set shows Chinatown
   instead of honors ("MICHELIN & James Beard" truncates in the iPad list column) and the Charleston Grinds 2 Da Max for plate lunch
   (Aloha Specialties' history has B cards and a closure: no negative mark in an App Store image).
   After the QA P1 fixes (2026-10-28 night): retook iPhone 01-home (9,573 restaurants), 05-inspections (6,069 places), iPad 01-home and
   the two landing images; iPhone unit tests 52/52 (guards and tracking tests included).
3. Research casino classics and saloons; Washoe records request (Nick sends, `playbook/records-requests.md`).
4. Nothing outward (repo, push, App Store Connect, DNS) without Nick's yes; never submit for review.
