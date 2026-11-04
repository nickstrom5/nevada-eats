#!/usr/bin/env python3
"""Writes the App Store listing and the App Review reply from the build's own counts (playbook/site-numbers.json, which
scripts/make-site.py rewrites on every run), so the copy never drifts from the data. Ported from tn-eats (modeled on wa-eats/playbook/06
and 13).

Usage (from nv-eats/): .venv/bin/python scripts/make-listing.py   (after make-site.py)
Writes playbook/06-app-store-listing.md, playbook/13-app-review-reply.md and playbook/app-store/listing.json (what
../scripts/asc_listing.py uploads once Nick creates the App Store Connect record and its FOLDERS line is added).
Checks before writing anything: Apple's length limits, no keyword repeating a name/subtitle word, no "best"/"top"/"#1", no price
claim outside the description's plain "free guide", the reply under 4,000 characters.
"""
import json, os, re, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
N = json.load(open(os.path.join(ROOT, "playbook", "site-numbers.json")))
R, T, LIC, HON, INS = N["restaurants"], N["towns"], N["on_an_official_list"], N["honors"], N["snhd_graded"]
MI, JBF = N["michelin"], N["james_beard"]
G = {k[6:]: v for k, v in N.items() if k.startswith("guide_") and isinstance(v, int)}
OLD = N["oldest"]
FLOOR = R // 1000 * 1000   # "9,000+": promo text and What's New outlive small data changes
SITE = "https://nevada.eatsranked.com/"   # until the CNAME resolves: https://nickstrom5.github.io/nevada-eats/

NAME = "Nevada Eats: Restaurants"     # Nick, 2026-10-27 (playbook/05-naming.md); Home Screen "Nevada Eats"
SUB = "Buffets, Basque & Grade Cards"
# no word from the name or subtitle; towns are the biggest search win (rotate after a month of App Store Connect search-term data)
KW = "las vegas,reno,henderson,sparks,carson city,elko,strip,chinatown,plate lunch,steakhouse,inspection"
PROMO = (f"{G['buffets']} casino buffets, {G['basque']} Basque tables and Chinatown's Spring Mountain Road, checked by hand, plus the "
         f"health district's grade cards and {FLOOR:,}+ places to eat.")
WHATS_NEW = (f"First release: buffets, Basque dining, Chinatown, Hawaiian plate lunch, Clark County's grade cards "
             f"and {FLOOR:,}+ Nevada restaurants.")

# the app's guides, each listed only once it has a place in it (Home leaves an empty guide out too)
GUIDE_LINES = [(k, line) for k, line in (
    ("basque", f"• Basque Dining: {G['basque']} family-style Basque tables from Carson Valley to Elko, the sheepherders' boarding-house meal."),
    ("buffets", f"• Buffets: {G['buffets']} casino buffets, each checked against a 2026 source."),
    ("chinatown", f"• Chinatown: {G['chinatown']} spots along Spring Mountain Road, from hand-pulled noodles to omakase."),
    ("plate", f"• Hawaiian Plate Lunch: {G['plate']} counters for loco moco, kalua pig and musubi in the Ninth Island."),
    ("steak", f"• Old Vegas Steakhouses: {G['steak']} steakhouses with decades behind them."),
    ("classics", f"• Casino Classics: {G['classics']} places for prime rib, steak and eggs and shrimp cocktail."),
    ("saloons", f"• Mining-Town Saloons: {G['saloons']} saloons in the old mining towns."),
) if G.get(k)]
GUIDE_NAMES = {"basque": "Basque Dining", "buffets": "Buffets", "chinatown": "Chinatown", "plate": "Hawaiian Plate Lunch",
               "steak": "Old Vegas Steakhouses", "classics": "Casino Classics", "saloons": "Mining-Town Saloons"}
GUIDE_COUNTS = {"basque": "Basque tables", "buffets": "casino buffets", "chinatown": "Chinatown spots", "plate": "plate-lunch counters",
                "steak": "old Vegas steakhouses", "classics": "casino classics", "saloons": "mining-town saloons"}


def join_words(xs):
    return xs[0] if len(xs) == 1 else ", ".join(xs[:-1]) + " and " + xs[-1]


n1 = MI.get("1 MICHELIN Star", 0)
n2 = MI.get("2 MICHELIN Stars", 0)
STARS = join_words(([f"{n2} two-star restaurant" + ("s" if n2 != 1 else "")] if n2 else [])
                   + ([f"{n1} one-star restaurant" + ("s" if n1 != 1 else "")] if n1 else []))
