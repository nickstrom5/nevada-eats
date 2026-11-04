import XCTest
import CoreLocation
@testable import NevadaEats

@MainActor
final class NevadaEatsTests: XCTestCase {

    /// A tiny core file and two region detail files with the same shape as Resources/places.json and Resources/detail-*.json.
    private func sampleModel() async throws -> AppModel {
        let json = """
        {"v":1,"generated":"2026-10-27","overture_release":"2026-10-21.0","permits_updated":"2026-10-27",
         "permits_url":"https://www.southernnevadahealthdistrict.org/restaurants/download/restaurants.zip","inspections_through":{"snhd":"2026-10-20"},
         "results":["A","B","C","X"],"itypes":["Pre-opening","Re-inspection","Routine"],"ins_jur":["snhd"],
         "cities":["Las Vegas","Reno","Henderson","Elko","North Las Vegas","Sparks"],
         "cuisines":["American & Other","Italian","Thai","Burgers","Breakfast & Diner","Steakhouse"],
         "brands":["In-N-Out Burger"],"counties":["Clark County","Washoe County","Elko County"],
         "regions":["Las Vegas & Southern Nevada","Reno, Sparks & Lake Tahoe","Carson City & Carson Valley","Elko & Northeastern Nevada","Central Nevada"],
         "srcs":["official","meta","AllThePlaces","DAC","research"],
         "count":9,"count_restaurants":8,
         "calibration":{"Clark County (SNHD outlets)":{"listings":12919,"groups":{"meta_high":{"n":4886,"official":0.83}}}},
         "places":[
          {"id":"a","n":"Esther's Kitchen","c":0,"co":0,"rg":0,"cu":1,"t":2,"s":1,"hc":1,"mi":2,"ip":36,"a":"1131 S Main St","z":"89104",
           "la":36.1576,"lo":-115.1534,"in":[0,0,"2026-03-10",8]},
          {"id":"b","n":"Peppermill Restaurant and Fireside Lounge","c":0,"co":0,"rg":0,"cu":4,"t":2,"s":1,"hc":1,"g":130,"h":17,"f":1972,
           "jbf":"America's Classic 2024","a":"2985 Las Vegas Blvd S","la":36.1337,"lo":-115.1632,"dish":"prime rib","in":[0,1,"2026-05-26",14]},
          {"id":"c","n":"In-N-Out Burger","c":2,"co":0,"rg":0,"cu":3,"t":1,"s":2,"b":0,"ch":25,"la":36.03,"lo":-115.08},
          {"id":"d","n":"Louis' Basque Corner","c":1,"co":1,"rg":1,"cu":0,"t":1,"s":1,"hc":1,"g":129,"f":1967,"a":"301 E 4th St","la":39.5310,"lo":-119.8090,
           "dish":"picon punch"},
          {"id":"e","n":"Arco","c":0,"co":0,"rg":0,"cu":0,"t":1,"s":1,"v":1,"la":36.10,"lo":-115.20},
          {"id":"f","n":"Restaurant de Joël Robuchon","c":0,"co":0,"rg":0,"cu":0,"t":2,"s":1,"hc":1,"mi":4,"ip":62,"a":"3799 Las Vegas Blvd S",
           "la":36.1022,"lo":-115.1700,"in":[0,0,"2026-02-20",3]},
          {"id":"g","n":"Lotus of Siam","c":0,"co":0,"rg":0,"cu":2,"t":2,"s":1,"hc":1,"h":2,"jbf":"Best Chef: Southwest winner 2011 (Saipin Chutima)",
           "a":"953 E Sahara Ave","la":36.1420,"lo":-115.1422,"in":[0,2,"2026-06-11",27]},
          {"id":"h","n":"Star Hotel","c":3,"co":2,"rg":3,"cu":0,"t":1,"s":1,"hc":1,"g":1,"a":"246 Silver St","la":40.8350,"lo":-115.7620},
          {"id":"i","n":"Lucky Diner","c":4,"co":0,"rg":0,"cu":4,"t":1,"s":1,"a":"100 W Lake Mead Blvd","la":36.1960,"lo":-115.1170}
         ]}
        """
        let vegas = """
        {"a":{"lic":[["SNHD health permit","PR0147555"],["City of Las Vegas business license","B12345"]],"ph":"(702) 570-7864","w":"estherslv.com",
              "in":{"n":3,"p":"PR0147555","h":[["2026-03-10",0,8,2],["2025-01-16",0,9,2],["2024-06-01",1,null,1]],
                    "i":[["8078371",3,"Adequate handwashing sinks stocked and accessible."],["76432",null,"Food handler failed to wash hands when required."]],
                    "o":[["Bar","PR0147554",0,"2026-03-10",5]]}},
         "g":{"w":"javascript:alert(1)","in":{"n":4,"p":"PR0000001","h":[["2026-06-11",2,27,2]],"i":[]}}}
        """
        let reno = """
        {"d":{"w":"https://www.louisbasquecorner.com/"}}
        """
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nv-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("places.json")
        try json.data(using: .utf8)!.write(to: url)
        try vegas.data(using: .utf8)!.write(to: dir.appendingPathComponent("detail-las-vegas-southern-nevada.json"))
        try reno.data(using: .utf8)!.write(to: dir.appendingPathComponent("detail-reno-sparks-lake-tahoe.json"))
        let model = AppModel(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        await model.load(from: url, detailFolder: dir)
        XCTAssertTrue(model.isLoaded, model.loadError ?? "")
        return model
    }

    func testDecodesAndHidesNonRestaurantsByDefault() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.places.count, 9)
        XCTAssertEqual(m.restaurantCount, 8)
        XCTAssertFalse(m.list(.all, sort: .name, search: "", here: nil).contains { $0.name == "Arco" }, "a gas-station counter is hidden by default")
        m.filters.includeNonRestaurants = true
        XCTAssertTrue(m.list(.all, sort: .name, search: "", here: nil).contains { $0.name == "Arco" })
        XCTAssertEqual(m.permitsUpdated, "2026-10-27")
    }

    func testGuidesListOnlyWhatTheyPromise() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.list(.basque, sort: .name, search: "", here: nil).map(\.name), ["Louis' Basque Corner", "Star Hotel"])
        XCTAssertEqual(m.list(.casinoClassics, sort: .name, search: "", here: nil).map(\.name), ["Peppermill Restaurant and Fireside Lounge"])
        XCTAssertEqual(m.list(.oldest, sort: .oldest, search: "", here: nil).map(\.name), ["Louis' Basque Corner", "Peppermill Restaurant and Fireside Lounge"])
        XCTAssertEqual(m.list(.honors, sort: .iconic, search: "", here: nil).map(\.name),
                       ["Restaurant de Joël Robuchon", "Esther's Kitchen", "Peppermill Restaurant and Fireside Lounge", "Lotus of Siam"])
        XCTAssertEqual(m.list(.chinatown, sort: .name, search: "", here: nil), [], "a guide with nothing hand-checked yet is empty, not padded")
    }

    /// SNHD's own grade cards, ordered card first and demerits second, never a grade worked out from demerits; a closure reads as one.
    func testInspectionsAreTheHealthDistrictsOwn() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.list(.inspections, sort: .recent, search: "", here: nil).map(\.name),
                       ["Lotus of Siam", "Peppermill Restaurant and Fireside Lounge", "Esther's Kitchen", "Restaurant de Joël Robuchon"])
        XCTAssertEqual(m.list(.inspections, sort: .highestScore, search: "", here: nil).map(\.name),
                       ["Restaurant de Joël Robuchon", "Esther's Kitchen", "Peppermill Restaurant and Fireside Lounge", "Lotus of Siam"])
        XCTAssertEqual(m.list(.inspections, sort: .lowestScore, search: "", here: nil).map(\.name),
                       ["Lotus of Siam", "Peppermill Restaurant and Fireside Lounge", "Esther's Kitchen", "Restaurant de Joël Robuchon"])
        let e = try XCTUnwrap(m.place(id: "a")?.inspection)
        XCTAssertEqual(e.demerits, 8); XCTAssertEqual(e.demeritsText, "8 demerits"); XCTAssertEqual(m.grade(e.grade), "A"); XCTAssertEqual(e.date, "2026-03-10")
        XCTAssertEqual(m.gradeLabel(m.place(id: "g")!.inspection!.grade), "Grade C")
        XCTAssertEqual(m.gradeLabel(3), "Closed (X)", "SNHD's X card is a closure")
        XCTAssertTrue(InspectionRecord(grade: 3, demerits: nil, date: "2026-10-01").isClosure)
        XCTAssertEqual(InspectionRecord(grade: 0, demerits: 1, date: "2026-10-01").demeritsText, "1 demerit")
        XCTAssertNil(m.place(id: "d")!.inspection, "outside Clark County no grade is shown, and none is computed")
        XCTAssertTrue(AppModel.inspector(county: "Washoe County").contains("Northern Nevada Public Health"))
        XCTAssertEqual(m.grade(7), "—", "a grade the data doesn't name is unknown")
        XCTAssertEqual(m.inspectionsThrough, "2026-10-20")
        XCTAssertEqual(m.inspectionType(1), "Re-inspection")
        let d = await m.detail(for: m.place(id: "a")!)
        XCTAssertEqual(d?.inspection?.n, 3)
        XCTAssertEqual(d?.inspection?.p, "PR0147555")
        XCTAssertEqual(d?.inspection?.visits.map(\.demerits), [8, 9, nil], "a missing demerit count stays missing")
        XCTAssertEqual(d?.inspection?.visits.last?.type, 1)
        XCTAssertEqual(d?.inspection?.items.first?.demerits, 3)
        XCTAssertEqual(d?.inspection?.others.first?.label, "Bar")
    }

    func testDatesAreCalendarDays() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let d = DayFormat.date("2026-06-16")!
        XCTAssertEqual(utc.dateComponents([.year, .month, .day], from: d), DateComponents(year: 2026, month: 6, day: 16))
        XCTAssertTrue(DayFormat.monthYear("2025-09-01")!.contains("2025"))
        XCTAssertNil(DayFormat.date("2026-13-01"))
        XCTAssertEqual(DayFormat.text("soon"), "soon", "a value that isn't a date is shown as it is")
    }

    func testRegionDetailsLoadOnDemand() async throws {
        let m = try await sampleModel()
        let v = await m.detail(for: m.place(id: "a")!)
        XCTAssertEqual(v?.licenses.first?.id, "PR0147555")
        XCTAssertEqual(v?.licenses.first?.source, "SNHD health permit")
        XCTAssertEqual(v?.website?.absoluteString, "https://estherslv.com", "a bare host gets https://")
        let g = await m.detail(for: m.place(id: "g")!)
        XCTAssertNil(g?.website, "a javascript: link never becomes a website button")
        let r = await m.detail(for: m.place(id: "d")!)
        XCTAssertEqual(r?.website?.host, "www.louisbasquecorner.com")
        XCTAssertEqual(AppModel.regionSlug("Reno, Sparks & Lake Tahoe"), "reno-sparks-lake-tahoe")
        let missing = await m.detail(for: m.place(id: "h")!)
        XCTAssertNil(missing, "a region with no detail file reads as no detail, not a crash")
    }

    func testSearchWordStartsTownsAndGuides() async throws {
        let m = try await sampleModel()
        XCTAssertEqual(m.list(.all, sort: .name, search: "esther", here: nil).map(\.name), ["Esther's Kitchen"])
        XCTAssertEqual(m.list(.all, sort: .name, search: "elko", here: nil).map(\.name), ["Star Hotel"], "a town narrows to it")
        XCTAssertEqual(m.list(.all, sort: .name, search: "north las vegas", here: nil).map(\.name), ["Lucky Diner"], "the town, not every Las Vegas place")
        XCTAssertEqual(m.list(.all, sort: .name, search: "🍕", here: nil), [], "an emoji finds nothing, not everything")
        XCTAssertEqual(m.list(.all, sort: .name, search: "basque", here: nil).map(\.name), ["Louis' Basque Corner", "Star Hotel"], "a guide word means the guide")
        XCTAssertEqual(m.list(.all, sort: .name, search: "basque dining", here: nil).map(\.name), ["Louis' Basque Corner", "Star Hotel"],
                       "the guide's whole name is taken as the guide, not \"basque\" plus a word to find")
        XCTAssertEqual(Search.parse("hawaiian plate lunch", towns: [:]).tag, .plateLunch)
        XCTAssertTrue(Search.parse("hawaiian plate lunch", towns: [:]).tokens.isEmpty, "no \"hawaiian\" left over to search for")
        XCTAssertEqual(m.list(.all, sort: .name, search: "picon punch", here: nil).map(\.name), ["Louis' Basque Corner"])
        XCTAssertEqual(m.list(.all, sort: .name, search: "louis basque", here: nil).map(\.name), ["Louis' Basque Corner"], "apostrophes don't matter")
        XCTAssertEqual(Search.normalize("P.F. Chang's"), "pf changs", "initials keep together")
        XCTAssertEqual(Search.normalize("P.O.P.S. Philly Steaks"), "pops philly steaks")
        XCTAssertEqual(Search.normalize("1 E. Main St."), "1 e main st", "a lone initial or St. stays a word")
        XCTAssertEqual(m.list(.all, sort: .name, search: "las vegas blvd", here: nil).map(\.name).sorted(),
                       ["Peppermill Restaurant and Fireside Lounge", "Restaurant de Joël Robuchon"], "a street, not the town")
    }

    func testOutsideNevadaUsesTheOutline() {
        func inside(_ la: Double, _ lo: Double) -> Bool { NevadaOutline.contains(CLLocationCoordinate2D(latitude: la, longitude: lo)) }
        XCTAssertTrue(inside(36.17, -115.14), "Las Vegas"); XCTAssertTrue(inside(39.53, -119.81), "Reno"); XCTAssertTrue(inside(35.17, -114.57), "Laughlin")
        XCTAssertTrue(inside(38.96, -119.94), "Stateline"); XCTAssertTrue(inside(40.74, -114.07), "West Wendover"); XCTAssertTrue(inside(41.98, -114.67), "Jackpot")
        XCTAssertTrue(inside(40.83, -115.76), "Elko"); XCTAssertTrue(inside(36.80, -114.07), "Mesquite"); XCTAssertTrue(inside(39.16, -119.77), "Carson City")
        XCTAssertFalse(inside(35.19, -114.05), "Kingman"); XCTAssertFalse(inside(37.36, -118.40), "Bishop"); XCTAssertFalse(inside(34.85, -114.61), "Needles")
        XCTAssertFalse(inside(40.76, -111.89), "Salt Lake City"); XCTAssertFalse(inside(34.90, -117.02), "Barstow"); XCTAssertFalse(inside(37.33, -122.03), "Cupertino")
    }

    func testBundledData() async throws {
        let m = AppModel(defaults: UserDefaults(suiteName: "bundle-\(UUID().uuidString)")!)
        await m.load()
        XCTAssertTrue(m.isLoaded, m.loadError ?? "")
        XCTAssertGreaterThan(m.restaurantCount, 8_000)
        XCTAssertGreaterThanOrEqual(m.count(.honors), 27)
        XCTAssertEqual(m.bibCount, 3, "Nevada's three Bib Gourmands (MICHELIN Guide American Southwest 2026)")
        XCTAssertEqual(m.places.filter { $0.michelin == .twoStars }.map(\.name), ["Restaurant de Joël Robuchon"])
        XCTAssertEqual(Set(m.places.filter { $0.michelin == .oneStar }.map(\.name)), ["Restaurant Guy Savoy", "é by José Andrés", "L'Atelier de Joël Robuchon"])
        XCTAssertEqual(Set(m.places.map(\.id)).count, m.places.count, "ids are unique")
        for g in Guide.allCases where g.tag != nil {
            XCTAssertTrue(m.places.filter(g.includes).allSatisfy(\.handChecked), "\(g.title) lists only hand-checked places")
        }
        XCTAssertTrue(m.places.contains { $0.name.hasPrefix("Peppermill") && $0.jamesBeardLabel == "America's Classic" })
        // inspection results are SNHD's only (Clark County), and only its four cards
        let inspected = m.places.filter { $0.inspection != nil }
        XCTAssertGreaterThan(inspected.count, 5_000)
        XCTAssertTrue(inspected.allSatisfy { $0.county == "Clark County" }, "an inspection result outside Clark County")
        XCTAssertEqual(Set(inspected.map { m.grade($0.inspection!.grade) }).subtracting(["A", "B", "C", "X"]), [])
        XCTAssertTrue(inspected.allSatisfy { $0.inspection!.date <= m.inspectionsThrough }, "an inspection after the records-through date")
        XCTAssertTrue(inspected.allSatisfy { ($0.inspection!.demerits ?? 0) >= 0 && ($0.inspection!.demerits ?? 0) <= 200 }, "an impossible demerit count")
        // a place SNHD closed and hasn't re-inspected for a month is left out (pipeline/nevada.py): an X older than that is a bug
        let monthBefore = DayFormat.date(m.inspectionsThrough).map { $0.addingTimeInterval(-30 * 86_400) }
        XCTAssertTrue(inspected.filter { $0.inspection!.isClosure }.allSatisfy { DayFormat.date($0.inspection!.date)! >= monthBefore! },
                      "a closure shown long after it, as if the place were open")
        XCTAssertTrue(m.places.filter(\.servesBeer).allSatisfy { $0.county == "Clark County" || $0.county == "Washoe County" },
                      "a liquor license where no list is published")
        // no Google-derived data: the data file has no rating, review or price fields at all
        let raw = try String(contentsOf: Bundle.main.url(forResource: "places", withExtension: "json")!, encoding: .utf8)
        for key in ["\"rating\"", "\"reviews\"", "\"price\"", "\"gmap_id\"", "google21"] { XCTAssertFalse(raw.contains(key), "\(key) must not ship") }
    }

    /// Stable ids: md5(name + ~100 m cell)[:12], never a row number; every bundled region detail file decodes and its ids are core ids.
    func testIdsAndBundledDetailFiles() async throws {
        let m = AppModel(defaults: UserDefaults(suiteName: "ids-\(UUID().uuidString)")!)
        await m.load()
        XCTAssertTrue(m.places.allSatisfy { $0.id.count >= 12 && $0.id.prefix(12).allSatisfy(\.isHexDigit) && $0.id.dropFirst(12).allSatisfy { $0 == "x" } })
        let ids = Set(m.places.map(\.id))
        var permitted = 0
        for region in Set(m.places.compactMap(\.region)) {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "detail-" + AppModel.regionSlug(region), withExtension: "json"), region)
            let d = try JSONDecoder().decode([String: PlaceDetail].self, from: Data(contentsOf: url))
            XCTAssertTrue(Set(d.keys).isSubset(of: ids), "\(region) detail ids are core ids")
            permitted += d.values.filter { $0.licenses.contains { $0.source == "SNHD health permit" && $0.id != nil } }.count
        }
        XCTAssertGreaterThan(permitted, 5_000, "Clark County places carry their SNHD permit numbers")
    }

    func testBundledDataGuards() async throws {
        let m = AppModel(defaults: UserDefaults(suiteName: "guards-\(UUID().uuidString)")!)
        await m.load()
        XCTAssertTrue(m.isLoaded, m.loadError ?? "")
        XCTAssertEqual(DataGuards.adultVenues(m.places), [], "no strip club under its name")
        XCTAssertEqual(DataGuards.adultWebsites(try DataGuards.bundledLinks(m.places)), [], "no place whose website is a strip club's")
        XCTAssertEqual(DataGuards.malformedWebsites(try DataGuards.bundledLinks(m.places, raw: true)), [], "every website is one clean web address")
        XCTAssertEqual(DataGuards.badWebsites(try DataGuards.bundledLinks(m.places)), [], "no directory, Google or news page as a restaurant's website")
        XCTAssertEqual(DataGuards.badNames(m.places), [], "no visible name ending in \u{201C} the\u{201D} or \u{201C} of\u{201D}, or just \u{201C}The\u{201D}")
        XCTAssertEqual(DataGuards.legalNames(m.places), [], "no license holder entity name (\u{201C}… LLC\u{201D}) shown as a place's name")
        XCTAssertEqual(DataGuards.nonRestaurants(m.places), [], "no nail salon, senior home, gun store or gas station among the restaurants")
    }

    /// Each guard above fires on a copy of the bundled data broken the way QA found it elsewhere: a guard that can't fail guards nothing.
    func testGuardsCatchABrokenCopy() async throws {
        let raw = try Data(contentsOf: Bundle.main.url(forResource: "places", withExtension: "json")!)
        var file = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        var places = try XCTUnwrap(file["places"] as? [[String: Any]])
        let idx = places.indices.filter { places[$0]["v"] == nil }.prefix(6).map { $0 }
        places[idx[2]]["n"] = "Sapphire Gentlemen's Club"
        places[idx[3]]["n"] = "Kitchen the"
        places[idx[4]]["n"] = "SILVER STATE HOSPITALITY GROUP LLC"
        places[idx[5]]["n"] = "Tipsy Nails & Spa"
        file["places"] = places
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("places-broken.json")
        try JSONSerialization.data(withJSONObject: file).write(to: url)
        let m = AppModel(defaults: UserDefaults(suiteName: "broken-\(UUID().uuidString)")!)
        await m.load(from: url)
        XCTAssertTrue(m.isLoaded, m.loadError ?? "")
        let id = idx.map { places[$0]["id"] as? String }
        func caught(_ found: [String], _ i: Int, _ what: String) {
            XCTAssertTrue(found.contains { $0.contains("[\(id[i] ?? "?")]") }, "the guard missed \(what)")
        }
        let links = [(name: "A", id: "x1", url: "https://www.yelp.com/biz/some-place"), (name: "B", id: "x2", url: "https://www.reviewjournal.com/entertainment/food/article.html"),
                     (name: "C", id: "x3", url: "https://smart.com/menu")]
        XCTAssertEqual(DataGuards.badWebsites(links).count, 2, "the guard catches a Yelp page and a news story, and not smart.com")
        XCTAssertEqual(DataGuards.adultWebsites(links + [(name: "D", id: "x4", url: "https://www.treasureslasvegas.com")]).map { String($0.prefix(6)) }, ["D [x4]"],
                       "the guard catches a club's own site under a plain name, and not the others")
        let messy = [(name: "E", id: "x5", url: "https://hammeredharrys.com/locations/las-vegas-fremont-s ."), (name: "F", id: "x6", url: "https:/example.com/menu"),
                     (name: "G", id: "x7", url: "https://example.com/menu,")]
        let fine = [(name: "H", id: "x8", url: "www.example.com/menu"), (name: "I", id: "x9", url: "https://locations.example.com/nv/las-vegas/4655-w.-charleston-blvd."),
                    (name: "J", id: "x10", url: "https://www.example.com/locations/nv/las-vegas/3265-s-rainbow-blvd-(desert-&-rainbow)")]
        XCTAssertEqual(DataGuards.malformedWebsites(links + messy + fine).count, 3,
                       "the guard catches a space, a broken scheme and trailing junk, and not a bare host or a store slug ending in \".\" or \")\"")
        caught(DataGuards.adultVenues(m.places), 2, "a gentlemen's club")
        caught(DataGuards.badNames(m.places), 3, "\u{201C}Kitchen the\u{201D}")
        caught(DataGuards.legalNames(m.places), 4, "a license holder's entity name")
        caught(DataGuards.nonRestaurants(m.places), 5, "a nail salon shown as a restaurant")
    }
}

