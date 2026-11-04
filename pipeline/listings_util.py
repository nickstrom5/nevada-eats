"""Matching map listings to official license records (used by calibrate.py and colorado.py). Adapted from wi-eats."""
import math
import re
from rapidfuzz import fuzz
from common import name_sim, _stems, GENERIC
from official import street_key, street_nums, street_compat


# a cuisine or dish word in common isn't a business in common: "Mo' Bettahs Hawaiian Style Food" took Hawaiian Bros Island Grill's
# permit at a food hall's address, "YuXiang Korean Chinese" a Korean market's (2026-10-28 QA)
CUISINE_W = {"HAWAIIAN", "MEXICAN", "ITALIAN", "THAI", "CHINESE", "JAPANESE", "KOREAN", "VIETNAMESE", "INDIAN", "GREEK", "CAJUN",
             "SOUTHERN", "ASIAN", "ISLAND", "FILIPINO", "CUBAN", "PERUVIAN", "SUSHI", "PHO", "TACO", "TACOS", "PIZZA", "BURGER", "BURGERS",
             "BBQ", "GRILL", "KITCHEN", "CAFE", "COFFEE", "BAKERY", "DELI", "BAR", "PUB", "WING", "WINGS", "CHICKEN", "NOODLE", "NOODLES", "RAMEN",
             "BOBA", "TEA", "DONUT", "DONUTS", "BAGEL", "BAGELS"}


def _direction(street):
    """The street's direction letter ("6925 N Buffalo Dr" -> "N", "3799 Las Vegas Blvd S" -> "S"), or None."""
    w = re.sub(r"[.,#]", " ", street or "").upper().split()
    full = {"NORTH": "N", "SOUTH": "S", "EAST": "E", "WEST": "W"}
    for t in (w[1:2] + w[-1:]) if len(w) > 2 else []:
        t = full.get(t, t)
        if t in ("N", "S", "E", "W"):
            return t
    return None


def _same_street(a, b):
    """street_compat, or one spelling slip in a long street name ("HELLEN TOLAND" / "HELEN TOLAND", "LAVENDER HILLS" / "LAVENDER HILL")."""
    return street_compat(a, b) or (isinstance(a, str) and isinstance(b, str) and min(len(a), len(b)) >= 8 and fuzz.ratio(a, b) >= 92)


def _close_words(a, b):
    """A distinctive word in common, allowing a spelling slip ("HIMAL CHULI" / "HIMALI CHULO")."""
    return any(x == y or (len(x) >= 5 and len(y) >= 5 and fuzz.ratio(x, y) >= 85) for x in a for y in b)


def official_match(L, R, one_to_one=False, town_words=frozenset(), street_col="street", bonus=None):
    """L: listings with k (name key), street, lat, lon. R: official records with keys, num, street, addr, lat, lon.
    Returns {listing index: official index}. A match needs the same business name nearby, or the same street address
    with a distinctive (non-generic, non-town) name word in common. `bonus` (one number per record) ranks records a listing should
    prefer when several match (Nevada: a resort's dining-room permit before its meat-prep room's); an exact name is preferred too."""
    by_num, grid = {}, {}
    for j, (a, st) in enumerate(zip(R.addr, R.street)):
        for n in street_nums(a):
            if st:
                by_num.setdefault(n, []).append(j)
    for j, (la, lo) in enumerate(zip(R.lat, R.lon)):
        if la == la and lo == lo:
            grid.setdefault((round(la / 0.0015), round(lo / 0.002)), []).append(j)
    rstems = [set().union(*[(_stems(k) - GENERIC - town_words - CUISINE_W) for k in ks]) if ks else set() for ks in R["keys"]]
    rnums = [street_nums(a) for a in R.addr]
    # a far "same address" needs the same town or zip as well (Nevada: SNHD's own point can be 2-23 km off, 2026-10-28 QA)
    rtown = [(str(c).lower() if c == c and c else None, str(z)[:5] if z == z and z else None)
             for c, z in zip(R.get("city", [None] * len(R)), R.get("zip", [None] * len(R)))]
    ltown = [(str(c).lower() if c == c and c else None, str(z)[:5] if z == z and z else None)
             for c, z in zip(L.get("city", [None] * len(L)), L.get("zip", [None] * len(L)))]
    pairs = []
    for i, (k, street, la, lo) in enumerate(zip(L.k, L[street_col], L.lat, L.lon)):
        if not k:
            continue
        _, st = street_key(street)
        nums = street_nums(street)
        cand = set()
        for n in nums:
            cand.update(j for j in by_num.get(n, []) if _same_street(st, R.street.iat[j]))
        if la == la:
            gy, gx = round(la / 0.0015), round(lo / 0.002)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    cand.update(grid.get((gy + dy, gx + dx), []))
        mine = _stems(k) - GENERIC - town_words - CUISINE_W
        for j in cand:
            same_addr = bool(st and _same_street(R.street.iat[j], st) and nums & rnums[j])
            rl, ro = R.lat.iat[j], R.lon.iat[j]
            dist = math.hypot((rl - la) * 111000, (ro - lo) * 79000) if (rl == rl and la == la) else (40 if same_addr else 9999)
            s = max((name_sim(k, rk) for rk in R["keys"].iat[j]), default=0)
            shared = bool(mine & rstems[j]) or _close_words(mine, rstems[j])
            if same_addr and rl == rl and la == la and dist > 2000:
                # the same name at the same street address in the same town is one place even when one point is far off (SNHD placed
                # Red Robin at 10990 Lavender Hill Dr 18 km away); the listing's point is kept
                (lc, lz), (rc, rz) = ltown[i], rtown[j]
                ld, rd = _direction(street), _direction(R.addr.iat[j])
                # "6925 N Buffalo Dr" isn't "6925 S Buffalo": the key drops the direction, so a far pair must not name two
                same_addr = (dist <= 30000 and s >= 75 and shared and bool((lz and lz == rz) or (lc and lc == rc))
                             and not (ld and rd and ld != rd))
                dist = 2000 if same_addr else dist
            if (same_addr and (s >= 75 or shared)) or (dist <= 150 and s >= 88) or (dist <= 60 and s >= 80 and shared):
                exact = 6 if k in R["keys"].iat[j] else 0
                pairs.append((s + (15 if same_addr else 0) - dist / 20 + exact + (bonus[j] if bonus is not None else 0), i, j))
    out, taken_l, taken_r = {}, set(), set()
    for sc, i, j in sorted(pairs, key=lambda t: -t[0]):
        if i in taken_l or (one_to_one and j in taken_r):
            continue
        taken_l.add(i); taken_r.add(j); out[i] = j
    return out
