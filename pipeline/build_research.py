"""Writes data/research/app/*.json (hand-checked Nevada guides) from the compact lists below. Ported from nc-eats (tn-eats lineage).

Each entry cites a page that names the place for the food or tradition (robots-checked host: check_sources.py) and 2025-26 evidence that
it is operating, one of: a page dated 2025-26 (Visit Las Vegas's dated posts, Carson Now, a dated travel guide); the place's own site
showing a 2025 or 2026 date; or, for a Clark County place named by an older page, its own Southern Nevada Health District inspection in
2025-26 (the district's own record, checked here against site/nevada.json). The address comes from the map listing we already hold for
that name in that town (site/nevada.json), never from memory; a name that isn't found exactly once in its town (or at the street number
given) is left out and listed in data/research/app/LEADS.md, unless it has an entry in ADDR (a place filed as a hotel, placed on its
own Overture listing by nevada.py).
Not used as sources: travelnevada.com (answers Claude's fetcher 403), neon.reviewjournal.com (403), lasvegasweekly.com (402 paywall),
vegas.eater.com, rgj.com, nevadaappeal.com, nevadamagazine.com, thisisreno.com and the TV stations' sites (robots disallow Claude).
Usage: ../.venv/bin/python build_research.py   (then nevada.py)"""
import json, os, re
from brands import brand_of
from common import norm_name
ROOT = os.path.join(os.path.dirname(__file__), "..")
R = os.path.join(ROOT, "data", "research")
d = json.load(open(os.path.join(ROOT, "site", "nevada.json")))
C, M = d["cols"], d["meta"]
INSP = {r[0]: r[3] for r in d["sparse"]["insp"]}   # row -> latest graded SNHD inspection date
norm = lambda s: re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", " ", (s or "").lower().replace("'", "").replace("’", ""))).strip()

# naming pages (each read 2026-10-27)
VLV_BUFFETS = "https://www.visitlasvegas.com/experience/post/buffets-on-and-off-the-strip/"   # Visit Las Vegas, Oct 19, 2026
VLV_CHINATOWN = "https://www.visitlasvegas.com/experience/post/a-bite-sized-guide-to-chinatown/"   # Visit Las Vegas, Jul 6, 2026
VLV_MADE_MAN = "https://www.visitlasvegas.com/experience/post/dine-like-a-made-man/"   # Visit Las Vegas, Apr 22, 2026 (Golden Steer since 1958)
VLV_NINTH = "https://www.visitlasvegas.com/experience/post/six-delicious-reminders-that-las-vegas-is-hawaiis-ninth-island/"   # Oct 24, 2024
WE3_ELKO = "https://we3travel.com/elko-nevada-basque-cuisine-guide/"   # We3 Travel, Aug 14, 2025 (the Star Hotel, established 1910)
CARSON_NOW = "https://www.carsonnow.org/?p=208755"   # Carson Now, Feb 24, 2026: Villa Basque Cafe "will continue to operate"
SNHD = "https://www.southernnevadahealthdistrict.org/restaurants/"   # the place's own 2025-26 SNHD inspection (checked below)
# the places' own sites (each read 2026-10-27)
MARTIN = "http://themartinhotel.com/"         # "All dinners are served in the Basque tradition"; since 1898; (c) 2026, closed Feb 8, 2026 notice
JTBASQUE = "http://jtbasquenv.com/"           # "Basque cuisine", family-style; founded 1955; a Nevada Day 2025 post
VILLA = "http://www.villabasquecafe.com/"     # "authentically Basque"; 730 Basque Way
BOBTAYLOR = "https://www.bobtaylorsranchhouse.com/"   # "The Place for Steaks Since 1955"; its 2026 James Beard award
GOLDENSTEER = "https://www.goldensteerlasvegas.com/"