/// The App Store build ships no Google-derived number, key or flag (Oregon and South Carolina once shipped google21_open in the
/// calibration). Every key of every bundled JSON is checked, and the check is proved on a broken copy.
final class NoGoogleDataTests: XCTestCase {
    static let googleKey = #"(?i)google|gmap|g21|in21|closed21|rating|review|stars|price_level|price_est|gprice"#

    static func keys(_ x: Any, _ path: String = "", into out: inout [String]) {
        if let d = x as? [String: Any] {
            for (k, v) in d {
                if k.range(of: googleKey, options: .regularExpression) != nil { out.append(path + "/" + k) }
                keys(v, path + "/" + k, into: &out)
            }
        } else if let a = x as? [Any] {
            for v in a { keys(v, path + "[]", into: &out) }
        }
    }

    func testNoGoogleKeyInBundledData() throws {
        let files = TrackingParams.bundledJSON()
        XCTAssertFalse(files.isEmpty, "no bundled JSON found")
        var hits: [String] = []
        for url in files {
            let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            var found: [String] = []
            Self.keys(obj, into: &found)
            hits += Set(found).map { "\(url.lastPathComponent): \($0)" }
        }
        XCTAssertEqual(hits.sorted(), [], "Google-derived keys in the app's bundled data")
    }

