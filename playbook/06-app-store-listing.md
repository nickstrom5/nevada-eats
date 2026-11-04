# App Store listing (ASO)

Written by `scripts/make-listing.py` from `site-numbers.json` (2026-10-27); re-run it after every data refresh, never hand-edit.
The machine copy is `app-store/listing.json` (read by `../scripts/asc_listing.py` once Nick creates the App Store Connect record and
adds `"com.nevadaeats.ios": "nv-eats"` to its FOLDERS). The URLs assume nevada.eatsranked.com is live; until Nick's CNAME
resolves, use https://nickstrom5.github.io/nevada-eats/.

## Name (30 max)
`Nevada Eats: Restaurants` (24)

## Subtitle (30 max)
`Buffets, Basque & Grade Cards` (29)

Together they index: nevada, eats, restaurants, buffets, basque, grade, cards. Home Screen name: Nevada Eats.

## Keywords (100 max)
`las vegas,reno,henderson,sparks,carson city,elko,strip,chinatown,plate lunch,steakhouse,inspection` (98)

- No word repeats the name or subtitle; no trademarks (no casino, resort or chain names), no "best", "top" or "#1".
- Towns are the biggest win; North Las Vegas ("north" alone is weak), Summerlin, Lake Tahoe, Mesquite, Laughlin and Winnemucca didn't fit.
  Rotate them in after a month of App Store Connect search-term data. Apple's public search can't be used for this research (itunes.apple.com's robots.txt blocks Claude).

## Promotional text (170 max, editable any time without review)
`4 casino buffets, 4 Basque tables and Chinatown's Spring Mountain Road, checked by hand, plus the health district's grade cards and 9,000+ places to eat.` (153)

## Description (3236 of 4,000)
```
Nevada's restaurants, from a Basque boarding-house table in Elko to a buffet on the Strip.

Nevada Eats is a free guide to eating in Nevada: 4 Basque tables, 4 casino buffets, 5 Chinatown spots, 6 plate-lunch counters and 2 old Vegas steakhouses we checked by hand, 28 MICHELIN and James Beard honorees, the Southern Nevada Health District's grade cards for 6,053 Clark County places, and 9,606 restaurants, cafés, bars and bakeries in 82 towns, from Laughlin to Jackpot. No account, no ads.

NEVADA GUIDES
• Basque Dining: 4 family-style Basque tables from Carson Valley to Elko, the sheepherders' boarding-house meal.
• Buffets: 4 casino buffets, each checked against a 2026 source.
• Chinatown: 5 spots along Spring Mountain Road, from hand-pulled noodles to omakase.
• Hawaiian Plate Lunch: 6 counters for loco moco, kalua pig and musubi in the Ninth Island.
• Old Vegas Steakhouses: 2 steakhouses with decades behind them.
• Oldest Places: 5 restaurants open at the same address since 1960 or earlier.
• MICHELIN & James Beard: the MICHELIN Guide's 1 two-star restaurant and 3 one-star restaurants, 3 Bib Gourmands and Recommended places, and James Beard winners and America's Classics (28 places).
• Clark County Grades: the latest grade card the health district issued for 6,053 places (A, B or C, or X when it closed a place), with the demerits, the date and the items cited.

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

An independent app, not affiliated with any restaurant, casino, chain or government agency (including the State of Nevada, the Southern Nevada Health District and Northern Nevada Public Health), or with the MICHELIN Guide or the James Beard Foundation. MICHELIN and the MICHELIN Guide are trademarks of Michelin. James Beard Foundation and James Beard Award are trademarks of the James Beard Foundation. Place data from Overture Maps Foundation (CDLA Permissive 2.0), the Southern Nevada Health District and others; sources and licenses are on the About tab.
```

## What's New (1.0)
`First release: buffets, Basque dining, Chinatown, Hawaiian plate lunch, Clark County's grade cards and 9,000+ Nevada restaurants.`

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
