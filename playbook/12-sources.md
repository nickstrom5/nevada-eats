# Nevada sources (checked 2026-10-27)

Every host below was robots-checked with `pipeline/check_sources.py` (ClaudeBot, Claude-User, anthropic-ai; RFC 9309 matcher; an empty
202 counts as a bot check) in its own step, before any other request. User agent on every scripted request:
`NevadaEatsBuild/1.0 (+nick@eatsranked.com)`. Raw files are in `data/raw/official/` (git-ignored, never public). ArcGIS Online REST
hosts (`services1.arcgis.com`, `services5.arcgis.com`) answer 403 to `/robots.txt` and are read through their documented query API only
(Colorado, Connecticut, Arizona and South Carolina precedent: `check_sources.API_HOSTS`).

Nevada has **one** bulk source of inspections: the **Southern Nevada Health District** (all of Clark County, about 78% of the state's
restaurants). Everywhere else there is no open inspection data.

## Coverage by jurisdiction (first build, 2026-10-27)

| County | Restaurants (web build) | Who inspects | Official result shown | Official lists used |
|---|---|---|---|---|
| Clark | 8,514 | Southern Nevada Health District | **SNHD grade card** (A/B/C, X = closed) with demerits and date: 6,072 places | SNHD permits; Clark County (unincorporated, the Strip), Las Vegas and Henderson business licenses |
| Washoe (Reno, Sparks, Incline Village) | 1,433 | Northern Nevada Public Health (placards: green Pass, yellow Conditional Pass, red Failed/Closed) | none: no bulk data (Washoe Eats app; OneNV Accela search) | City of Reno business licenses (layer frozen 2025-10-01) |
| Carson City | 173 | Carson City Health and Human Services | none (site answers scripts with an Akamai 403: to check by hand) | none found |
| Douglas, Lyon, Storey, Elko, Nye, Churchill, Humboldt, White Pine, Lander, Mineral, Lincoln, Pershing, Eureka, Esmeralda | 828 | State DPBH (rural counties); who inspects Douglas, Lyon and Storey still to verify by hand | none ("no official record") | none found |

Inspections are shown within SNHD's jurisdiction only and never blended into a statewide number.

## Southern Nevada Health District (used)

- `https://www.southernnevadahealthdistrict.org/restaurants/download/restaurants.zip` (8,995,553 bytes, `Last-Modified: Tue, 27 Oct 2026
  05:00:05 GMT`, rebuilt nightly; robots allow) and its schema `restaurants.sql.txt` ("The health district does not guarantee the accuracy
  of the information reported on this database, and disclaims liability for any errors."). No license text; public records.
- `restaurant_establishments.csv`: 36,642 permits; **19,835 active** (`record_status` 01 active-billable or 04 active-exempt; the code table
  `query_estab_billable_status.csv`) at 9,826 facilities. Fields: permit, facility, PE (program element), restaurant name, location name,
  address, point, city, zip, current/previous grade and date. Traps handled in `pipeline/official.py`: semicolon-delimited; 54 rows with
  stray semicolons inside a name (re-split around the point and zip); `latitude`/`longitude` swapped; new-style permit numbers
  (`FOOD-CO-26-…`, facilities `FAC-26-…`) beside the old `PR…`/`FA…`.
- **Permits are not places.** Permits are grouped into **outlets** (12,448): a facility whose location name runs through its permits is
  one business ("EMERILS NEW ORLEANS FISH HOUSE @ MGM": dining room, bar, hot line, prep); a resort facility whose permits name their
  outlets is split by the outlet in the permit name after removing the facility's prefix ("RW CROSSROADS - BAR 1FL" → Crossroads at
  Resorts World; 41 outlets there). PE codes → kind: restaurant 1003–1008, snack bar 1009–1011, buffet 1012, barbecue 1013, bar 1016,
  beer bar 1017 are the public "food" permits; main/banquet/special kitchens, bakeries, pantries, garde manger and support rooms are
  back-of-house; carts, seasonal, itinerant (AILR/AIHR) and mobile permits are trucks; meat, produce, bakery-sales and sampling permits are
  markets; schools, childcare, institutions, jails and caterers are "other" (PEs missing from the zip's xref were read from their permits'
  names).