    func testGoogleGuardCatchesABrokenCopy() throws {
        let broken: [String: Any] = ["calibration": ["Clark County (SNHD outlets)": ["google21_open": 0.8]], "places": [["id": "x", "n": "A", "rating": 4.5]]]
        var found: [String] = []
        Self.keys(broken, into: &found)
        XCTAssertEqual(Set(found), ["/calibration/Clark County (SNHD outlets)/google21_open", "/places[]/rating"])
    }
}

/// Checks on the bundled data, written as functions so testGuardsCatchABrokenCopy can prove each one fires.
enum DataGuards {
    /// directories, Google and news sites: matched on the link's host, so "smart.com" isn't "rt.com"
    static let badHosts = #"^https?://([^/?#]*\.)?(yelp\.com|business\.site|google\.com|groupon\.com|yellowpages\.com|tripadvisor\.com|reviewjournal\.com|lasvegassun\.com|rgj\.com|ktnv\.com|news3lv\.com|8newsnow\.com|fox5vegas\.com|kolotv\.com|ktvn\.com|lasvegasweekly\.com|travelnevada\.com|visitlasvegas\.com|eater\.com|rt\.com)([:/?#]|$)"#

    static func badWebsites(_ links: [(name: String, id: String, url: String)]) -> [String] {
        links.compactMap { l in
            guard l.url.range(of: badHosts, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
            return "\(l.name) [\(l.id)]: \(l.url)"
        }
    }

    /// every website link in the bundled region detail files, with its place's name
    /// every website in the bundled detail files: as the app opens it, or (raw) exactly as the data writes it
    static func bundledLinks(_ places: [Place], raw: Bool = false) throws -> [(name: String, id: String, url: String)] {
        let names = Dictionary(places.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        var out: [(name: String, id: String, url: String)] = []
        for region in Set(places.compactMap(\.region)) {
            guard let url = Bundle.main.url(forResource: "detail-" + AppModel.regionSlug(region), withExtension: "json") else { continue }
            for (id, d) in try JSONDecoder().decode([String: PlaceDetail].self, from: Data(contentsOf: url)) {
                if let w = raw ? d.w : d.website?.absoluteString { out.append((names[id] ?? "?", id, w)) }
            }
        }
        return out
    }

    static let adultNames = #"\bnude\b|adult book ?store|adult superstore|gentlem[ae]n['’]?s club|strip club|exotic dancer|\bmen['’]?s club|rick['’]?s cabaret|baby dolls|spearmint rhino|sapphire gentlem|crazy horse (?:iii|3)|hustler club|little darlings|girl collection|bikini bar|showgirls|centerfolds|treasures? gentlem|treasures nightclub|foxy girls|peppermint hippo|las toxicas|crazy horse (?:bar|paris)"#
    /// club sites a plainly named listing can carry ("Treasures Nightclub" -> treasureslasvegas.com; 2026-10-28 QA NV-1)
    static let adultSites = #"treasureslasvegas|crazyhorse3|crazy-horse-show|spearmintrhino|sapphirelasvegas|peppermint-?hippo|hustlerclub|scoreslv|gentlemensclub|stripclub"#

    /// one web address: http(s) (a bare "www.x.com/menu" counts: the app adds https://), a dotted host, no space or control character,
    /// nothing stray at the end (a store page's slug may end in "." or ")"); pipeline/nevada.py's one_url
    static func malformedWebsites(_ links: [(name: String, id: String, url: String)]) -> [String] {
        links.filter { l in
            guard l.url.range(of: #"[\s<>"{}|\\^`]|[,;'"]$"#, options: .regularExpression) == nil,
                  let u = URL(string: l.url.contains("://") ? l.url : "https://" + l.url), let scheme = u.scheme?.lowercased(),
                  ["http", "https"].contains(scheme), let host = u.host, host.contains("."), !host.hasSuffix(".") else { return true }
            return false
        }.map { "\($0.name) [\($0.id)]: \($0.url)" }
    }

    static func adultWebsites(_ links: [(name: String, id: String, url: String)]) -> [String] {
        links.filter { $0.url.range(of: adultSites, options: [.regularExpression, .caseInsensitive]) != nil }.map { "\($0.name) [\($0.id)]: \($0.url)" }
    }

    /// every permit or license number in the bundled region detail files, by place id
    static func bundledLicenses(_ places: [Place]) throws -> [String: [String]] {
        var out: [String: [String]] = [:]
        for region in Set(places.compactMap(\.region)) {
            guard let url = Bundle.main.url(forResource: "detail-" + AppModel.regionSlug(region), withExtension: "json") else { continue }
            for (id, d) in try JSONDecoder().decode([String: PlaceDetail].self, from: Data(contentsOf: url)) where !d.licenses.isEmpty {
                out[id] = d.licenses.compactMap(\.id)
            }
        }
        return out
    }

    static func adultVenues(_ places: [Place]) -> [String] {
        places.filter { $0.name.range(of: adultNames, options: [.regularExpression, .caseInsensitive]) != nil }.map { "\($0.name) [\($0.id)]" }
    }

    /// a name cut off after "the" or "of" ("Kitchen the", "Wines of") or nothing but "The", among the places shown by default
    static func badNames(_ places: [Place]) -> [String] {
        places.filter { p in
            let n = p.name.trimmingCharacters(in: .whitespaces).lowercased()
            return !p.isVenue && (n.hasSuffix(" the") || n.hasSuffix(" of") || n == "the")
        }.map { "\($0.name) [\($0.id)]" }
    }

    /// a license holder (owner) is never shown; a business name that's still a legal entity shouldn't be either
    static let legalSuffix = #"\b(llc|l\.l\.c|inc|corp|corporation)\.?$"#

    static func legalNames(_ places: [Place]) -> [String] {
        places.filter { !$0.isVenue && $0.name.range(of: legalSuffix, options: [.regularExpression, .caseInsensitive]) != nil }
            .map { "\($0.name) [\($0.id)]" }
    }

    /// businesses that aren't places to eat, among the places shown by default
    static let nonRestaurantNames = #"\bnails?\b|assisted living|gun (?:club|range|shop|store)|shooting range|firearms|petroleum|\bauto (?:repair|parts)\b"#

    static func nonRestaurants(_ places: [Place]) -> [String] {
        places.filter { !$0.isVenue && $0.name.range(of: nonRestaurantNames, options: [.regularExpression, .caseInsensitive]) != nil }
            .map { "\($0.name) [\($0.id)]" }
    }
}

/// pipeline/website_blocklist.json (hacked, taken-over, expired or another business's sites, confirmed by hand in the link sweeps):
/// no link on it may ship in any field of any JSON file the app bundles. The 2026-10-19 QA found the export had only filtered the
/// website field, or nothing, so hijacked links were still in the bundle. Read from the repo, so a new entry needs no code change.
final class LinkBlocklistTests: XCTestCase {
    func testNoBlocklistedLinkInBundledData() throws {
        let entries = try LinkBlocklist.entries()
        XCTAssertFalse(entries.isEmpty, "the blocklist is missing or empty")
        let files = LinkBlocklist.bundledJSON()
        XCTAssertFalse(files.isEmpty, "no bundled JSON found")
        var hits: [String] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            hits += LinkBlocklist.hits(in: text, entries).map { "\(url.lastPathComponent): \($0)" }
        }
        XCTAssertEqual(hits, [], "blocklisted links in the app's bundled data")
    }

    /// The guard fires on a copy of the bundled data broken three ways: a blocklisted domain, its subdomain, and a "url" entry.
    func testBlocklistGuardCatchesABrokenCopy() throws {
        let entries = try LinkBlocklist.entries()
        let file = try XCTUnwrap(LinkBlocklist.bundledJSON().max { (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 < (try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 })
        let text = try String(contentsOf: file, encoding: .utf8)
        let domain = try XCTUnwrap(entries.first { ($0["match"] as? String ?? "domain") == "domain" }?["domain"] as? String)
        let fake: [[String: Any]] = entries + [["match": "url", "url": "https://example.org/hacked-page"]]
        let before = LinkBlocklist.hits(in: text, fake).count
        let broken = text + "{\"w\":\"https://www.\(domain)/menu\"}{\"src\":\"http://shop.\(domain)/\"}{\"w\":\"https://example.org/hacked-page/\"}"
        XCTAssertEqual(LinkBlocklist.hits(in: broken, fake).count, before + 3, "a domain, a subdomain and a url entry are all caught")
        XCTAssertEqual(LinkBlocklist.hits(in: "{\"w\":\"https://not\(domain)/\"}", entries), [], "a host that only ends with the domain's letters isn't it")
    }
}

enum LinkBlocklist {
    static func entries() throws -> [[String: Any]] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("pipeline/website_blocklist.json")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
    }

    /// every .json file in the app bundle, subfolders included
    static func bundledJSON() -> [URL] {
        let root = Bundle.main.bundleURL
        let all = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return all.filter { $0.pathExtension == "json" && !$0.path.contains("/PlugIns/") }
    }

    private static func host(_ u: URLComponents) -> String {
        var h = (u.host ?? "").lowercased()
        if h.hasSuffix(".") { h.removeLast() }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    private static func trimmedPath(_ p: String) -> String { p.hasSuffix("/") ? String(p.dropLast()) : p }

    /// the links in a JSON text that an entry covers: a "domain" entry its domain and subdomains, a "url" entry that page only
    static func hits(in text: String, _ entries: [[String: Any]]) -> [String] {
        let t = text.replacingOccurrences(of: "\\/", with: "/")
        let rx = try! NSRegularExpression(pattern: #"https?://[^"\s\\]+"#, options: [.caseInsensitive])
        return rx.matches(in: t, range: NSRange(t.startIndex..., in: t)).compactMap { m -> String? in
            let s = String(t[Range(m.range, in: t)!])
            guard let u = URLComponents(string: s) else { return nil }
            let h = host(u)
            for e in entries {
                if (e["match"] as? String ?? "domain") == "url" {
                    guard let v = URLComponents(string: e["url"] as? String ?? "") else { continue }
                    if !h.isEmpty && h == host(v) && trimmedPath(u.path) == trimmedPath(v.path) { return s }
                } else {
                    var d = (e["domain"] as? String ?? "").lowercased()
                    if let r = d.range(of: "://") { d = String(d[r.upperBound...]) }
                    d = String(d.split(separator: "/").first ?? "")
                    if d.hasPrefix("www.") { d = String(d.dropFirst(4)) }
                    if !d.isEmpty && (h == d || h.hasSuffix("." + d)) { return s }
                }
            }
            return nil
        }
    }
}

/// QA 2026-10-19, P1 3a: the support address is nick@eatsranked.com (Nick, 2026-10-12). The old Gmail address must not come back
/// anywhere in the app's source or bundled files.
final class SupportEmailTests: XCTestCase {
    func testSupportEmailIsEatsRanked() {
        XCTAssertEqual(Links.supportEmail, "nick@eatsranked.com")
    }

    func testNoGmailInAppSource() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("NevadaEats")
        XCTAssertGreaterThan(SupportEmailScan.textFiles(under: root).count, 5, "the app's source folder wasn't found")
        XCTAssertEqual(SupportEmailScan.hits(under: root), [], "the app's source still has a Gmail address")
    }

    /// The guard fires on a broken copy: a folder with one planted Gmail address.
    func testGmailGuardCatchesABrokenCopy() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("App"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "static let supportEmail = \"someone@GMAIL.com\"\n".write(to: dir.appendingPathComponent("App/Links.swift"), atomically: true, encoding: .utf8)
        try "{\"ok\": \"nick@eatsranked.com\"}".write(to: dir.appendingPathComponent("App/data.json"), atomically: true, encoding: .utf8)
        XCTAssertEqual(SupportEmailScan.hits(under: dir), ["App/Links.swift"])
    }
}

enum SupportEmailScan {
    static let textExtensions: Set<String> = ["swift", "plist", "json", "strings", "xcstrings", "xcprivacy", "md", "txt", "html", "entitlements"]

    static func textFiles(under root: URL) -> [URL] {
        let all = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return all.filter { textExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// paths (relative to root) of text files that mention gmail.com, in any case
    static func hits(under root: URL) -> [String] {
        let base = root.resolvingSymlinksInPath().path + "/"
        return textFiles(under: root).compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  text.range(of: "gmail.com", options: .caseInsensitive) != nil else { return nil }
            return url.resolvingSymlinksInPath().path.replacingOccurrences(of: base, with: "")
        }.sorted()
    }
}

/// QA 2026-10-19, P1 #13: outbound links ship without tracking tags (ref=google, referrer=google_food_ordering, cn_channel, utm_* …).
/// pipeline/tracking_params.py strips them in the export; these are the same rules.
final class TrackingParamTests: XCTestCase {
    func testNoTrackingParametersInBundledLinks() throws {
        let files = TrackingParams.bundledJSON()
        XCTAssertFalse(files.isEmpty, "no bundled JSON found")
        var hits: [String] = []
        for url in files {
            let text = try String(contentsOf: url, encoding: .utf8)
            hits += TrackingParams.tracked(in: text).map { "\(url.lastPathComponent): \($0)" }
        }
        XCTAssertEqual(hits, [], "links with tracking parameters in the app's bundled data")
    }

    /// The guard fires on a broken copy (four kinds of tracking tag, one in escaped JSON; then tags after "#", in the path, without a
    /// scheme and Klaviyo's _kx) and leaves a store's own parameters, anchors and routes alone.
    func testTrackingGuardCatchesABrokenCopy() {
        let broken = #"[{"w":"https:\/\/places.example.com\/menu?ref=google"},{"w":"https://a.example/?utm_source=gmb&store=4"},"#
            + #"{"w":"https://b.example/x?referrer=google_food_ordering"},{"w":"https://c.example/order/1?cn_channel=cn_google"}]"#
        XCTAssertEqual(TrackingParams.tracked(in: broken).count, 4)
        // QA 2026-10-28 (P1 #4): after "#", written into the path, without a scheme, and Klaviyo's _kx
        let hidden = #"[{"w":"https://locations.example.com/us/nv/las-vegas/#utm_source=rest_of_network&utm_medium=Yext"},"#
            + #"{"w":"https://www.example.com/locations/alpharetta/utm_source=Facebook&utm_medium=BusinessListing"},"#
            + #"{"w":"instagram.com/someplace?igshid=MzRlODBiNWFlZA=="},{"w":"https://shop.example.com/menu?_kx=abc123.XYZ&size=2"}]"#
        XCTAssertEqual(TrackingParams.tracked(in: hidden).count, 4)
        let clean = #"[{"w":"https://order.example.com/menu?restaurantId=51&location=7"},{"w":"https://shop.example.com/?cid=12&ref=gs"},"#
            + #"{"w":"https://a.example.com/#menu"},{"w":"https://b.example.com/#/order?table=4"},{"w":"instagram.com/someplace"}]"#
        XCTAssertEqual(TrackingParams.tracked(in: clean), [])
    }
}

enum TrackingParams {
    /// tracking by name, whatever the value
    static let keys = try! NSRegularExpression(pattern: #"^(?:utm[_-].*|gclid|gbraid|wbraid|dclid|fbclid|msclkid|mc_cid|mc_eid|_ga|_gl|_kx|igsh|"#
        + #"igshid|mibextid|srsltid|cn_channel|y_source|rwg_token|olonwp|ost_redirect_attribution|cmpid|yext_?.*)$"#, options: [.caseInsensitive])
    /// tracking only with these values
    static let values: [String: String] = ["ref": #"^(?:google|gmb|gbp|yext|bookmarks)\b"#, "referrer": "^google",
                                           "source": #"^(?:google|gmb|gbp|yext)\b"#, "cid": "^RF:YXT", "cmp": "^OKC-"]

    /// every .json file in the app bundle, subfolders included
    static func bundledJSON() -> [URL] {
        let all = FileManager.default.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return all.filter { $0.pathExtension == "json" && !$0.path.contains("/PlugIns/") }
    }

    static func isTracking(_ key: String, _ value: String) -> Bool {
        let k = key.trimmingCharacters(in: .whitespaces)
        if keys.firstMatch(in: k, range: NSRange(k.startIndex..., in: k)) != nil { return true }
        guard let pattern = values[k.lowercased()] else { return false }
        return value.trimmingCharacters(in: .whitespaces).range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// links in a JSON text that still carry a tracking tag: in the query, after "#" (a route's own query, or "#utm_source=…"), or
    /// written into the path ("…/alpharetta/utm_source=Facebook&utm_medium=BusinessListing"), with or without a scheme
    /// ("instagram.com/x?igshid=…"); pipeline/tracking_params.py's rules since QA 2026-10-28 (P1 #4)
    static func tracked(in text: String) -> [String] {
        let t = text.replacingOccurrences(of: "\\/", with: "/").replacingOccurrences(of: "&amp;", with: "&")
        let rx = try! NSRegularExpression(pattern: #"https?://[^\s"'<>\\]+|(?<![\w/.:@-])(?:[a-z0-9-]+\.)+[a-z]{2,}/[^\s"'<>\\]*"#,
                                          options: [.caseInsensitive])
        return rx.matches(in: t, range: NSRange(t.startIndex..., in: t)).compactMap { m -> String? in
            let s = String(t[Range(m.range, in: t)!])
            return isTracked(s) ? s : nil
        }
    }

    static func isTracked(_ link: String) -> Bool {
        var rest = Substring(link)
        var fragment: Substring = ""
        if let h = rest.firstIndex(of: "#") { fragment = rest[rest.index(after: h)...]; rest = rest[..<h] }
        var query: Substring = ""
        if let q = rest.firstIndex(of: "?") { query = rest[rest.index(after: q)...]; rest = rest[..<q] }
        if hasTracking(query) { return true }
        if fragment.contains("=") {
            let tail = fragment.lastIndex(of: "?").map { fragment[fragment.index(after: $0)...] } ?? fragment
            if hasTracking(tail) { return true }
        }
        let afterScheme = rest.range(of: "://").map { rest[$0.upperBound...] } ?? rest
        let path = afterScheme.firstIndex(of: "/").map { afterScheme[$0...] } ?? ""
        return path.split(separator: "/").contains { $0.contains("=") && hasTracking($0) }
    }

    /// "k=v&k2=v2" holds a tracking pair
    static func hasTracking(_ params: Substring) -> Bool {
        for part in params.split(separator: "&") {
            let kv = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let k = String(kv[0]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(kv[0])
            let v = kv.count > 1 ? (String(kv[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(kv[1])) : ""
            if isTracking(k, v) { return true }
        }
        return false
    }
}