# kind -> (name as the source writes it, town, street number to pick the location (or None), note, founded, founded_note, [sources],
#          needs the place's own 2025-26 SNHD inspection)
GUIDES = {
 "basque": [
  ("Star Hotel", "Elko", None, "A Basque boardinghouse since 1910, still serving family-style dinners (We3 Travel, Aug 2025).", 1910,
   "We3 Travel (Aug 14, 2025): \u201cThe Star Hotel, established in 1910.\u201d", [WE3_ELKO], False),
  ("The Martin Hotel", "Winnemucca", "94", "Dinners served in the Basque tradition (its own site).", 1898,
   "Its own site: \u201cThe Martin Hotel since 1898.\u201d", [MARTIN], False),
  ("JT Basque Bar and Dining Room", "Gardnerville", "1426", "Family-style Basque dinners and Picon punch (its own site).", 1955,
   "Its own site: founded in 1955 by the Jaunsaras and Trounday families.", [JTBASQUE], False),
  ("Villa Basque Café", "Carson City", "730", "A Basque deli and café known for its family chorizo; still open after its founder's death in 2026 (Carson Now).", None, None,
   [CARSON_NOW, VILLA], False),
 ],
 "buffet": [
  ("Bacchanal Buffet", "Las Vegas", "3570", "Caesars Palace's buffet (Visit Las Vegas, Oct 2026).", None, None, [VLV_BUFFETS], False),
  ("Wicked Spoon", "Las Vegas", "3708", "The Cosmopolitan's buffet of small plates (Visit Las Vegas, Oct 2026).", None, None, [VLV_BUFFETS], False),
  ("The Buffet at Wynn Las Vegas", "Las Vegas", "3131", "Wynn Las Vegas's buffet (Visit Las Vegas, Oct 2026).", None, None, [VLV_BUFFETS], False),
  ("A.Y.C.E", "Las Vegas", "4321", "The Palms' all-you-can-eat buffet (Visit Las Vegas, Oct 2026).", None, None, [VLV_BUFFETS], False),
 ],
 "chinatown": [
  ("ShangHai Taste", "Las Vegas", "4266", "Xiao long bao on Spring Mountain Road (Visit Las Vegas's Chinatown guide, Jul 2026).", None, None, [VLV_CHINATOWN], False),
  ("Partage", "Las Vegas", "3839", "French tasting menus in Chinatown; MICHELIN Recommended.", None, None, [VLV_CHINATOWN], False),
  ("Double Zero Pie & Pub", "Las Vegas", "3853", "Neapolitan pizza in Chinatown (Visit Las Vegas, Jul 2026).", None, None, [VLV_CHINATOWN], False),
  ("Sparrow + Wolf", "Las Vegas", "4480", "Wood-fired cooking from around the world in Chinatown; MICHELIN Recommended.", None, None, [VLV_CHINATOWN], False),
  ("Kame Omakase", "Las Vegas", "3616", "Omakase sushi in Chinatown; MICHELIN Recommended.", None, None, [VLV_CHINATOWN], False),
 ],
 "plate lunch": [
  ("Pacific Island Taste", "Las Vegas", "545", "Hawaiian plate lunch off East Sahara (Visit Las Vegas's Ninth Island list).", None, None, [VLV_NINTH, SNHD], True),
  ("Unko Frank's Hawaiian BBQ", "Las Vegas", "7780", "Hawaiian barbecue plates in the southwest valley (Visit Las Vegas's Ninth Island list).", None, None, [VLV_NINTH, SNHD], True),
  ("Aloha Specialties", "Las Vegas", "12", "Plate lunch inside the California Hotel downtown, the Ninth Island's hotel (Visit Las Vegas).", None, None, [VLV_NINTH, SNHD], True),
  ("Grinds 2 Da Max", "Las Vegas", "6475", "Hawaiian plates (Visit Las Vegas's Ninth Island list).", None, None, [VLV_NINTH, SNHD], True),
  ("Grinds 2 Da Max", "Las Vegas", "6825", "Hawaiian plates (Visit Las Vegas's Ninth Island list).", None, None, [VLV_NINTH, SNHD], True),
  ("Poke Market at Uncommons Las Vegas", "Las Vegas", "6815", "Chef Michael's poke at Uncommons (Visit Las Vegas's Ninth Island list).", None, None, [VLV_NINTH, SNHD], True),
 ],
 "old vegas steakhouse": [
  ("Golden Steer Steakhouse", "Las Vegas", "308", "A Rat Pack-era steakhouse on West Sahara since 1958 (Visit Las Vegas, Apr 2026).", 1958,
   "Visit Las Vegas (Apr 22, 2026): opened in 1958.", [VLV_MADE_MAN], False),
  ("Bob Taylor's Ranch House", "Las Vegas", "6250", "Mesquite-grilled steaks in the northwest valley; a James Beard America's Classic (2026).", 1955,
   "Its own site: \u201cThe Place for Steaks Since 1955.\u201d", [BOBTAYLOR], False),
 ],
}
KINDS = {"basque": ["Basque"], "buffet": ["Buffet"], "chinatown": ["Chinatown"], "plate lunch": ["Plate lunch"],
         "old vegas steakhouse": ["Old Vegas steakhouse"], "casino classics": ["Casino classics"], "mining town saloon": ["Mining town saloon"]}
