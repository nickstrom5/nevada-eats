import Foundation
import CoreLocation
import SwiftUI

// MARK: - The bundled data (Resources/places.json + Resources/detail-<region>.json), written by pipeline/nevada.py with NV_APP=1
// places.json is the statewide core every screen needs at launch (about 11,000 places); a region's detail file (the Southern Nevada
// Health District's inspection history, permits and licenses, phone, website) is read only when one of its places opens.

/// The core file's header (everything but the places). Read with JSONSerialization, not Codable: tens of thousands of keyed records
/// through JSONDecoder made launch slow (Florida's lesson).
struct DataFile {
    let generated: String
    /// the Overture Maps release the listings come from ("2026-09-23.1")
    let overture_release: String?
    /// the day the Southern Nevada Health District's restaurant file was read
    let permits_updated: String
    /// SNHD's restaurant file (permits, inspections and code tables)
    let permitsURL: URL?
    /// the last inspection day in SNHD's records, a week before the file was read ("snhd": "2026-10-20")
    let inspections_through: [String: String]
    /// SNHD's grade cards in the order the data indexes them ("A", "B", "C", "X"; X = closed by the district)
    let results: [String]
    /// inspection types in the order the history indexes them ("Pre-opening", "Re-inspection", "Routine", ...)
    let itypes: [String]
    let cities: [String]
    let cuisines: [String]
    let brands: [String]
    let counties: [String]
    /// the regions the detail files are split by ("Houston & Gulf Coast", ...); a place's `rg` indexes this
    let regions: [String]
    let srcs: [String]
    let count_restaurants: Int
    let calibration: Calibration

    struct Malformed: LocalizedError { let field: String; var errorDescription: String? { "the data file is missing \(field)" } }

    init(json r: [String: Any]) throws {
        func str(_ k: String) throws -> String { guard let v = r[k] as? String else { throw Malformed(field: k) }; return v }
        func list(_ k: String) throws -> [String] { guard let v = r[k] as? [String] else { throw Malformed(field: k) }; return v }
        generated = try str("generated")
        overture_release = r["overture_release"] as? String
        permits_updated = try str("permits_updated")
        permitsURL = (r["permits_url"] as? String).flatMap(URL.init(string:))
        inspections_through = (r["inspections_through"] as? [String: String]) ?? [:]
        results = (r["results"] as? [String]) ?? []
        itypes = (r["itypes"] as? [String]) ?? []
        cities = try list("cities"); cuisines = try list("cuisines"); brands = try list("brands"); counties = try list("counties")
        regions = (r["regions"] as? [String]) ?? []
        srcs = try list("srcs")
        guard let n = r["count_restaurants"] as? Int else { throw Malformed(field: "count_restaurants") }
        count_restaurants = n
        let cal = (r["calibration"] as? [String: Any]).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        calibration = cal.flatMap { try? JSONDecoder().decode(Calibration.self, from: $0) } ?? Calibration(areas: [:])
    }
}

/// How often listings of one kind matched an SNHD outlet (pipeline/calibrate.py):
/// {"Clark County (SNHD outlets)": {"groups": {"meta_high": {"n": 4886, "official": 0.83}, ...}}}
struct Calibration: Decodable, Hashable {
    let areas: [String: CalibrationScope]

    init(areas: [String: CalibrationScope]) { self.areas = areas }
    init(from decoder: Decoder) throws {
        areas = try decoder.singleValueContainer().decode([String: CalibrationScope].self)
    }
}

struct CalibrationScope: Decodable, Hashable {
    let groups: [String: CalibrationGroup]
}

struct CalibrationGroup: Decodable, Hashable {
    let n: Int
    let official: Double
}

/// An official record behind the place: [list ("SNHD health permit", "Clark County business license"...), the permit or license number].
struct License: Decodable, Hashable {
    let source: String
    let id: String?

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        source = try c.decode(String.self)
        id = try c.decodeIfPresent(String.self)
    }
}

/// One graded inspection in a place's history: [date, grade index, demerits or null, inspection type index].
struct InspectionVisit: Decodable, Hashable {
    let date: String
    let grade: Int
    let demerits: Int?
    let type: Int

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        date = try c.decode(String.self)
        grade = try c.decode(Int.self)
        demerits = try c.decodeIfPresent(Int.self)
        type = try c.decodeIfPresent(Int.self) ?? 0
    }
}

/// An item cited on the latest inspection: [SNHD's item id, demerits or null, the item as SNHD words it]. SNHD's 2020s items are
/// written as the standard checked ("Adequate handwashing sinks stocked and accessible."): cited means it wasn't met that day.
struct CitedItem: Decodable, Hashable {
    let code: String?
    let demerits: Int?
    let text: String?

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        code = try c.decodeIfPresent(String.self)
        demerits = try c.decodeIfPresent(Int.self)
        text = try c.decodeIfPresent(String.self)
    }
}

