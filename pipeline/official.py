"""Official records for Nevada -> one table of permitted food businesses (one row per outlet) and business licenses, plus inspections.

- "snhd": Southern Nevada Health District (all of Clark County: Las Vegas, the Strip, Henderson, North Las Vegas, Boulder City, Mesquite,
          Laughlin and the rural towns). Its nightly restaurants.zip has every permit with its program element (PE: restaurant, bar,
          snack bar, buffet, back-of-house kitchens, carts, markets, schools...), the facility it sits in, and every inspection since
          2020-09-01 with the grade card it issued (A, B, C, or X for a closure) and its demerits. Grades are SNHD's, never ours.
          A permit is not a place: one restaurant holds a dining-room permit, a bar permit and back-of-house permits, and one resort
          facility holds the permits of dozens of outlets. load() groups permits into outlets (the business a diner walks into).
- Business licenses (no grades; used to confirm a business and to say it holds an on-premises liquor license):
  "ccl" Clark County (unincorporated Clark, including the Strip), "lvl" City of Las Vegas, "hen" City of Henderson,
  "rno" City of Reno (the city's layer stopped updating on 2025-10-01).
  Owner and contact fields were never downloaded; Henderson's and Reno's business names can still be a person's name and are never shown.

load() returns: jur, lic (our id), name, keys (name keys), addr, city, zip, num, street, lat, lon, kind, active, ltype, biz, county
(+ permits for SNHD outlets: [[permit_number, PE label, kind], ...], front = the permit whose grade card hangs by the door).
kind: food | truck | retail | support | other (SNHD) ; liquor | food | retail | other (licenses).
"""
import os, re, json, datetime, collections
import numpy as np, pandas as pd
from common import norm_name, RAW, name_sim, _stems, GENERIC, canon_city, nice

OFF = os.path.join(RAW, "official")
DIRS = {"N": "N", "S": "S", "E": "E", "W": "W", "NORTH": "N", "SOUTH": "S", "EAST": "E", "WEST": "W"}
TYPES = set("ST STREET AVE AV AVENUE BLVD BOULEVARD RD ROAD DR DRIVE LN LANE CT COURT PL PLACE PKWY PARKWAY TER TRL TRAIL WAY HWY CIR "
            "CIRCLE PLZ SQ MALL BND PASS XING RUN ROW WALK RDG LOOP FWY FREEWAY EXPY EXPRESSWAY PIKE PK PKE BV".split())
UNIT = re.compile(r"\s(?:#\s*\S+|(?:STE|SUITE|UNIT|SPC|SP|SPACE|BLDG|BLD|APT|RM|ROOM|FL|FLR|FLOOR|LOWER LEVEL|LL|BOOTH|STALL|KIOSK)\b\.?\s*\S*).*$")


def road(a):
    """One spelling for numbered roads: 'US HIGHWAY 95' = 'US-95' = 'US 95'; 'NV HWY 28' = 'NV-28' = 'SR 28' = 'STATE ROUTE 28';
    'INTERSTATE 15' = 'I-15'."""
    a = re.sub(r"(\d)\s*&\s*(\d)", r"\1-\2", a.upper())
    a = re.sub(r"\b(US|NV|SR|SH|CR|I|IH)-(\w)", r"\1 \2", a)
    a = re.sub(r"\b(?:INTERSTATE(?: HIGHWAY| HWY)?|IH|I H)\s*(?=\d)", "I ", a)
    a = re.sub(r"\b(?:US|U S)\s+(?:HIGHWAY|HWY)\b", "US", a)
    a = re.sub(r"\b(?:STATE (?:HIGHWAY|HWY|ROAD|RD|ROUTE|RTE)|SR|SH|NEVADA (?:HIGHWAY|HWY|STATE ROUTE)|NV (?:HIGHWAY|HWY)|NV)\b(?=\s*\d)", "SH", a)
    a = re.sub(r"\b(?:COUNTY (?:HIGHWAY|HWY|ROAD|RD)|CO RD|CTY (?:HWY|RD)|CR)\b", "CR", a)
    a = re.sub(r"\bHIGHWAY\b", "HWY", a)
    return re.sub(r"\b(US|SH|CR|HWY|I) (\w+)\s*-\s*\w+", r"\1 \2", a)