counted = join_words([f"{G[k]} {GUIDE_COUNTS[k]}" for k, _ in GUIDE_LINES])
home_path = ", ".join([GUIDE_NAMES[k] for k, _ in GUIDE_LINES][1:] + ["MICHELIN & James Beard"] + (["Oldest Places"] if OLD else [])
                      + ["Clark County Grades", "Near Me"])

DESC = f"""Nevada's restaurants, from a Basque boarding-house table in Elko to a buffet on the Strip.

Nevada Eats is a free guide to eating in Nevada: {counted} we checked by hand, {HON} MICHELIN and James Beard honorees, the Southern Nevada Health District's grade cards for {INS:,} Clark County places, and {R:,} restaurants, cafés, bars and bakeries in {T} towns, from Laughlin to Jackpot. No account, no ads.

NEVADA GUIDES
{chr(10).join(line for _, line in GUIDE_LINES)}
{f"• Oldest Places: {OLD} restaurants open at the same address since 1960 or earlier." + chr(10) if OLD else ""}• MICHELIN & James Beard: the MICHELIN Guide's {STARS}, {MI.get('Bib Gourmand', 0)} Bib Gourmands and Recommended places, and James Beard winners and America's Classics ({HON} places).
• Clark County Grades: the latest grade card the health district issued for {INS:,} places (A, B or C, or X when it closed a place), with the demerits, the date and the items cited.

FIND IT FAST
• Sort by distance, or browse the map by guide.
• Search by name, town, street or dish: "buffet henderson", "loco moco".
• Filter by town or cuisine, show Bib Gourmands only, or hide chains.
• Save places, and find hand-checked places from iPhone search (Spotlight).

LIVE DETAILS FROM APPLE MAPS
Tap "Ratings, hours & photos" on any place to open Apple Maps' own place card, with current hours, photos, ratings and directions.

HOW THE LISTS ARE BUILT
Every guide place was checked by hand in October 2026 against a 2025 or 2026 source: the MICHELIN Guide, the James Beard Foundation, the place's own site, a health district inspection, dated local press or a tourism listing. The rest come from Overture Maps open data, checked against the Southern Nevada Health District's permits and the business licenses Clark County, Las Vegas, Henderson and Reno publish. Grades are the cards the health district issued, as published; the app never works a grade out of demerits. Website links are checked too. Nothing is ranked by star ratings.

PRIVATE BY DESIGN
No account, no tracking, no ads. Your location, if you share it, only sorts lists on your device. Saved places stay on your device.

Places open and close, so check before you go. Spot a mistake? Email nick@eatsranked.com.

An independent app, not affiliated with any restaurant, casino, chain or government agency (including the State of Nevada, the Southern Nevada Health District and Northern Nevada Public Health), or with the MICHELIN Guide or the James Beard Foundation. MICHELIN and the MICHELIN Guide are trademarks of Michelin. James Beard Foundation and James Beard Award are trademarks of the James Beard Foundation. Place data from Overture Maps Foundation (CDLA Permissive 2.0), the Southern Nevada Health District and others; sources and licenses are on the About tab."""