/// Another public permit of the same place (a bar inside a restaurant): [permit type, permit number, grade index, date, demerits].
struct OtherPermit: Decodable, Hashable {
    let label: String
    let permit: String
    let grade: Int
    let date: String
    let demerits: Int?

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        label = try c.decode(String.self)
        permit = try c.decode(String.self)
        grade = try c.decode(Int.self)
        date = try c.decode(String.self)
        demerits = try c.decodeIfPresent(Int.self)
    }
}

/// The place's SNHD inspection record (detail file): how many graded inspections, the permit they belong to, the latest eight, the
/// latest one's items, and the outlet's other public permits.
struct InspectionDetail: Decodable, Hashable {
    let n: Int?
    let p: String?
    let h: [InspectionVisit]?
    let i: [CitedItem]?
    let o: [OtherPermit]?
    var visits: [InspectionVisit] { h ?? [] }
    var items: [CitedItem] { i ?? [] }
    var others: [OtherPermit] { o ?? [] }
}

/// The latest graded inspection (core file): [jurisdiction index, grade index, date, demerits]. The grade is the card SNHD issued
/// (A, B, C, or X when it closed the place), never worked out from the demerits.
struct InspectionRecord: Hashable {
    let jurisdiction: Int
    let grade: Int
    let date: String
    let demerits: Int?

    init?(array a: [Any]) {
        guard a.count >= 4, let j = a[0] as? Int, let g = a[1] as? Int, let d = a[2] as? String else { return nil }
        jurisdiction = j; grade = g; date = d
        demerits = (a[3] as? Int) ?? (a[3] as? Double).map { Int($0) }
    }
    init(grade: Int, demerits: Int?, date: String) { jurisdiction = 0; self.grade = grade; self.demerits = demerits; self.date = date }

    /// "8 demerits", "1 demerit", "—"
    var demeritsText: String { demerits.map { "\($0) demerit\($0 == 1 ? "" : "s")" } ?? "demerits not published" }
    /// SNHD's X card: the district closed the place at this inspection
    var isClosure: Bool { grade == 3 }
}

/// A place's detail record, from its region's detail file.
struct PlaceDetail: Decodable, Hashable {
    let lic: [License]?
    let ph: String?
    let w: String?
    let inspection: InspectionDetail?

    enum CodingKeys: String, CodingKey {
        case lic, ph, w
        case inspection = "in"
    }

    /// web links only: a bare host gets https://, and any other scheme (javascript:, tel:, a custom app URL) is dropped
    var website: URL? {
        w.flatMap { URL(string: $0.contains("://") ? $0 : "https://" + $0) }
            .flatMap { ["http", "https"].contains($0.scheme?.lowercased() ?? "") && $0.host != nil ? $0 : nil }
    }
    var licenses: [License] { lic ?? [] }
}

struct PlaceRecord {
    // the memberwise initializer is used by init?(_ d:) below
    let id: String
    let n: String
    let c: Int?
    let cu: Int
    let t: Int
    let s: Int
    let co: Int?
    let rg: Int?
    let a: String?
    let z: String?
    let la: Double?
    let lo: Double?
    let b: Int?
    let ch: Int?
    let v: Int?
    let bar: Int?
    /// 1 when the place holds its own active on-premises liquor license (Clark County, Las Vegas, Henderson or Reno)
    let liq: Int?
    let g: Int?
    let hc: Int?
    let h: Int?
    let mi: Int?
    let jbf: String?
    let ip: Double?
    let f: Int?
    let fn: String?
    let note: String?
    let dish: String?
    let seas: String?
    /// the listing's other name when a hand-checked place shows its verified one ("Cafe Versailles Calle 8"): searchable, shown small
    let aka: String?
    /// SNHD's latest graded inspection (Clark County only)
    let inspection: InspectionRecord?
}

extension PlaceRecord {
    /// From one JSONSerialization dictionary (the fast path); nil when the required fields are missing.
    init?(_ d: [String: Any]) {
        guard let id = d["id"] as? String, let n = d["n"] as? String, let cu = d["cu"] as? Int, let t = d["t"] as? Int, let s = d["s"] as? Int else { return nil }
        func i(_ k: String) -> Int? { d[k] as? Int }
        func str(_ k: String) -> String? { d[k] as? String }
        self.init(id: id, n: n, c: i("c"), cu: cu, t: t, s: s, co: i("co"), rg: i("rg"), a: str("a"), z: str("z"), la: d["la"] as? Double,
                  lo: d["lo"] as? Double, b: i("b"), ch: i("ch"), v: i("v"), bar: i("bar"), liq: i("liq"), g: i("g"), hc: i("hc"), h: i("h"),
                  mi: i("mi"), jbf: str("jbf"), ip: d["ip"] as? Double, f: i("f"), fn: str("fn"), note: str("note"), dish: str("dish"),
                  seas: str("seas"), aka: str("aka"), inspection: (d["in"] as? [Any]).flatMap { InspectionRecord(array: $0) })
    }
}