ORD = {"FIRST": "1ST", "SECOND": "2ND", "THIRD": "3RD", "FOURTH": "4TH", "FIFTH": "5TH", "SIXTH": "6TH", "SEVENTH": "7TH",
       "EIGHTH": "8TH", "NINTH": "9TH", "TENTH": "10TH", "ELEVENTH": "11TH", "TWELFTH": "12TH"}


def street_key(a):
    """'3799 S LAS VEGAS BLVD' = '3799 Las Vegas Blvd S' -> ('3799', 'LAS VEGAS'); '7965 S RAINBOW #140' -> ('7965', 'RAINBOW')
    (SNHD's addresses often leave out the street type and keep the suite)."""
    if not isinstance(a, str):
        return None, None
    a = UNIT.sub("", " " + road(a)).strip()
    a = re.sub(r"[.,#]", " ", a)
    m = re.match(r"^\s*(\d+)[A-Z]?(?:\s*-\s*\d+[A-Z]?)?\s+(.*)$", a)
    if not m:
        return None, None
    words = [w for w in m.group(2).split() if w]
    if len(words) > 1 and words[0] in DIRS:
        words = words[1:]
    core = []
    for w in words:
        if (w in TYPES or (w.isdigit() and core and core[0] not in ("US", "SH", "CR", "I", "HWY"))) and core:
            break
        core.append(w)
    while len(core) > 1 and core[-1] in DIRS:   # "LAS VEGAS BLVD S" without its type
        core.pop()
    # a suite run into a street with no type: SNHD's "10990 Lavender Hill 8B3", "10945 Oval Park D4", "7400 S Las Vegas K145"
    while len(core) > 1 and re.fullmatch(r"(?=[A-Z]*\d)(?=\d*[A-Z])[A-Z0-9]{2,5}|\d+(?:-\d+)+", core[-1]):
        core.pop()
    # "Saint Rose Pkwy" (SNHD) is "St Rose Pkwy" (the map listings): one street, one key (2026-10-28 QA)
    # and "Ft. Apache Road" is "Fort Apache Rd" (two keys left one Starbucks listed twice)
    core = [{"SAINT": "ST", "FT": "FORT", "MT": "MOUNT"}.get(w, ORD.get(w, w)) for w in core]
    return m.group(1), " ".join(core[:3]) or None


def street_compat(a, b):
    """Same street, or one is a whole-word prefix of the other (a source that cuts names short)."""
    if not isinstance(a, str) or not isinstance(b, str) or not a or not b:
        return False
    return a == b or a.startswith(b + " ") or b.startswith(a + " ")


def street_nums(a):
    """'157-159 W Main St' -> {'157', '159'}; '2505 Monroe St' -> {'2505'}."""
    if not isinstance(a, str):
        return set()
    a = road(a)
    m = re.match(r"^\s*(\d+)[A-Z]?(?:\s*-\s*(\d+)[A-Z]?)?\s", a.upper() + " ")
    if not m:
        return set()
    lo = int(m.group(1)); hi = int(m.group(2)) if m.group(2) else lo
    if hi < lo:   # "1500-02"
        hi = int(str(lo)[: len(str(lo)) - len(m.group(2))] + m.group(2)) if m.group(2) else lo
    return {str(x) for x in range(lo, hi + 1, 2 if (hi - lo) % 2 == 0 else 1)} if 0 <= hi - lo <= 12 else {str(lo)}


def _names(*vals):
    out = []
    for v in vals:
        if not isinstance(v, str):
            continue
        v = re.sub(r"\s*\((?:MOBILE|MOBILE UNIT|COMMISSARY|CATERING|SPECIAL EVENT|SPEC EVENT|TEMP(?:ORARY)? EVENT|CP|INSIDE [^)]*)\)\s*$", "", v, flags=re.I)
        for part in re.split(r"\s*/\s*|\s+\bdba\b\s+|\s+&\s+(?=[A-Z][a-z])", v, flags=re.I):
            k = norm_name(re.sub(r"\b(?:LLC|INC|CORP|CORPORATION|LTD|CO)\b\.?", "", part, flags=re.I))
            if k and k not in out:
                out.append(k)
    return out


