"""data/research/adult_venues.json from the official license lists: every active Clark County "Adult Entertainment Cabaret" (with or
without drinking), adult book, novelty, arcade or motion-picture license, and every active City of Las Vegas "Erotic Dance
Establishment", "Topless Club", "Adult Nightclub Establishment" or "Adult Book Store" license ("Collections" counts as active: a club
behind on its fees is still open; Treasures and Peppermint Hippo hold Topless Club licenses, 2026-10-28 QA NV-1). Each entry's source is its license (Colorado's lesson: clubs hold plain tavern licenses
under plain trade names, so names alone miss them). Adult day care licenses are not adult venues. Keeps hand-added entries and the
"not_adult" list (Overture listings filed as adult venues by mistake) that are already in the file.
"""
import json, os, re
ROOT = os.path.join(os.path.dirname(__file__), "..")
OFF = f"{ROOT}/data/raw/official"
PATH = f"{ROOT}/data/research/adult_venues.json"
ADULT = re.compile(r"(?i)^adult (?:entertainment cabaret|book|novelty|picture arcade|mini motion|\s*motion picture)|^adult books|erotic dance")
old = json.load(open(PATH)) if os.path.exists(PATH) else {"venues": [], "not_adult": []}
keep = [v for v in old.get("venues", []) if not v.get("from_license")]
out, seen = [], set()
cl = json.load(open(f"{OFF}/clark_licenses.json"))
for r in cl["rows"]:
    d = r.get("USER_CredentialDescription") or ""
    if ADULT.search(d) and r.get("USER_StatusDescription") in ("Licensed", "Limited License", "Temporary License"):
        a = (r.get("USER_AddressLine1") or "").strip()
        if a.upper() in seen:
            continue
        seen.add(a.upper())
        out.append({"name": (r.get("USER_LocationName") or "").strip(), "address": a, "towns": ["Las Vegas", "Henderson", "North Las Vegas"],
                    "kind": d, "from_license": True, "sources": [cl["meta"]["url"] + "#" + str(r.get("USER_FullCredentialNumber"))]})
lv = json.load(open(f"{OFF}/lv_licenses.json"))
for r in lv["rows"]:
    d = r.get("Type_of_Business") or ""
    if re.search(r"(?i)erotic dance|topless club|adult nightclub|adult book", d) and (r.get("Status") or "") in ("Active", "Temp Active", "Issued", "Collections"):
        a = (r.get("Address") or "").strip()
        if a.upper() in seen:
            continue
        seen.add(a.upper())
        out.append({"name": (r.get("Business_Name") or "").strip(), "address": a, "towns": ["Las Vegas", "North Las Vegas"], "kind": d,
                    "from_license": True, "sources": [lv["meta"]["url"] + "#" + str(r.get("License__"))]})
json.dump({"venues": keep + out, "not_adult": old.get("not_adult", [])}, open(PATH, "w"), indent=1)
print("adult venues from licenses:", len(out), "| hand-added kept:", len(keep))
