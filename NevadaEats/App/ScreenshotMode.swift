import Foundation
import CoreLocation
import UIKit

/// `-screenshot <name>` opens one screen with fixed state for App Store screenshots (scripts/capture-screenshots.sh).
/// Names: home, honors, inspections, chinatown, detail, map, saved, about.
enum ScreenshotMode {
    /// Debug builds only: an App Store build ignores the launch argument, so no one can reach seeded screens or fake locations.
    static var name: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }
    static var isActive: Bool { name != nil }

    @MainActor
    static func apply(to model: AppModel) {
        guard let name, model.isLoaded else { return }
        model.filters = Filters()
        // the Strip at Flamingo Road, so "nearest" lists have distances without a permission prompt
        model.screenshotLocation = CLLocation(latitude: 36.1162, longitude: -115.1745)
        // by name and town, ignoring case, so a rebuild with a slightly different casing still finds the place; the hand-checked one first
        let pick = { (n: String, town: String?) -> Place? in
            let hits = model.places.filter { $0.name.caseInsensitiveCompare(n) == .orderedSame && (town == nil || $0.city == town) }
            return hits.first(where: \.handChecked) ?? hits.first
        }
        for p in [pick("Esther's Kitchen", "Las Vegas"), pick("Lotus of Siam", "Las Vegas"), pick("Peppermill Restaurant and Fireside Lounge", "Las Vegas")]
            .compactMap({ $0 }) where !model.isSaved(p) {
            model.toggleSaved(p)
        }
        let open = { (g: Guide) in model.tab = .guides; model.selectedGuide = g; model.guidesPath = [.guide(g)] }
        switch name {
        case "chinatown":
            // from Spring Mountain Road at Jones Boulevard
            model.screenshotLocation = CLLocation(latitude: 36.1260, longitude: -115.2245)
            open(.chinatown)
        case "buffets": open(.buffets)
        case "plate_lunch":
            // from the west side, where most of the plate-lunch counters are
            model.screenshotLocation = CLLocation(latitude: 36.1460, longitude: -115.2420)
            open(.plateLunch)
        case "basque":
            // downtown Carson City: the Basque tables are up north, Carson Valley to Elko
            model.screenshotLocation = CLLocation(latitude: 39.1638, longitude: -119.7674)
            open(.basque)
        case "honors": open(.honors)
        case "inspections": open(.inspections)
        case "detail":
            // Esther's Kitchen: a Bib Gourmand, with the health district's latest grade card
            open(.honors)
            if let p = pick("Esther's Kitchen", "Las Vegas") ?? model.places.first {
                model.selectedPlace = p; model.guidesPath.append(.place(p))
            }
        case "map": model.tab = .map
        case "saved": model.tab = .saved
        case "about": model.tab = .about
        default: model.tab = .guides; model.selectedGuide = nil
        }
        // iPad shows the place column next to every list, so give each shot a place instead of "Pick a place": a different
        // honored or hand-checked one per shot.
        guard UIDevice.current.userInterfaceIdiom == .pad, model.selectedPlace == nil else { return }
        let place: Place? = switch name {
        case "home": pick("Peppermill Restaurant and Fireside Lounge", "Las Vegas")
        case "chinatown": pick("Partage", "Las Vegas")
        case "buffets": pick("Bacchanal Buffet", "Las Vegas")
        // the Charleston Grinds: its inspection history is all A cards (no B or closure in an App Store image)
        case "plate_lunch": model.places.first { $0.name == "Grinds 2 Da Max" && $0.address?.hasPrefix("6475 ") == true } ?? pick("Grinds 2 Da Max", "Las Vegas")
        case "basque": pick("The Martin Hotel", "Winnemucca")
        case "map": pick("Lotus of Siam", "Las Vegas")
        case "honors": pick("Restaurant de Joël Robuchon", "Las Vegas")
        case "inspections": pick("Bob Taylor's Ranch House", "Las Vegas")
        case "saved": pick("Esther's Kitchen", "Las Vegas")
        case "about": nil
        default: pick("YEN Viet Kitchen", "Las Vegas")
        }
        model.selectedPlace = place
    }
}