def _zip(z):
    z = re.sub(r"\D", "", str(int(z)) if isinstance(z, float) and z == z else str(z or ""))
    return z[:5] if len(z) >= 5 else ""


def _addr(a):
    """'3799 S LAS VEGAS BLVD ' -> '3799 S Las Vegas Blvd' (directions, and SNHD's corner codes like 'NWC ST ROSE & MARYLAND', keep their case)."""
    a = re.sub(r"\s+", " ", a or "").strip()
    keep = ("NE", "NW", "SE", "SW", "NEC", "NWC", "SEC", "SWC", "US", "NV")
    return re.sub(r"\b([A-Z]{2,})\b", lambda m: m.group(1).title() if m.group(1) not in keep else m.group(1), a)


# ---------------------------------------------------------------- Southern Nevada Health District
_META = os.path.join(OFF, "snhd_meta.json")
LIST_DATE = json.load(open(_META)).get("fetched") if os.path.exists(_META) else None
SNHD_SEARCH = "https://www.southernnevadahealthdistrict.org/restaurants/"
SNHD_DATA = "https://www.southernnevadahealthdistrict.org/restaurants/download/restaurants.zip"
# program element -> (kind, label). From the zip's restaurant_pe_category_xref.csv and restaurant_categories.csv; the codes the xref leaves
# out were read from their permits' names (2026-10-27): 1092/1093 and 1124/1125 are annual itinerant (event) permits, 1098-1101
# seasonal ones, 1115-1120 jails, schools and senior programs, 1121 casino support rooms, 1122 mobile vendors.
def _pe(code):
    c = int(code) if str(code).isdigit() else 0
    if 1003 <= c <= 1008: return "food", "Restaurant"
    if 1009 <= c <= 1011: return "food", "Snack bar"
    if c == 1012: return "food", "Buffet"
    if c == 1013: return "food", "Barbecue"
    if c == 1016: return "food", "Bar"
    if c == 1017: return "food", "Beer bar"
    if c in (1000, 1001) or 1018 <= c <= 1036 or 1043 <= c <= 1056 or c == 1121: return "support", "Kitchen"
    if 1038 <= c <= 1040 or 1058 <= c <= 1062 or c == 1084: return "retail", "Meat & seafood"
    if 1063 <= c <= 1065: return "retail", "Confection"
    if 1068 <= c <= 1077: return "retail", "Market"
    if c in (1087, 1117): return "retail", "Market"
    if c in (1078, 1079, 1080, 1102) or 1098 <= c <= 1101: return "truck", "Portable or seasonal"
    if c in (1081, 1082, 1083, 1086, 1122): return "truck", "Food truck"
    if c in (1092, 1093, 1124, 1125, 1094, 1096, 1097): return "truck", "Event or market vendor"
    if c in (1088, 1089): return "other", "Concessions"
    if c == 1090: return "other", "Caterer"
    return "other", "Institution"


FRONT = {"Restaurant": 0, "Buffet": 1, "Barbecue": 2, "Snack bar": 3, "Bar": 4, "Beer bar": 5}
# the part of a permit name that names a station, not the outlet: "EMERILS HOT LINE", "BREZZA - BULK PREP KITCHEN 1FL", "CRUSH BAR #1"
STATION = re.compile(r"(?:\s+-\s+.*$)|(?:\s+(?:\d+FL|FL\s?\d+|B\d|L\d|LVL\s?\d+|LEVEL\s?\d+|1ST FL(?:OOR)?|2ND FL(?:OOR)?)\b.*$)|"
                     r"(?:\s+@\s+.*$)|(?:\s+#\s*\d+\w*$)|"
                     r"(?:\s+(?:RESTAURANT|RESTAURA\w*|BAR(?:\s+\d+|\s+#\s*\d+)?|SERVICE BAR|MAIN BAR|BAR AND STORAGE|BAR & STORAGE|"
                     r"KITCHEN|MAIN KITCHEN|PREP(?:\s+KITCHEN)?|PREP/WAREWASH|PREP AND WAREWASH|BULK PREP|HOT LINE|COOKLINE|COOK LINE|"
                     r"PANTRY|WAREWASH(?:ING)?|DISH ?WASH|DISHROOM|STORAGE|SUPPORT(?:\s+KITCHEN)?|BOH|FOH|SNACK BAR|"
                     r"GARDE MANGER\S*|MEAT ROOM|MEAT PREP(?: ROOM)?|PREP ROOM|FISH ROOM|BUTCHER(?: SHOP)?|SHELLFISH STATION|"
                     r"BEV\S*(?:\s+STATION)?|STATION|SATELLITE|DELI|LOUNGE BAR)\s*$)")