ADDR = {"Star Hotel": "246 Silver St"}   # filed as a hotel in the map data; nevada.py places it on its own Overture listing

def key(s):
    """The name key without a leading "the": "Loveless Cafe" is our "The Loveless Cafe"."""
    return re.sub(r"^the ", "", norm(s))


def find(name, town, num):
    k = key(name)
    hits = [i for i, n in enumerate(C["name"]) if C["city"][i] is not None and M["cities"][C["city"][i]] == town
            and (key(n) == k or key(n).startswith(k + " ") or k.startswith(key(n) + " ") or key(n).replace(" ", "") == k.replace(" ", "")
                 or (key(n).split()[:2] == k.split()[:2] and len(k.split()) >= 2))]
    if num:
        hits = [i for i in hits if (C["addr"][i] or "").split(" ")[0] == num]
    return hits



leads, n_out = [], {}
for kind, rows in GUIDES.items():
    out = []
    for name, town, num, note, founded, fnote, srcs, needs_snhd in rows:
        hits = find(name, town, num)
        if not hits and name in ADDR:
            out.append({"name": name, "address": ADDR[name], "city": town, "zip": None, "kinds": KINDS[kind], "dishes": [], "note": note,
                        "founded": founded, "founded_note": fnote, "website": None, "open": True, "evidence_date": "2026-10",
                        "sources": srcs, "match_names": []})
            continue
        if len(hits) != 1:
            leads.append(f"- {kind}: {name} ({town}{', ' + num if num else ''}) — {len(hits)} matches in our data; not added"); continue
        i = hits[0]
        if needs_snhd and not (INSP.get(i) or "") >= "2025-01-01":
            leads.append(f"- {kind}: {name} ({town}) — no 2025-26 SNHD inspection matched; not added"); continue
        out.append({"name": C["name"][i], "address": C["addr"][i], "city": town, "zip": str(C["zip"][i]) if C["zip"][i] else None,
                    "kinds": KINDS[kind], "dishes": [], "note": note, "founded": founded, "founded_note": fnote, "website": None, "open": True,
                    "evidence_date": INSP.get(i) if needs_snhd else "2026-10", "sources": srcs,
                    "match_names": [name.upper()] if norm(name) != norm(C["name"][i]) else []})
        if C["name"][i] != name and not brand_of(norm_name(name)):
            out[-1]["display"] = name   # the source's (and usually the place's own) spelling
    fn = re.sub(r"[^a-z]+", "_", kind).strip("_")
    json.dump(out, open(f"{R}/app/{fn}.json", "w"), indent=1, ensure_ascii=False)
    n_out[kind] = len(out)

open(f"{R}/app/LEADS.md", "w").write("# Nevada research leads (not yet verified)\n\nWritten by pipeline/build_research.py.\n\n" + "\n".join(leads) + """

## Waiting for 2025-26 evidence we may use (named by a source, but nothing current found yet)
- Basque: Louis' Basque Corner (Reno, since 1967; its own site shows (c) 2015; USA TODAY 2024; Washoe publishes no inspections), Toki Ona
  and Ogi Deli Bar and Pintxos (Elko; own sites undated / (c) 2024), Bakarra Basque Bistro (Winnemucca; formerly Ormachea's).
- Buffets: The Buffet at Bellagio (Visit Las Vegas, Oct 2026) isn't in our map data as a buffet; Reno's casino buffets need a source.
- Chinatown: Le Club by Partage, Aburiya Raku, Sookdal (not in our map data), Daeho Kalbijjim (our listing is on Decatur Blvd, not in
  Chinatown).
- Old Vegas steakhouses: Hugo's Cellar (Four Queens, since 1973 per Visit Las Vegas; no SNHD outlet matched), Top of Binion's, The Steak
  House at Circus Circus, Michael's Gourmet Room: need a dated source.
- Casino classics: the Golden Gate's shrimp cocktail (since 1959), graveyard steak-and-eggs specials, prime rib: the Review-Journal's
  pieces answer Claude's fetcher 403.
- Mining-town saloons: Virginia City's Bucket of Blood and Delta Saloon (renovated under new owners, 2024), Tonopah's Mizpah: need a
  dated source; Storey and Nye publish no inspections.
- Bartolotta Ristorante di Mare (Wynn): Paul Bartolotta, Best Chef: Southwest 2009: confirm he still leads it.
""")
print(n_out, "| leads:", len(leads))
