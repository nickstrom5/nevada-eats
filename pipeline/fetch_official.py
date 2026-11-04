"""Official Nevada records -> data/raw/official/ (git-ignored). Every host was robots-checked first (check_sources.py).

- Southern Nevada Health District (all of Clark County): the nightly `restaurants.zip` (permits, inspections, code tables) and its
  schema. Robots allow; one request each.
- Business licenses, each read through the publisher's documented ArcGIS REST API, one request at a time, a second apart:
  - Clark County (unincorporated Clark, including the Strip): BusinessLicenseData MapServer layer 1 (maps.clarkcountynv.gov).
  - City of Las Vegas: "CLV Business Licenses" open-data table (services1.arcgis.com, owner Opendata_lasvegas).
  - City of Henderson: OpenDataGovernment MapServer layer 0 (maps.cityofhenderson.com).
  - City of Reno: "All Reno Businesses" layer 1 (services5.arcgis.com); stale since 2025-10-01.
  Owner, contact and e-mail fields are never written to disk: the request names only the fields we use.
"""
import io, json, os, sys, time, zipfile
import requests

OUT = os.path.join(os.path.dirname(__file__), "..", "data", "raw", "official")
UA = {"User-Agent": "NevadaEatsBuild/1.0 (+nick@eatsranked.com)"}
DELAY = 1.0
os.makedirs(OUT, exist_ok=True)
_last = [0.0]


def get(url, **kw):
    wait = _last[0] + DELAY - time.time()
    if wait > 0:
        time.sleep(wait)
    try:
        r = requests.get(url, headers=UA, timeout=300, **kw)
    finally:
        _last[0] = time.time()
    r.raise_for_status()
    return r


def snhd():
    base = "https://www.southernnevadahealthdistrict.org/restaurants/download/"
    r = get(base + "restaurants.zip")
    open(f"{OUT}/restaurants.zip", "wb").write(r.content)
    zipfile.ZipFile(io.BytesIO(r.content)).extractall(f"{OUT}/snhd")
    open(f"{OUT}/restaurants.sql.txt", "wb").write(get(base + "restaurants.sql.txt").content)
    meta = {"fetched": time.strftime("%Y-%m-%d"), "last_modified": r.headers.get("last-modified"), "bytes": len(r.content)}
    json.dump(meta, open(f"{OUT}/snhd_meta.json", "w"), indent=1)
    print("snhd", meta, flush=True)


LAYERS = {
    "clark_licenses": ("https://maps.clarkcountynv.gov/arcgis/rest/services/BusinessLicense/BusinessLicenseData/MapServer/1",
                       "OBJECTID,USER_FullCredentialNumber,USER_LocationName,USER_unitLine,USER_AddressLine1,USER_City,USER_State,"
                       "USER_ZipCode,USER_CredentialDescription,USER_StatusDescription,USER_InitialLicenseIssuedDate,"
                       "USER_OutOfBusinessDateActual,USER_LocationAddress,USER_LandUse", 10000),
    "lv_licenses": ("https://services1.arcgis.com/F1v0ufATbBQScMtY/arcgis/rest/services/Business_Licenses_OpenData/FeatureServer/0",
                    "ObjectId,Business_Name,Type_of_Business,Address,Zip_Code,License__,Status,CLV,NLV,HEN,CC,Within_City_Limits", 1000),
    "henderson_licenses": ("https://maps.cityofhenderson.com/arcgis/rest/services/public/OpenDataGovernment/MapServer/0",
                           "OBJECTID,CASENUMBER,DESCRIPTION,MAIN_ADDRESS_LINE1,MAIN_ADDRESS_LINE2,CASETYPE,CASEWORKCLASS,STATUS,"
                           "APPLICATIONDATE,ISSUEDATE,EXPIREDATE,LOCATION,SCOPE", 1000),
    "reno_licenses": ("https://services5.arcgis.com/RjM4BJrv5ZkqP4XC/arcgis/rest/services/All_Reno_Businesses/FeatureServer/1", None, 1000),
}
# Reno's layer names its fields only in its own metadata: keep everything but people and contacts
DROP = ("OWNER", "CONTACT", "EMAIL", "MAIL", "APPLICANT", "PHONE", "ATTENTION", "AGENT", "FIRST", "LAST", "PERSON", "LICENSEE")


def layer(name):
    url, fields, page = LAYERS[name]
    m = get(url, params={"f": "json"}).json()
    oid = next((f["name"] for f in m.get("fields") or [] if f["type"] == "esriFieldTypeOID"), "OBJECTID")
    if fields is None:
        fields = ",".join(f["name"] for f in m["fields"] if not any(w in f["name"].upper() for w in DROP) and f["type"] != "esriFieldTypeGeometry")
    rows, last = [], -1
    while True:
        r = get(url + "/query", params={"where": f"{oid} > {last}", "outFields": fields, "orderByFields": f"{oid} ASC",
                                        "resultRecordCount": page, "returnGeometry": "true", "outSR": 4326, "f": "json"}).json()
        if "error" in r:
            raise SystemExit(f"{name}: {r['error']}")
        feats = r.get("features") or []
        for f in feats:
            a = f["attributes"]
            g = f.get("geometry") or {}
            if "x" in g:
                a["lon"], a["lat"] = round(g["x"], 6), round(g["y"], 6)
            rows.append(a)
        if not feats:
            break
        last = feats[-1]["attributes"][oid]
        print(f"  {name}: {len(rows)}", flush=True)
    meta = {"url": url, "fetched": time.strftime("%Y-%m-%d"), "rows": len(rows), "fields": fields.split(","),
            "lastEditDate": (m.get("editingInfo") or {}).get("lastEditDate"), "copyright": m.get("copyrightText"),
            "description": (m.get("description") or "")[:2000]}
    json.dump({"meta": meta, "rows": rows}, open(f"{OUT}/{name}.json", "w"))
    print(name, len(rows), "rows", flush=True)


if __name__ == "__main__":
    for w in sys.argv[1:] or ["snhd", *LAYERS]:
        snhd() if w == "snhd" else layer(w)