def _outlet(n):
    """A permit's outlet name: 'RW CROSSROADS - BAR 1FL' -> 'RW CROSSROADS'; 'EMERILS HOT LINE' -> 'EMERILS'."""
    n = re.sub(r"\s+", " ", (n or "").upper().replace("�", "'")).strip()
    for _ in range(4):
        m = STATION.sub("", n).strip(" -/&")
        if not m or m == n:
            break
        n = m
    return n


def _host_free(loc):
    """'EMERILS NEW ORLEANS FISH HOUSE @ MGM' -> 'EMERILS NEW ORLEANS FISH HOUSE'; 'MGM GRAND GARDEN ARENA - DEEZNUTS AILR' stays."""
    return re.split(r"\s+@\s+|\s+AT\s+(?=MGM|RW\b|RESORTS|THE\s)", (loc or "").upper())[0].strip()


def _read_snhd(name):
    """SNHD's semicolon files. About 55 establishment rows have semicolons inside a name: those rows are re-split by anchoring on the
    point (the fields after the address are numbers, codes and dates)."""
    lines = open(os.path.join(OFF, "snhd", name), encoding="utf-8", errors="replace").read().splitlines()
    hdr = lines[0].split(";")
    rows, fixed = [], 0
    for ln in lines[1:]:
        f = ln.split(";")
        if len(f) == len(hdr):
            rows.append(f); continue
        if name != "restaurant_establishments.csv":
            continue
        # permit, facility, owner, PE, then name;location;address with extra semicolons, then lat (-11x.x or empty), lon, city_id
        k = next((i for i in range(6, len(f) - 3) if re.fullmatch(r"-11\d\.\d+|", f[i]) and re.fullmatch(r"3\d\.\d+|", f[i + 1])
                  and re.fullmatch(r"-?\d+", f[i + 2])), None)
        if k is None:
            continue
        addr, loc, name_ = f[k - 1], f[k - 2], ";".join(f[4:k - 2])
        tail = f[k:]
        # tail: lat, lon, city_id, city_name, zip, nciaa, plan_review, record_status, grade, demerits, date_current, prev, date_prev, search..
        z = next((i for i in range(4, len(tail)) if re.fullmatch(r"\d{5}(?:-\d{4})?", tail[i])), None)
        if z is None:
            continue
        rest = tail[z + 1:z + 9]
        if len(rest) < 8:
            continue
        rows.append(f[:4] + [name_, loc, addr] + tail[:3] + [" ".join(tail[3:z])] + [tail[z]] + rest + [";".join(tail[z + 9:]), ""])
        fixed += 1
    df = pd.DataFrame([r[:len(hdr)] for r in rows], columns=hdr)
    df.attrs["fixed"] = fixed
    return df