- `restaurant_inspections.csv`: **128,581 inspections, 2020-09-01 to 2026-10-26** (`restaurant_inspections_stanford.csv` covers 2005 to
  2017; not used). Grades A 117,068, B 9,201, C 1,288, X 712. Types: routine 916, re-inspection 914, pre-opening 935, survey 919.
  **Records through 2026-10-20** (a week before the file). The grade shown is the card SNHD issued (some B cards carry single-digit
  demerits); never derived. A place shows its outlet's front permit's latest graded inspection (dining room before buffet, barbecue,
  snack bar, then bar), the outlet's other public permits with their own cards, and the cited items (`restaurant_violations.csv`; 94% of
  cited ids resolve; the 2020s items are written as the standard checked, e.g. "Adequate handwashing sinks stocked and accessible").
- A closure (X) with no later inspection for 30+ days is taken as closed and the place removed (2 in the first build: Vive Cancun
  Hamburgers, X 2025-04-22; The Chicken Shack, Boulder City, X 2026-06-26).
- SNHD runs its own app ("Restaurant Grades Southern NV"): the app must never look official.

## Business licenses (used: confirmation and "serves alcohol")

| Source | Rows | Terms | Cadence | Use |
|---|---|---|---|---|
| **Clark County** BusinessLicenseData MapServer layer 1 (`maps.clarkcountynv.gov/arcgis/rest/services/BusinessLicense/BusinessLicenseData/MapServer/1`, item 458d4a7753ae497294d6dfedd92440fc) | 90,139 (unincorporated Clark incl. the Strip) | no license text on the item | current (statuses through Sept 2026) | food/liquor licenses with status; "Liquor - Tavern With Restaurant", "Liquor - Restaurants - Supper Clubs" etc.; adult cabaret licenses feed `data/research/adult_venues.json` |
| **City of Las Vegas** "CLV Business Licenses" table (`services1.arcgis.com/F1v0ufATbBQScMtY/…/Business_Licenses_OpenData/FeatureServer/0`, item f6b923ee5eb9450baf6adebaf0f307ed, owner Opendata_lasvegas) | 214,263 (2013 to now; 60,451 Active) | "The City of Las Vegas makes no warranty … assumes no liability" | updated daily | Restaurant, Food Services or Cafe, Full Alcohol / Beer and Wine On-Premise; no points, matched by street address |
| **City of Henderson** OpenDataGovernment MapServer layer 0 (`maps.cityofhenderson.com/…/OpenDataGovernment/MapServer/0`) | 17,454 active | none stated | current | Restaurant/Food Service and Liquor case types |
| **City of Reno** "All Reno Businesses" layer 1 (`services5.arcgis.com/RjM4BJrv5ZkqP4XC/…/All_Reno_Businesses/FeatureServer/1`, item 620fcef256e14055bfa0efe57b434a06) | 21,306 | none stated; cityofreno.com's robots.txt disallows all agents (never called) | **frozen 2025-10-01** | Restaurant, Food Service, Dining Room Alcohol / Wine and Beer, On-Premises Alcohol; shown as "list as of 2025-10-01" |

Owner, contact and e-mail fields were never downloaded (the fetch names only the fields used; Reno's licensee name and address fields were
removed from the stored file). Henderson's and Reno's business names can be a person's name and are never shown. A place shows "Serves
alcohol" only from its own active on-premises liquor license (1,577 places in the first build); elsewhere it's "—" (a resort outlet is
usually under the resort's own license). North Las Vegas (bot check), Sparks and Carson City publish no license data found. The state
Department of Taxation licenses only suppliers, wholesalers and makers (PDF lists at tax.nv.gov/tax-types/liquor-tax/; not used yet).

## Not used / to do

- **Northern Nevada Public Health** (Washoe): nnph.org answered our checker with a TLS error (treated as unreachable). Results are in the
  Washoe Eats app and OneNV (`aca-prod.accela.com/one`, robots allow; search only, PDFs). **Needs Nick's call** before any crawl; a
  records request to healthehs@nnph.org may be better.
- **Carson City Health** (gethealthycarsoncity.org): Akamai 403 to scripts (bot check): check by hand only.
- **State DPBH** (rural counties): no public results found.
- Property values: Clark has no open download found; Washoe's assessor files say "for assessment purposes only". No property board.
- North Las Vegas (`cityofnorthlasvegas.com`): bot check.