// MARK: - The model the views use

struct PlaceTags: OptionSet, Hashable {
    let rawValue: Int
    static let basque = PlaceTags(rawValue: 1)        // hand-checked Basque dining (Elko, Winnemucca, Reno)
    static let casinoClassics = PlaceTags(rawValue: 2) // hand-checked casino classics (prime rib, steak and eggs, shrimp cocktail)
    static let buffets = PlaceTags(rawValue: 4)       // hand-checked buffets, each with a 2026 source showing it serving
    static let chinatown = PlaceTags(rawValue: 8)     // hand-checked Spring Mountain Road Chinatown
    static let plateLunch = PlaceTags(rawValue: 16)   // hand-checked Hawaiian plate lunch
    static let steakhouses = PlaceTags(rawValue: 32)  // hand-checked old Vegas steakhouses
    static let saloons = PlaceTags(rawValue: 64)      // hand-checked mining-town saloons
    static let oldest = PlaceTags(rawValue: 128)      // hand-checked, open at this address since 1960 or earlier
}

/// How a place got on the list. The share that matched a license comes from calibration.
enum Tier: Int, Comparable {
    case listing = 0        // one map listing
    case confirmed = 1      // a high-confidence Meta listing, or a hand-checked place
    case licensed = 2       // on an official list: an SNHD health permit or a city's or the county's business license

    static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .licensed: "On an official list"
        case .confirmed: "High-confidence listing"
        case .listing: "Listing only"
        }
    }
}

enum Michelin: Int {
    case none = 0, recommended = 1, bib = 2, oneStar = 3, twoStars = 4, threeStars = 5
    var label: String? {
        switch self {
        case .none: nil
        case .recommended: "MICHELIN Recommended"
        case .bib: "Bib Gourmand"
        case .oneStar: "1 MICHELIN Star"
        case .twoStars: "2 MICHELIN Stars"
        case .threeStars: "3 MICHELIN Stars"
        }
    }
}