def load_snhd():
    E = _read_snhd("restaurant_establishments.csv")
    E = E[E.record_status.isin(["01", "04"])].copy()   # 01 active, billable; 04 active, exempt from billing
    # the file's latitude column holds the longitude and the other way round
    lo_, la_ = pd.to_numeric(E.latitude, errors="coerce"), pd.to_numeric(E.longitude, errors="coerce")
    ok = la_.between(34.9, 37.6) & lo_.between(-116.3, -113.9)
    E["lat"], E["lon"] = la_.where(ok), lo_.where(ok)
    E[["kind", "label"]] = [list(_pe(c)) for c in E.PE]
    E["oname"] = E.restaurant_name.map(_outlet)
    E["host_free"] = E.location_name.map(_host_free)
    E["okey"] = E.oname.map(norm_name)
    out = []
    for fac, g in E.groupby("facility_id", sort=False):
        loc = g.host_free.mode().iat[0] if len(g) else ""
        lk = norm_name(loc)
        lst = _stems(lk) - GENERIC
        # one business per facility when the location's own name runs through its permits ("EMERILS ..." under "EMERILS NEW ORLEANS
        # FISH HOUSE"); otherwise a resort or venue facility whose permits name their outlets ("RW CROSSROADS", "RW BACCARAT")
        shares = [bool(lst & (_stems(k) - GENERIC)) or (lk and name_sim(lk, k) >= 85) for k in g.okey]
        single = len(g) <= 2 or (sum(shares) >= 0.6 * len(g) and len(set(g.okey)) <= 12)
        if single:
            groups = {lk or g.okey.iat[0]: list(g.index)}
        else:
            # strip the facility's own prefix ("RW", "MB", "ARA MGM", "BELLAGIO") before grouping outlets
            first = collections.Counter(k.split()[0] for k in g.okey if k)
            pre = first.most_common(1)[0][0] if first and first.most_common(1)[0][1] >= 0.5 * len(g) else None
            groups = collections.defaultdict(list)
            for i, k in zip(g.index, g.okey):
                kk = " ".join(k.split()[1:]) if pre and k.startswith(pre + " ") and len(k.split()) > 1 else k
                hit = next((h for h in groups if h and kk and (name_sim(h, kk) >= 90 or h.startswith(kk + " ") or kk.startswith(h + " "))), None)
                groups[hit or kk].append(i)
        for key, ix in groups.items():
            gg = E.loc[ix]
            food = gg[gg.kind == "food"]
            frontp = (food if len(food) else gg).assign(r=lambda d: d.label.map(FRONT).fillna(9)).sort_values("r").iloc[0]
            kind = "food" if len(food) else collections.Counter(gg.kind).most_common(1)[0][0]
            if single:
                disp = loc or frontp.oname
            else:
                disp = frontp.oname
                if pre and disp.startswith(pre + " ") and len(disp.split()) > 1:
                    disp = disp[len(pre) + 1:]
            names = _names(disp, frontp.oname, *([loc] if single else []))
            pt = gg[gg.lat.notna()]
            out.append({"jur": "snhd", "lic": "snhd-" + frontp.permit_number, "name": disp, "dba": disp, "holder": None, "keys": names,
                        "addr": _addr(frontp.address), "city": canon_city(frontp.city_name) or canon_city(gg.city_name.mode().iat[0]),
                        "zip": _zip(frontp.zip_code), "lat": pt.lat.median() if len(pt) else np.nan, "lon": pt.lon.median() if len(pt) else np.nan,
                        "kind": kind, "active": True, "ltype": frontp.label, "facility": fac, "host": None if single else loc,
                        "front": frontp.permit_number,
                        "permits": [[p, l_, k_] for p, l_, k_ in zip(gg.permit_number, gg.label, gg.kind)]})
    df = pd.DataFrame(out)
    nk = df.addr.map(street_key)
    df["num"] = [k[0] for k in nk]; df["street"] = [k[1] for k in nk]
    df["county"] = "Clark County"
    print("SNHD: active permits", len(E), "| facilities", E.facility_id.nunique(), "| outlets", len(df), df.kind.value_counts().to_dict(),
          "| rows re-split around stray semicolons", _read_snhd.__defaults__ if False else "")
    return df