## Statewide base

| Source | What | Terms | Cadence | Rows |
|---|---|---|---|---|
| Overture Maps places `2026-10-21.0` (newest release) | Map listings, state and county outlines (land division areas), address points | CDLA-Permissive-2.0 / Apache-2.0 + Foursquare NOTICE | Monthly | 16,898 Nevada eating/drinking listings (`region = 'NV'`; 936 marked closed); 170,408 places in the state; only 28,396 address points (Overture's Nevada address coverage is thin); 17 counties incl. Carson City |
| UCSD Google Local 2021 (`meta-Nevada.json.gz`, mcauleylab.ucsd.edu, 10.7 MB) | 2021 ratings, reviews, price, 2021 closures: **web leaderboard only, never the app** | research dataset | frozen Sep 2021 | 10,101 food listings (1,213 closed by 2021); 7,636 matched to Overture listings |
| Census CBP 2023 (from the prompt) | NAICS 722: 7,339 (Clark 5,457, Washoe 1,160, Carson City 154), without casino-hotel outlets (NAICS 72112) | public | yearly | benchmark only |

Spillover over the California, Arizona, Utah, Idaho and Oregon lines is clipped three ways: Overture's own `region = 'NV'`, a Nevada ZIP
(889xx–898xx), and the state outline with a 100 m buffer.

## Calibration (2026-10-27, `data/nv/calibration*.json`)

SNHD permits every place in Clark County that serves food, so its outlet list is a **real rate**, like Wake County's in North Carolina.
Each Clark County map listing was checked against the 12,424 active SNHD outlets (same business name nearby, or the same street address
with a distinctive name word in common; resort host words such as MGM, Bellagio or Resorts World never count as the shared word).

| Kind of listing | On SNHD's list |
|---|---|
| Meta + open in Google 2021 | 85.1% of 3,637 |
| Meta only | 47.5% of 3,497 |
| Brand feed + Google 2021 / brand feed only | 90.1% of 152 / 59.9% of 287 |
| Microsoft only | 37.8% of 621 |
| Foursquare/BrightQuery/Microsoft + Google 2021 | 27.1% of 1,249 |
| Foursquare only | 14.9% of 1,138 |
| BrightQuery only | 12.2% of 1,166 |
| Google 2021 says closed / Overture says closed | 4.4% / 4.2% |
| App grouping: Meta ≥ 0.95 | 83.0% of 4,886 |
| App grouping: Meta 0.90–0.95 | 45.3% of 878 |
| App grouping: Meta < 0.90 | 21.7% of 1,429 |
| App grouping: BrightQuery ≥ 0.95 | 19.4% of 979 |
| App grouping: chain store lists | 70.3% of 438 |

Same order as Colorado, Texas, North Carolina and the rest, so the same keep rules: web = Meta and chain store lists (plus official and
hand-checked), minus what Google showed closed in 2021; app = Meta ≥ 0.95, Meta 0.90–0.95 with a website, chain store lists, official,
hand-checked. The other way, the open map listings hold **61.1%** of SNHD's 7,848 single-business restaurant, snack bar and bar outlets
(a resort's own service bars and staff dining rooms aren't counted); permitted restaurants, buffets and barbecue outlets among the rest
are added from the list (1,970 added; about 1,000 of those hidden as stores, hotels, schools, gaming parlors and other non-restaurants).

Result (first web build): **10,948 restaurants in 90 towns** (12,304 places with non-restaurants); 6,072 with an SNHD grade (A 6,026,
B 35, C 9; X closures re-inspected within the month only). CBP's 7,339 leaves out the 144 casino hotels' outlets, which SNHD counts.

## Honors (data/research)

- **MICHELIN Guide American Southwest 2026** (debuted 2026-08-26; AZ, NV, NM, UT). guide.michelin.com read 2026-10-27 with Claude's web
  fetcher (`check_sources.READ_BY_FETCHER`): Nevada "1-24 of 24 restaurants", all in Las Vegas. **2 Stars** Restaurant de Joël Robuchon
  (the 2026 MICHELIN Guide Southwest Service Award went to Sean Christopher there, per its page); **1 Star** Restaurant Guy
  Savoy, é by José Andrés, L'Atelier de Joël Robuchon; **Bib Gourmand** Esther's Kitchen, China Poblano, YEN Viet Kitchen; **17
  Recommended**. Each restaurant page read for its address (`michelin.json`). The **Bib Gourmand filter** applies (BIB-GOURMAND-FILTER.md).
- **James Beard** (`jbf.json`): Best Chef: Southwest **Saipin Chutima, Lotus of Siam** (2011, shared; archive.jamesbeard.org; Lotus of
  Siam's own site shows the award; the original Sahara Avenue restaurant reopened with a grand opening on May 10, 2026, and the Flamingo
  Road one is open) and **Sarah Thompson, Casa Playa** at Encore (2026; jamesbeard.org's 2026 winners page; wynnlasvegas.com);
  **America's Classics**: the **Peppermill** (2024; "since 1972", its own site) and **Bob Taylor's Ranch House** (2026; "since 1955",
  its own site). Leads: Paul Bartolotta (2009, Bartolotta Ristorante di Mare) is shown only once he's confirmed still there; Claude Le
  Tohic (2010, Robuchon) has left, so that award isn't on the restaurant (`data/research/app/LEADS.md`).
- fox5vegas.com robots-disallows ClaudeBot and anthropic-ai: not cited.

## Hand-checked guides (pipeline/build_research.py, 2026-10-27)

21 places, every one matched to a listing, each with a dated 2025–26 source (robots-checked hosts only):
- **Basque dining** (4): Star Hotel (Elko, 246 Silver St), The Martin Hotel (Winnemucca), JT Basque Bar and Dining Room
  (Gardnerville), Villa Basque Café (Carson City): their own sites (©2026, a Nevada Day 2025 post) and WE3 Elko (Aug 14, 2025).
- **Buffets** (4): Bacchanal (Caesars), Wicked Spoon (Cosmopolitan), The Buffet at Wynn, A.Y.C.E (Palms): Vital Vegas buffet roundup
  (Oct 19, 2026) plus the resorts' own pages.
- **Chinatown** (5): ShangHai Taste, Partage, Double Zero Pie & Pub, Sparrow + Wolf, Kame Omakase: Vital Vegas Chinatown (Jul 6, 2026).
- **Hawaiian plate lunch** (6): Pacific Island Taste, Unko Frank's, Aloha Specialties (California Hotel), Grinds 2 Da Max (two),
  Poke Market: Vital Vegas (Oct 24, 2024) only with a 2025–26 SNHD inspection to show each is still serving.
- **Old Vegas steakhouses** (2): Golden Steer (since 1958) and Bob Taylor's Ranch House (since 1955): their own sites. Below the
  site's 4-place page threshold, so no web page yet; the app lists them.
- **Oldest places** (5, founded 1960 or earlier at the same address): Golden Steer, Bob Taylor's, JT Basque, Star Hotel, Martin Hotel.
- Casino classics and mining-town saloons: still empty; leads in `data/research/app/LEADS.md` (Louis' Basque Corner, Toki Ona,
  Bakarra, the Bellagio buffet, Hugo's Cellar, Bartolotta, saloons in Virginia City, Austin, Eureka, Tonopah).
- Not used: travelnevada.com (403 to Claude's fetcher), neon.reviewjournal.com (403), lasvegasweekly.com (402), fox5vegas.com (robots).
- Website links: Nevada papers, TV and tourism sites are in `check_websites.NEWS` and the app export drops them even before a check
  (a lasvegassun.com place page shipped as Cocolini's website in the first build; `testBundledDataGuards` caught it).

## Adult venues

`data/research/adult_venues.json` is built from the official lists (`pipeline/build_adult.py`): every active Clark County "Adult
Entertainment Cabaret" (with or without drinking), adult book, novelty, arcade or picture-theatre license and every active Las Vegas "Erotic
Dance Establishment" or "Adult Book Store" license; each entry's source is its license. A place at that address goes when its name agrees
with the license's or it's the only place listed there; Overture's adult category catches the rest by name and distance. First build: 13
removed, among them a bar-and-grill and a nightclub that hold adult-cabaret licenses under plain names. Reno's adult clubs are covered
only by name and Overture's category so far (Reno lists dancers' licenses, not the clubs').