struct Place: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String?
    let city: String?
    let county: String?
    /// the region whose detail file holds this place's inspection history, permit, phone and website
    let region: String?
    let zip: String?
    let coordinate: CLLocationCoordinate2D?
    let cuisine: String
    let brand: String?
    let chainCount: Int
    let tier: Tier
    let source: String
    let isVenue: Bool
    let isBar: Bool
    /// holds its own active on-premises liquor license (Clark County, Las Vegas, Henderson, Reno); false means unknown, never "no"
    let servesBeer: Bool
    /// SNHD's latest graded inspection (Clark County only)
    let inspection: InspectionRecord?
    let tags: PlaceTags
    /// On our hand-checked list (data/research): confirmed open with a 2025–26 source.
    let handChecked: Bool
    let honorFlags: Int
    let michelin: Michelin
    let iconicPoints: Double?
    let jamesBeard: String?
    let founded: Int?
    let foundedNote: String?
    let note: String?
    let dishes: String?
    let seasonal: String?
    /// normalized text for search: name, town, county, zip, cuisine, brand, dishes, then the address with street words abbreviated
    private(set) var searchText: String
    let nameText: String
    /// the A-to-Z key, worked out once at load: the normalized name ("por wine house" for "/pôr/ Wine House"), so case, accents
    /// and leading punctuation don't change the order, and a sort never runs a localized compare per comparison
    let sortKey: String
    /// made once at load: a new CLLocation per comparison made a Nearest sort of 16,000 places take seconds
    let location: CLLocation?

    static func == (a: Place, b: Place) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    /// MICHELIN, James Beard or a verified founding year: what the map and Spotlight put first
    var isHonored: Bool { honorFlags != 0 || michelin != .none }
    /// what the Honors section lists: a MICHELIN distinction or a James Beard honor ("oldest" alone isn't an honor)
    var hasHonors: Bool { michelin != .none || jamesBeard != nil }
    var isChain: Bool { chainCount >= 5 }
    var jamesBeardLabel: String? {
        if honorFlags & 1 != 0 { return "America's Classic" }
        if honorFlags & 2 != 0 { return "James Beard winner" }
        if honorFlags & 4 != 0 { return "James Beard finalist" }
        if honorFlags & 8 != 0 { return "James Beard semifinalist" }
        return nil
    }
    /// The chip for a James Beard line: the place's own honor, or a restaurateur (group) honor when that's the only one.
    var jamesBeardChip: String? { jamesBeardLabel ?? (jamesBeard != nil ? "James Beard (restaurateur)" : nil) }
    /// a hand-checked Nevada pick: the sandstone pins
    var isClassic: Bool { handChecked && !tags.isEmpty }
    var townLine: String { [city, cuisine].compactMap { $0 }.joined(separator: " · ") }
    var fullAddress: String {
        [address, [city, zip].compactMap { $0 }.joined(separator: " ")].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Every place in the core file, built on all cores at once (each place's search text takes four normalizations).
    static func build(_ raw: [[String: Any]], file: DataFile) -> [Place] {
        var out = [Place?](repeating: nil, count: raw.count)
        let chunk = 2_000, chunks = (raw.count + chunk - 1) / chunk
        out.withUnsafeMutableBufferPointer { buf in
            let base = buf   // each chunk writes only its own slots
            DispatchQueue.concurrentPerform(iterations: chunks) { c in
                for k in (c * chunk)..<min(raw.count, (c + 1) * chunk) {
                    base[k] = PlaceRecord(raw[k]).map { Place($0, file: file) }
                }
            }
        }
        return out.compactMap { $0 }
    }

    init(_ r: PlaceRecord, file: DataFile) {
        let city = r.c.flatMap { $0 < file.cities.count ? file.cities[$0] : nil }
        let cuisine = r.cu < file.cuisines.count ? file.cuisines[r.cu] : "American & Other"
        let brand = r.b.flatMap { $0 < file.brands.count ? file.brands[$0] : nil }
        let county = r.co.flatMap { $0 < file.counties.count ? file.counties[$0] : nil }
        id = r.id
        name = r.n
        address = r.a
        self.city = city
        self.county = county
        region = r.rg.flatMap { $0 < file.regions.count ? file.regions[$0] : nil }
        zip = r.z
        if let la = r.la, let lo = r.lo { coordinate = CLLocationCoordinate2D(latitude: la, longitude: lo) } else { coordinate = nil }
        self.cuisine = cuisine
        self.brand = brand
        chainCount = r.ch ?? 1
        tier = Tier(rawValue: r.t) ?? .listing
        source = r.s < file.srcs.count ? file.srcs[r.s] : "meta"
        isVenue = r.v == 1
        isBar = r.bar == 1
        servesBeer = r.liq == 1
        inspection = r.inspection
        tags = PlaceTags(rawValue: r.g ?? 0)
        handChecked = r.hc == 1
        honorFlags = r.h ?? 0
        michelin = Michelin(rawValue: r.mi ?? 0) ?? .none
        iconicPoints = r.ip
        jamesBeard = r.jbf
        founded = r.f
        foundedNote = r.fn
        note = r.note
        dishes = r.dish
        seasonal = r.seas
        // the dishes a hand-checked place serves are searchable too: "prime rib", "picon punch"
        searchText = " " + Search.normalize([r.n, r.aka, city, county, r.z, cuisine, brand, r.dish].compactMap { $0 }.joined(separator: " ")) + " "
            + Search.normalizeAddress(r.a ?? "") + " "
        // "barbecue" and "bbq" find the same places (QA 2026-10-26: Tennessee's "barbecue" found 57 places, "bbq" 478)
        if searchText.contains(" barbecue ") || searchText.contains(" barbeque ") { searchText += "bbq " }
        if searchText.contains(" bbq ") { searchText += "barbecue " }
        nameText = " " + Search.normalize([r.n, brand].compactMap { $0 }.joined(separator: " ")) + " "
        sortKey = Search.normalize(r.n)
        location = coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

/// The data's dates are calendar days ("2026-06-16"), not moments: read and shown in UTC, so no time zone can move one a day.
enum DayFormat {
    private static let utc = TimeZone(identifier: "UTC")!

    static func date(_ s: String?) -> Date? {
        guard let s, s.count >= 10 else { return nil }
        let parts = s.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// "Jun 16, 2026" (in the reader's language); anything that isn't a date is shown as it is
    static func text(_ s: String?) -> String? {
        guard let s else { return nil }
        guard let d = date(s) else { return s }
        return d.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: utc))
    }

    /// "Sep 2025"
    static func monthYear(_ s: String?) -> String? {
        guard let s else { return nil }
        guard let d = date(s) else { return s }
        return d.formatted(Date.FormatStyle(timeZone: utc).month(.abbreviated).year())
    }
}