def snhd_inspections(through):
    """Every inspection on or before `through`: permit, date, type, demerits, grade (A/B/C, X = closed), result, cited items.
    The grade is the card SNHD issued, never one we derive from demerits (some B cards carry single-digit demerits: a repeat
    violation or a failed re-inspection also downgrades)."""
    I = _read_snhd("restaurant_inspections.csv")
    I["d"] = I.inspection_date.str[:10]
    I = I[I.d.notna() & (I.d <= through)].copy()
    I["dem"] = pd.to_numeric(I.inspection_demerits, errors="coerce")
    I["grade"] = I.inspection_grade.str.strip().str.upper().where(lambda s: s.isin(["A", "B", "C", "X"]))
    TYP = {"916": "Routine", "914": "Re-inspection", "935": "Pre-opening", "919": "Survey", "902": "Complaint", "918": "Special request",
           "604": "Epidemiological", "928": "Remodel"}
    I["typ"] = I.inspection_type_id.map(TYP).fillna("Inspection")
    I["res"] = I.inspection_result.str.replace('"', "", regex=False).str.strip()
    return I[["permit_number", "d", "typ", "dem", "grade", "res", "violations"]].rename(columns={"permit_number": "permit"}).sort_values(["permit", "d"])


def snhd_violations():
    """violation id -> (code, demerits, description) from the zip's restaurant_violations.csv."""
    V = _read_snhd("restaurant_violations.csv")
    return {r.violation_id: (r.violation_code, pd.to_numeric(r.violation_demerits, errors="coerce"), (r.violation_description or "").strip())
            for r in V.itertuples()}


# ---------------------------------------------------------------- business licenses
LIC_META = {}


def _rows(name):
    d = json.load(open(os.path.join(OFF, f"{name}.json")))
    LIC_META[name] = d["meta"]
    return d["rows"]


def _ms(v):
    return datetime.datetime.fromtimestamp(v / 1000, datetime.timezone.utc).date().isoformat() if isinstance(v, (int, float)) and v > 0 else None


ONPREM = re.compile(r"(?i)tavern|restaurant|supper club|service bar|full (?:service )?(?:liquor )?bar|resort hotel|dining room|on-?premises?|"
                    r"beer (?:and|&) wine|brew ?pub|club\b|lounge|billiard|karaoke|golf course|bowling|within a resort|cat\. ii|banquet")
PACKAGE = re.compile(r"(?i)package|convenience|grocery|drug store|gift store|wholesal|importer|manufactur|specialty|wine cellar|neighborhood")


def _lic_kind(desc):
    d = desc or ""
    if re.search(r"(?i)liquor|alcohol|beer|wine", d):
        if PACKAGE.search(d):
            return "retail"
        return "liquor" if ONPREM.search(d) or re.search(r"(?i)^liquor - (?:taverns?|full bar)", d) else "other"
    if re.search(r"(?i)restaurant|food service|supper club|take-?out|eating|caf[eé]|bakery|snack|food caterer|dining", d):
        return "food"
    if re.search(r"(?i)mobile food|food truck|vending", d):
        return "truck"
    return "other"


def _lic(jur, lic, name, addr, city, z, la, lo, desc, active, extra=None):
    num, st = street_key(addr)
    r = {"jur": jur, "lic": f"{jur}-{lic}", "name": name, "dba": name, "holder": None, "keys": _names(name), "addr": _addr(addr),
         "city": canon_city(city), "zip": _zip(z), "num": num, "street": st, "lat": la, "lon": lo, "kind": _lic_kind(desc),
         "active": active, "ltype": desc, "shown_id": str(lic)}
    r.update(extra or {})
    return r


FOODISH_LIC = re.compile(r"(?i)liquor|alcohol|beer|wine|restaurant|food|supper|take-?out|bakery|snack|dining|tavern|caterer")


def load_clark():
    out = []
    for r in _rows("clark_licenses"):
        desc = r.get("USER_CredentialDescription") or ""
        if not FOODISH_LIC.search(desc):
            continue
        st = r.get("USER_StatusDescription") or ""
        active = st in ("Licensed", "Temporary License", "Limited License")
        addr = " ".join(x for x in (r.get("USER_AddressLine1"), r.get("USER_unitLine")) if x) or r.get("USER_LocationAddress")
        out.append(_lic("ccl", r.get("USER_FullCredentialNumber") or r.get("OBJECTID"), (r.get("USER_LocationName") or "").strip(), addr,
                        r.get("USER_City"), r.get("USER_ZipCode"), r.get("lat", np.nan), r.get("lon", np.nan), desc, active,
                        {"since": _ms(r.get("USER_InitialLicenseIssuedDate")), "status": st}))
    return out