REPLY = f"""Thank you. Here is the information requested. A screen recording from an iPhone running the latest iOS is attached. It starts at launch and shows the full flow.

1. Screen recording: attached. There is no account, login, user-generated content or paid content.

2. Purpose and audience: Nevada Eats is a free guide to restaurants in Nevada. Its focus is the state's own food: {counted}, each checked by hand in October 2026 against a 2025 or 2026 source, plus the MICHELIN Guide and James Beard honorees. It also lists {R:,} restaurants, cafés and bars statewide from open map data, checked against the Southern Nevada Health District's permits and city and county business licenses, and shows the district's published grade cards for {INS:,} Clark County places. It is for Nevada residents and visitors deciding where to eat, with no ads, account or tracking.

3. How to use it (no login, no setup, no sample files needed):
- Home → {GUIDE_NAMES[GUIDE_LINES[0][0]]} (or {home_path}) → tap any place.
- On a place, tap "Ratings, hours & photos" to open Apple Maps' own place card through MapKit. Directions, Call and Website are below it; further down, Clark County places show the health district's latest grade card and demerits, with a link to its own search.
- Search from the Home search box by name, town, street or dish ("buffet henderson", "loco moco").
- The Map tab shows each guide as pins. "My location" and the Nearest sort use location only if allowed, on the device.
- The heart saves a place on the device (Saved tab). About lists the sources, licenses and the independence statement.
- On iPad, a sidebar replaces the tabs; a place opens in the right-hand column.
- Outside Nevada (as App Review usually is), the map says so and stays on the state; distance sorting still works from where you are.
- "Nevada Eats" is the short Home Screen name of "Nevada Eats: Restaurants".

4. External services and data:
- Apple MapKit: maps, local search to find a place's Apple Maps listing, and Apple's place card for live hours, photos and ratings.
- Core Location: optional, on-device only, for distance sorting.
- Core Spotlight: on-device indexing so places appear in iPhone search.
- Data updates: at most daily, the app checks the website below for newer restaurant data (nothing about the user is sent). No backend, accounts, analytics, ads, payments or AI services.
- Bundled data: Overture Maps Foundation places (CDLA Permissive 2.0; Foursquare records under Apache 2.0, AllThePlaces under CC0; license texts in the app); the Southern Nevada Health District's restaurant permits and inspections; business licenses published by Clark County and the cities of Las Vegas, Henderson and Reno; MICHELIN Guide and James Beard honors (facts only); our own research of public websites and local press.
- The website with the privacy policy and support page is static and hosted on GitHub Pages: {SITE}

5. Regional differences: none. The content covers Nevada; the app is offered in the United States and works the same everywhere.

6. Regulated or protected material: the app is not in a regulated industry and includes no protected third-party material. The data is open-licensed or public record, with attribution and licenses on the About tab. Ratings, hours and photos are shown only inside Apple's own place card through MapKit; the app stores no ratings or reviews. Grades are the cards the health district issued, as published; the app computes no grades of its own. It has no gambling content. Every website link was checked before release, and adult venues are excluded. The app is independent and not affiliated with any restaurant, casino, agency, the MICHELIN Guide or the James Beard Foundation.

Support: nick@eatsranked.com"""

# ---------------- checks (nothing is written unless all pass)
problems = []
for label, text, limit in (("name", NAME, 30), ("subtitle", SUB, 30), ("keywords", KW, 100), ("promotional text", PROMO, 170),
                           ("What's New", WHATS_NEW, 4000), ("description", DESC, 4000), ("review notes", REPLY, 4000)):
    if len(text) > limit:
        problems.append(f"{label}: {len(text)} characters, limit {limit}")
title_words = set(re.findall(r"[a-z]+", (NAME + " " + SUB).lower()))
for kw in KW.split(","):
    if kw != kw.strip() or not kw:
        problems.append(f"keyword {kw!r}: no spaces around commas, no empty entries")
    if set(kw.split()) & title_words:
        problems.append(f"keyword {kw!r} repeats a word from the name or subtitle")
for text, label in ((KW, "keywords"), (PROMO, "promotional text"), (SUB, "subtitle"), (WHATS_NEW, "What's New")):
    for bad in (r"\bbest\b", r"\btop\b", r"#1", r"\bfree\b", r"\bevery\b"):
        if re.search(bad, text, re.I):
            problems.append(f"{label}: contains {bad!r}")
if re.search(r"\bevery (?:restaurant|place)\b|\ball [\d,]+ ", DESC + REPLY, re.I):
    problems.append("description/reply: an 'every restaurant' or 'all N' claim the data can't back")
if problems:
    sys.exit("not written:\n  " + "\n  ".join(problems))

listing = {"bundleId": "com.nevadaeats.ios", "name": NAME, "subtitle": SUB, "privacyPolicyUrl": SITE + "privacy.html",
           "primaryCategory": "FOOD_AND_DRINK", "secondaryCategory": "TRAVEL", "description": DESC, "keywords": KW,
           "promotionalText": PROMO, "supportUrl": SITE, "marketingUrl": SITE, "reviewNotes": REPLY}
os.makedirs(os.path.join(ROOT, "playbook", "app-store"), exist_ok=True)
json.dump(listing, open(os.path.join(ROOT, "playbook", "app-store", "listing.json"), "w"), indent=1, ensure_ascii=False)

