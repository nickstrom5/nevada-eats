import SwiftUI
import MapKit

struct PlaceDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(LocationService.self) private var location
    let place: Place

    @State private var mapItem: MKMapItem?
    @State private var lookingUp = false
    @State private var notOnAppleMaps = false
    @State private var appleMapsFailed = false
    /// SNHD's inspection history, permits and licenses, phone and website, from the place's region file (read when the place opens)
    @State private var detail: PlaceDetail?
    @State private var detailLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                actions
                if let c = place.coordinate { mapSnippet(c) }
                if place.handChecked && (place.note != nil || place.dishes != nil || place.founded != nil || place.seasonal != nil) { checked }
                if place.hasHonors { honors }
                records
                inspections
                listing
            }
            .padding(16)
        }
        .background(Theme.surface)
        .inlineTitle(place.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { model.toggleSaved(place) } label: {
                    Label(model.isSaved(place) ? "Saved" : "Save", systemImage: model.isSaved(place) ? "heart.fill" : "heart")
                }
                .accessibilityIdentifier("saveHeart")   // the Saved tab is also a "Saved" button
                ShareLink(item: Links.share(place), subject: Text(place.name), message: Text(Links.shareMessage(place))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .task(id: place.id) {
            detailLoaded = false
            detail = await model.detail(for: place)
            detailLoaded = true
        }
        .mapItemDetailSheet(item: $mapItem)
        .alert("Not on Apple Maps", isPresented: $notOnAppleMaps) {
            Button("Open Apple Maps anyway") { AppleMaps.openInMaps(place) }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple Maps doesn't have a listing for \(place.name) at this spot, so there are no ratings or hours to show here.")
        }
        .alert("Couldn't reach Apple Maps", isPresented: $appleMapsFailed) {
            Button("Try again") { lookUp() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }

    /// Apple's place card for this place; "not on Apple Maps" only when Apple answered and had no listing here.
    private func lookUp() {
        lookingUp = true
        Task {
            let result = await AppleMaps.findItem(for: place)
            lookingUp = false
            switch result {
            case .found(let item): mapItem = item
            case .notListed: notOnAppleMaps = true
            case .failed: appleMapsFailed = true
            }
        }
    }

    // MARK: sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            // "HENDERSON · CLARK COUNTY" (the data's county names already end in "County"; Carson City is its own)
            Text((place.city ?? "Nevada").uppercased() + (place.county.map { " · " + $0.uppercased() } ?? ""))
                .monoFont(12).tracking(0.4).foregroundStyle(Theme.green2)
            Text(place.name.uppercased())
                .displayFont(38).foregroundStyle(Theme.green)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text([place.fullAddress, place.cuisine].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(Theme.ink2)
                .textSelection(.enabled)
            if let here = model.screenshotLocation ?? location.location, let l = place.location {
                Text("\(here.milesText(to: l)) away").font(.subheadline).foregroundStyle(Theme.muted)
            }
            PlaceChips(place: place)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button { lookUp() } label: {
                HStack {
                    if lookingUp { ProgressView().tint(.white) } else { Image(systemName: "star.bubble") }
                    Text("Ratings, hours & photos").fontWeight(.semibold)
                    Spacer()
                    Text("Apple Maps").font(.caption).foregroundStyle(Theme.goldSoft)
                }
                .padding(14)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.green))
            }
            .disabled(place.coordinate == nil || lookingUp)
            .accessibilityHint("Opens the Apple Maps place card with current ratings and hours")

            HStack(spacing: 10) {
                actionButton("Directions", "arrow.triangle.turn.up.right.diamond") { AppleMaps.openInMaps(place, directions: true) }
                if let phone = detail?.ph, let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                    actionButton("Call", "phone") { UIApplication.shared.open(url) }
                }
                if let web = detail?.website {
                    actionButton("Website", "safari") { UIApplication.shared.open(web) }
                }
            }
        }
    }

    private func actionButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(Theme.green)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.rule2))
        }
    }

    private func mapSnippet(_ c: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: c, latitudinalMeters: 900, longitudinalMeters: 900)), interactionModes: []) {
            Marker(place.name, systemImage: place.tags.contains(.steakhouses) ? "flame.fill" : "fork.knife", coordinate: c).tint(Theme.green)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { AppleMaps.openInMaps(place) }
        .accessibilityLabel("Map of \(place.name). Opens Apple Maps.")
        .accessibilityAddTraits(.isButton)
    }

    private var checked: some View {
        section("Hand-checked") {
            VStack(alignment: .leading, spacing: 8) {
                if let note = place.note { Text(note).font(.subheadline).foregroundStyle(Theme.ink2) }
                if let d = place.dishes { fact("On the menu", d.components(separatedBy: "; ").joined(separator: ", ")) }
                if let f = place.founded {
                    fact("Open here since", "\(f)")
                    // the note explains the year; without a year it only repeated the description above
                    if let fn = place.foundedNote { Text(fn).font(.caption).foregroundStyle(Theme.ink2) }
                }
                if let sea = place.seasonal { fact("Season", sea) }
                Text("Checked by hand against a 2025 or 2026 source: the MICHELIN Guide, the James Beard Foundation, the place's own site, a 2026 health district inspection, dated local press or a current tourism listing. Menus, hours and casino outlets change often, so check before you go.")
                    .font(.caption).foregroundStyle(Theme.ink2)
            }
        }
    }

    private var honors: some View {
        section("Honors") {
            VStack(alignment: .leading, spacing: 8) {
                if let m = place.michelin.label {
                    Label(m + " · MICHELIN Guide American Southwest", systemImage: "rosette").font(.subheadline).foregroundStyle(Theme.ink)
                }
                ForEach(lines(place.jamesBeard, prefix: "James Beard: "), id: \.self) { l in
                    Label(l, systemImage: "rosette").font(.subheadline).foregroundStyle(Theme.ink)
                }
                Text("Honors are facts, not ratings. MICHELIN and the MICHELIN Guide are trademarks of Michelin; James Beard Foundation and James Beard Award are trademarks of the James Beard Foundation.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    /// The Southern Nevada Health District publishes every inspection in Clark County: its latest grade card (A, B, C, or X for a
    /// closure) with the demerits and date, the history, the items cited and the place's other public permits. Everywhere else the
    /// section says who inspects and that no results are published.
    private var inspections: some View {
        section("Health inspections") {
            VStack(alignment: .leading, spacing: 10) {
                if let ins = place.inspection {
                    HStack(alignment: .center, spacing: 12) {
                        GradeCard(grade: model.grade(ins.grade))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ins.isClosure ? "Closed by the health district" : "\(model.gradeLabel(ins.grade)) · \(ins.demeritsText)")
                                .font(.headline).foregroundStyle(Theme.ink)
                            Text("Latest graded inspection, \(DayFormat.text(ins.date) ?? ins.date)").font(.subheadline).foregroundStyle(Theme.ink2)
                            Text("Official · Southern Nevada Health District").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    if let d = detail?.inspection {
                        if !d.items.isEmpty {
                            Text("Items cited on that inspection").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            ForEach(Array(d.items.enumerated()), id: \.offset) { _, it in
                                Text("• " + [it.text ?? it.code ?? "Item", it.demerits.flatMap { $0 > 0 ? "(\($0) demerit\($0 == 1 ? "" : "s"))" : nil }]
                                        .compactMap { $0 }.joined(separator: " "))
                                    .font(.caption).foregroundStyle(Theme.ink2)
                            }
                            Text("SNHD lists each cited item by the standard it checks: cited means it wasn't met that day.")
                                .font(.caption2).foregroundStyle(Theme.muted)
                        } else {
                            Text("No items were cited on that inspection.").font(.caption).foregroundStyle(Theme.ink2)
                        }
                        if d.visits.count > 1 {
                            Text("Earlier inspections").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            ForEach(Array(d.visits.dropFirst().enumerated()), id: \.offset) { _, v in
                                kv((DayFormat.text(v.date) ?? v.date) + " · " + model.inspectionType(v.type).lowercased(),
                                   model.gradeLabel(v.grade) + (v.demerits.map { " · \($0)" } ?? ""))
                            }
                        }
                        if !d.others.isEmpty {
                            Text("Its other permits").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            ForEach(d.others, id: \.self) { o in
                                kv(o.label + " · " + (DayFormat.text(o.date) ?? o.date), model.gradeLabel(o.grade) + (o.demerits.map { " · \($0)" } ?? ""))
                            }
                        }
                    } else if !detailLoaded {
                        ProgressView().frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("The grade is the card the Southern Nevada Health District issued, as published in its restaurant file (inspections through \(DayFormat.text(model.inspectionsThrough) ?? model.inspectionsThrough)): A, B or C, or X when it closed the place. Demerits are shown as published; we never work a grade out from them. One inspection is a snapshot of one day, and a downgraded place is re-inspected and can earn its A back. An independent app: the health district doesn't run it.")
                        .font(.caption).foregroundStyle(Theme.muted)
                    Link(destination: Links.snhdSearch) {
                        Label("The health district's own restaurant search", systemImage: "arrow.up.right.square").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.green)
                } else {
                    Text(AppModel.inspector(county: place.county)).font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var records: some View {
        section("Official records") {
            VStack(alignment: .leading, spacing: 8) {
                if let ls = detail?.licenses, !ls.isEmpty {
                    ForEach(ls, id: \.self) { l in
                        kv(l.source, l.id.map(Self.unbroken) ?? "On the list")
                    }
                } else if place.county == "Clark County" {
                    kv("SNHD health permit", detailLoaded ? "— (none matched)" : "…")
                }
                kv("Serves alcohol", place.servesBeer ? "Yes · on-premises liquor license" : "—")
                Text(recordsNote).font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    private var listing: some View {
        section("How we know it's here") {
            VStack(alignment: .leading, spacing: 8) {
                kv("Listed as", place.tier.label)
                if place.tier == .licensed { kv("Official record", detail?.licenses.first?.source ?? "An official permit or license") }
                if place.chainCount >= 2 { kv("Locations in Nevada", place.chainCount.formatted()) }
                Text(listingNote).font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    /// "04092010037", never broken across lines
    private static func unbroken(_ id: String) -> String { id.replacingOccurrences(of: "-", with: "\u{2011}") }

    /// Where the records come from; a missing record is unknown, not "no permit".
    private var recordsNote: String {
        let permits = DayFormat.text(model.permitsUpdated) ?? model.permitsUpdated
        return "The Southern Nevada Health District publishes every active Clark County food permit (read \(permits)); Clark County, Las Vegas and Henderson publish their business licenses, and Reno's list stopped updating on Oct 1, 2025. Other counties and cities publish none. A place with nothing matched may hold a permit under another name. \"Serves alcohol\" comes only from the place's own on-premises liquor license; a resort outlet usually sells under the resort's license, so \"—\" means unknown, never \"no\"."
    }

    private var listingNote: String {
        let checked = place.handChecked
        if place.source == "research" {
            return "On our hand-checked list (checked against a 2025 or 2026 source). The open map data didn't list it as a place to eat, so it's placed from its own map listing or street address."
        }
        switch place.tier {
        case .licensed:
            return place.source == "official"
                ? "From the Southern Nevada Health District's permit list. The open map data didn't have it, so its location is the district's own point for the permit."
                : "Matched to an active health permit or business license on an official list."
        case .confirmed, .listing:
            let base = place.tier == .confirmed
                ? "A high-confidence listing in Overture's open map data."
                : "A single listing in Overture's open map data, so it may be closed or misfiled."
            return base + (checked ? " It's also on our hand-checked list, checked against a 2025 or 2026 source." : "")
        }
    }

    // MARK: helpers

    private func lines(_ s: String?, prefix: String) -> [String] {
        (s ?? "").components(separatedBy: "; ").filter { !$0.isEmpty }.map { prefix + $0 }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(Theme.ink2)
            Divider()
            content()
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(value).font(.subheadline).foregroundStyle(Theme.ink2)
        }
    }

    @ViewBuilder
    private func kv(_ k: String, _ v: String?) -> some View {
        if let v {
            HStack(alignment: .firstTextBaseline) {
                Text(k).font(.subheadline).foregroundStyle(Theme.ink2)
                Spacer(minLength: 12)
                Text(v).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.trailing)
            }
        }
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

/// The grade as a plain letter tile: black on white with a hard black frame. Deliberately not a copy of SNHD's posted card, so the app
/// never looks official; X (a closure) reads "Closed" to VoiceOver.
struct GradeCard: View {
    let grade: String
    var body: some View {
        Text(grade)
            .font(.system(size: 34, weight: .heavy, design: .default))
            .foregroundStyle(.black)
            .frame(width: 58, height: 58)
            .background(RoundedRectangle(cornerRadius: 6).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.black, lineWidth: 3))
            .accessibilityLabel(grade == "X" ? "Closed by the health district" : "Grade \(grade)")
    }
}