def load_lv():
    out = []
    for r in _rows("lv_licenses"):
        desc = r.get("Type_of_Business") or ""
        if not FOODISH_LIC.search(desc):
            continue
        st = r.get("Status") or ""
        out.append(_lic("lvl", r.get("License__") or r.get("ObjectId"), (r.get("Business_Name") or "").strip(), r.get("Address"), "Las Vegas",
                        r.get("Zip_Code"), np.nan, np.nan, desc, st.lower() == "active", {"status": st, "in_city": r.get("Within_City_Limits")}))
    return out


def load_henderson():
    out = []
    for r in _rows("henderson_licenses"):
        desc = " - ".join(x for x in (r.get("CASETYPE"), r.get("SCOPE")) if x)
        if not FOODISH_LIC.search(r.get("CASETYPE") or "") and not re.search(r"(?i)restaurant|food|liquor|alcohol|beer|wine", r.get("SCOPE") or ""):
            continue
        a = re.sub(r"-\d{5}$", "", r.get("MAIN_ADDRESS_LINE1") or "")
        z = (re.search(r"(\d{5})$", r.get("MAIN_ADDRESS_LINE1") or "") or [None, None])[1]
        unit = re.match(r"^(.*?)-([^-]+)$", a)
        a = unit.group(1) if unit else a
        desc2 = r.get("CASETYPE") or ""
        if desc2 == "Liquor":
            desc2 = "Liquor - " + (r.get("SCOPE") or "").strip()[:80]
        out.append(_lic("hen", r.get("CASENUMBER") or r.get("OBJECTID"), (r.get("DESCRIPTION") or "").strip(), a, "Henderson", z,
                        r.get("lat", np.nan), r.get("lon", np.nan), desc2, (r.get("STATUS") or "").startswith("Active"),
                        {"status": r.get("STATUS"), "in_city": r.get("LOCATION")}))
    return out


def load_reno():
    out = []
    for r in _rows("reno_licenses"):
        desc = r.get("BUSINESS_CLASSIFICATION") or ""
        if not re.search(r"(?i)restaurant|food service|alcohol|wine and beer|dining room", desc):
            continue
        loc = r.get("BUSINESS_LOCATION") or ""
        m = re.match(r"^(.*?),\s*([A-Z .]+),\s*NV\s*(\d{5})?", loc)
        addr, city, z = (m.group(1), m.group(2), m.group(3)) if m else (loc, "Reno", None)
        st = r.get("License_Status") or ""
        out.append(_lic("rno", r.get("LICENSE_NBR") or r.get("OBJECTID"), (r.get("NAME_OF_BUSINESS") or "").strip(), addr, city, z,
                        r.get("lat", np.nan), r.get("lon", np.nan), desc, st in ("Active", "Grace Period", "About to Expire"),
                        {"status": st, "in_city": r.get("JURISDICTION")}))
    return out


def load():
    S = load_snhd()
    L = pd.DataFrame(load_clark() + (load_lv() if os.path.exists(os.path.join(OFF, "lv_licenses.json")) else []) + load_henderson() + load_reno())
    L["county"] = np.where(L.jur.eq("rno"), "Washoe County", "Clark County")
    df = pd.concat([S, L], ignore_index=True)
    df["biz"] = np.arange(len(df))
    # one business's licenses share a biz: the same list, street address and name (Lotus of Siam's food license and its liquor license)
    lic = df.jur.ne("snhd")
    key = df.jur + "|" + df.num.fillna("") + "|" + df.street.fillna("") + "|" + df["keys"].map(lambda k: k[0] if k else "")
    first = df[lic].groupby(key[lic]).biz.transform("min")
    df.loc[lic, "biz"] = first
    print("licenses:", L.groupby(["jur", "kind"]).size().to_dict(), "| active:", L.groupby("jur").active.sum().to_dict())
    return df