open(os.path.join(ROOT, "playbook", "06-app-store-listing.md"), "w").write(f"""# App Store listing (ASO)

Written by `scripts/make-listing.py` from `site-numbers.json` ({N['generated']}); re-run it after every data refresh, never hand-edit.
The machine copy is `app-store/listing.json` (read by `../scripts/asc_listing.py` once Nick creates the App Store Connect record and
adds `"com.nevadaeats.ios": "nv-eats"` to its FOLDERS). The URLs assume nevada.eatsranked.com is live; until Nick's CNAME
resolves, use https://nickstrom5.github.io/nevada-eats/.

## Name (30 max)
`{NAME}` ({len(NAME)})

## Subtitle (30 max)
`{SUB}` ({len(SUB)})

Together they index: nevada, eats, restaurants, buffets, basque, grade, cards. Home Screen name: Nevada Eats.

## Keywords (100 max)
`{KW}` ({len(KW)})

- No word repeats the name or subtitle; no trademarks (no casino, resort or chain names), no "best", "top" or "#1".
- Towns are the biggest win; North Las Vegas ("north" alone is weak), Summerlin, Lake Tahoe, Mesquite, Laughlin and Winnemucca didn't fit.
  Rotate them in after a month of App Store Connect search-term data. Apple's public search can't be used for this research (itunes.apple.com's robots.txt blocks Claude).

## Promotional text (170 max, editable any time without review)
`{PROMO}` ({len(PROMO)})

## Description ({len(DESC)} of 4,000)
```
{DESC}
```

## What's New (1.0)
`{WHATS_NEW}`

## Screenshots
Framed by `scripts/appstore-screenshots.py`: `app-store/iphone/` (8, 1320x2868, the 6.9" slot) and `app-store/ipad/` (6, 2064x2752, the
13" slot). Upload one file at a time in file order and check the order after a reload. No negative board appears in any image, and
captions name no award body.

## Category and age rating
Primary Food & Drink, secondary Travel. Age rating: alcohol references "Infrequent" (bars, saloons, lounges) → 13+; gambling: None (the app lists places to eat, some inside casinos, with no gaming content); everything
else None/No. Pricing $0.00, available in the United States. Content rights: yes, third-party content, with the rights (open data, public
records, Apple's place card). Untick "Sign-in required".

## App Review
Reply and recording script: `13-app-review-reply.md`. Put the reply in App Review Information → Notes from the start.
""")

open(os.path.join(ROOT, "playbook", "13-app-review-reply.md"), "w").write(f"""# App Review: prepared before submitting (Guideline 2.1 "Information Needed")

Written by `scripts/make-listing.py` ({N['generated']}). Wisconsin's new-developer review asked for a screen recording from a physical
device, starting at launch, plus answers to six questions; Nevada Eats should expect the same. Put the reply below in **App
Review Information → Notes** from the start ({len(REPLY):,} of 4,000 characters), and record the video before submitting. If Apple
raises Guideline 4.3(a), answer with Nevada's own guides and sources (Basque boarding-house dining, casino buffets, Spring Mountain
Road's Chinatown, Hawaiian plate lunch in the Ninth Island, the MICHELIN Guide American Southwest, the Southern Nevada Health
District's A/B/C/X grade cards and permits, Clark County, Las Vegas, Henderson and Reno business licenses); never compare with the
other state apps in the Notes.

## Screen recording (Nick, on his iPhone, latest iOS, 60–120 seconds, no sound)

Install from TestFlight first (the internal tester's email must be the Apple ID under Settings › your name › Media & Purchases on the
phone, or TestFlight says "not available"). Record with Control Center → Screen Recording:

1. Start on the Home Screen and tap **Nevada Eats**. The recording must begin with the launch.
2. Home: scroll the cards a little.
3. Tap **Buffets**, then **Bacchanal Buffet** (Las Vegas).
4. Tap **Ratings, hours & photos**; Apple's place card opens. Close it, then scroll to the Health inspections section (the health
   district's grade card and demerits).
5. Tap the **heart** (Save), then go back to Home.
6. Tap the search box and type `basque elko`. Open one result.
7. Tap the **Map** tab, then **Nevada picks**, then a pin and its name.
8. Tap the **Saved** tab, where the saved place shows. Then tap **About** and scroll to the sources.

## Reply text

```
{REPLY}
```
""")
print(f"wrote listing.json, 06-app-store-listing.md, 13-app-review-reply.md | keywords {len(KW)}/100, promo {len(PROMO)}/170, "
      f"description {len(DESC):,}/4,000, reply {len(REPLY):,}/4,000")
