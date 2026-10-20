import SwiftUI
import UIKit

/// Land drawn as a field of dots: no borders, labels or roads, so the routes carry the screen.
enum TripGlobeLand {
    /// Longitude/latitude pairs sampled every 1.6° from Natural Earth's 1:110m land outlines.
    static let dots: [SIMD2<Double>] = {
        struct File: Decodable { let dots: [[Double]] }
        guard let data = NSDataAsset(name: "LandDots")?.data,
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.dots.compactMap { $0.count == 2 ? SIMD2($0[0], $0[1]) : nil }
    }()
}

/// An orthographic globe framed so the destination sits a little below the middle of the hero,
/// with routes arching over the horizon above it.
struct TripGlobeProjection {
    let centerLongitude: Double
    let centerLatitude: Double
    let radius: CGFloat
    let center: CGPoint

    init(destination: CLLocationCoordinate2D, size: CGSize) {
        centerLongitude = destination.longitude - 4
        centerLatitude = max(-60, min(60, destination.latitude - 20))
        radius = size.width * 0.95
        let anchorY = size.height * 0.64
        let p = destination.latitude * .pi / 180, p0 = centerLatitude * .pi / 180
        let l = (destination.longitude - centerLongitude) * .pi / 180
        center = CGPoint(x: size.width / 2 - radius * cos(p) * sin(l),
                         y: anchorY + radius * (cos(p0) * sin(p) - sin(p0) * cos(p) * cos(l)))
    }

    struct Projected { let point: CGPoint; let front: Bool; let depth: Double }

    func project(longitude: Double, latitude: Double, altitude: Double = 0) -> Projected {
        let l = (longitude - centerLongitude) * .pi / 180, p = latitude * .pi / 180, p0 = centerLatitude * .pi / 180
        let r = radius * (1 + altitude)
        let cosc = sin(p0) * sin(p) + cos(p0) * cos(p) * cos(l)
        return Projected(point: CGPoint(x: center.x + r * cos(p) * sin(l),
                                        y: center.y - r * (cos(p0) * sin(p) - sin(p0) * cos(p) * cos(l))),
                         front: cosc > 0, depth: cosc)
    }

    /// Great-circle points lifted into an arch; points behind the globe are marked hidden.
    func arc(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D, steps: Int = 120) -> [(CGPoint, Bool)] {
        func vector(_ c: CLLocationCoordinate2D) -> SIMD3<Double> {
            let l = c.longitude * .pi / 180, p = c.latitude * .pi / 180
            return SIMD3(cos(p) * cos(l), cos(p) * sin(l), sin(p))
        }
        let va = vector(a), vb = vector(b)
        let angle = acos(max(-1, min(1, (va * vb).sum())))
        guard angle > 0.0001 else { return [] }
        return (0...steps).map { step in
            let t = Double(step) / Double(steps)
            let v = va * (sin((1 - t) * angle) / sin(angle)) + vb * (sin(t * angle) / sin(angle))
            let lat = asin(max(-1, min(1, v.z))) * 180 / .pi, lon = atan2(v.y, v.x) * 180 / .pi
            let projected = project(longitude: lon, latitude: lat, altitude: sin(.pi * t) * min(0.3, angle * 0.22))
            let distance = hypot(projected.point.x - center.x, projected.point.y - center.y)
            return (projected.point, projected.front || distance > radius)
        }
    }
}

/// One person on the trip, with their flight each way.
struct TripGlobeTraveler: Identifiable {
    let person: TripParticipant
    let outbound: TripFlight?
    let inbound: TripFlight?
    var id: String { person.id }

    func flight(_ direction: TripDirection) -> TripFlight? { direction == .outbound ? outbound : inbound }
    /// The airport they fly home to or from, whichever leg is known.
    var home: String? { outbound?.origin ?? inbound?.destination }
    var color: Color { WIFPersonPalette.fill(for: person.name) }
    var initials: String {
        let parts = person.name.split(separator: " ")
        if parts.count > 1 { return String(parts.prefix(2).compactMap(\.first)).uppercased() }
        return String(person.name.prefix(person.name.unicodeScalars.first.map { $0.value > 0x2E80 } == true ? 1 : 2)).uppercased()
    }
    var shortName: String { person.name.split(separator: " ").first.map(String.init) ?? person.name }

    static func all(in trip: TripPlan) -> [TripGlobeTraveler] {
        func flight(for person: TripParticipant, _ direction: TripDirection) -> TripFlight? {
            trip.flights.filter { $0.direction == direction && ($0.travelerID == person.id || ($0.travelerID == nil && $0.traveler == person.name)) }
                .min { (direction == .outbound ? $0.arrivalSortDate : $0.departureSortDate) < (direction == .outbound ? $1.arrivalSortDate : $1.departureSortDate) }
        }
        return trip.participants.map { TripGlobeTraveler(person: $0, outbound: flight(for: $0, .outbound), inbound: flight(for: $0, .inbound)) }
    }
}

/// The entrance: each route draws in, a plane flies it, and its traveler lands on the island
/// (or, heading home, leaves it). Everything is a function of the time since the scene started.
struct TripGlobeTimeline {
    static func draw(_ index: Int) -> Double { 0.25 + Double(index) * 0.55 }
    static func fly(_ index: Int) -> Double { draw(index) + 0.55 }
    static func land(_ index: Int) -> Double { fly(index) + 2.3 }
    static func ease(_ t: Double) -> Double { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }
    static func clamp(_ t: Double) -> Double { max(0, min(1, t)) }
    /// A small overshoot so avatars pop in rather than fade.
    static func pop(_ seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        let t = min(1, seconds / 0.45)
        return 1 + 0.18 * sin(t * .pi) * (1 - t) * 3 - (1 - t) * (1 - t) * (1 - t)
    }
}

/// The hero: dotted globe, the destination's emblem, and everyone's routes.
struct TripGlobeHero: View {
    let destination: AirportLocation
    let travelers: [TripGlobeTraveler]
    let direction: TripDirection
    let elapsed: Double
    @Binding var selectedID: String?
    @State private var dotCache = DotCache()

    private final class DotCache {
        var key = ""
        var points: [(CGPoint, Double, Double)] = []
    }

    /// Travelers with a flight in this direction, in the order their planes take off.
    private var flying: [(traveler: TripGlobeTraveler, flight: TripFlight, home: AirportLocation)] {
        travelers.compactMap { traveler in
            guard let flight = traveler.flight(direction),
                  let home = AirportLocation.location(for: direction == .outbound ? flight.origin : flight.destination),
                  home.code != destination.code else { return nil }
            return (traveler, flight, home)
        }
        .sorted { (direction == .outbound ? $0.flight.arrivalSortDate : $0.flight.departureSortDate)
            < (direction == .outbound ? $1.flight.arrivalSortDate : $1.flight.departureSortDate) }
    }

    var body: some View {
        GeometryReader { proxy in
            let projection = TripGlobeProjection(destination: destination.coordinate, size: proxy.size)
            let island = projection.project(longitude: destination.coordinate.longitude, latitude: destination.coordinate.latitude).point
            let routes = flying.enumerated().map { index, item in
                let path = projection.arc(from: item.home.coordinate, to: destination.coordinate)
                return (index: index, item: item, points: direction == .outbound ? path : path.reversed())
            }
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    drawGlobe(context, size: size, projection: projection)
                    for route in routes { drawRoute(context, route: route, size: size) }
                    drawRipples(context, island: island, count: routes.count)
                }
                CityEmblemView(city: destination.city, countryCode: destination.countryCode, size: 92)
                    .shadow(color: WIFTheme.primaryText.opacity(0.18), radius: 10, y: 8)
                    .position(x: island.x, y: island.y - 30 - hop(count: routes.count) * 6)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                crew(routes: routes.map { ($0.index, $0.item.traveler) })
                    .position(x: island.x + 6, y: island.y + 20)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let hit = routes.compactMap { route -> (String, CGFloat)? in
                    guard let point = marker(for: route.points, index: route.index) else { return nil }
                    return (route.item.traveler.id, hypot(point.x - location.x, point.y - location.y))
                }.min { $0.1 < $1.1 }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selectedID = hit.flatMap { $0.1 < 34 ? $0.0 : nil }.flatMap { $0 == selectedID ? nil : $0 }
                }
            }
        }
        .background(RadialGradient(colors: [WIFTheme.freshSurface.opacity(0.55), WIFTheme.canvas], center: .bottom, startRadius: 20, endRadius: 420))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let names = flying.map { "\($0.traveler.shortName) from \($0.home.code)" }.formatted(.list(type: .and))
        return names.isEmpty ? String(localized: "Map of \(destination.city)") : String(localized: "Routes to \(destination.city): \(names)")
    }

    // MARK: Drawing

    private func drawGlobe(_ context: GraphicsContext, size: CGSize, projection: TripGlobeProjection) {
        let body = Path(ellipseIn: CGRect(x: projection.center.x - projection.radius, y: projection.center.y - projection.radius,
                                          width: projection.radius * 2, height: projection.radius * 2))
        context.fill(body, with: .color(WIFTheme.surface.opacity(0.9)))
        context.stroke(body, with: .color(WIFTheme.freshSurface), lineWidth: 1)
        let key = "\(Int(size.width))x\(Int(size.height))-\(destination.code)"
        if dotCache.key != key {
            dotCache.key = key
            dotCache.points = TripGlobeLand.dots.compactMap { dot in
                let p = projection.project(longitude: dot.x, latitude: dot.y)
                guard p.front, p.point.y < size.height + 4 else { return nil }
                return (p.point, p.depth, dot.x)
            }
        }
        // A slow band of light passes across the land.
        let sweep = (elapsed / 9).truncatingRemainder(dividingBy: 1) * 260 - 130 + destination.coordinate.longitude
        for (point, depth, longitude) in dotCache.points {
            let glint = max(0, 1 - abs(longitude - sweep) / 18) * 0.35
            let alpha = min(1, 0.2 + 0.5 * (0.3 + 0.7 * depth) + glint)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 1.1, y: point.y - 1.1, width: 2.2, height: 2.2)),
                         with: .color(WIFTheme.secondaryText.opacity(alpha * 0.85)))
        }
    }

    private func drawRoute(_ context: GraphicsContext, route: (index: Int, item: (traveler: TripGlobeTraveler, flight: TripFlight, home: AirportLocation), points: [(CGPoint, Bool)]), size: CGSize) {
        let points = route.points, last = points.count - 1
        guard last > 0 else { return }
        let lit = selectedID == nil || selectedID == route.item.traveler.id
        let drawn = TripGlobeTimeline.ease(TripGlobeTimeline.clamp((elapsed - TripGlobeTimeline.draw(route.index)) / 0.8))
        let flown = TripGlobeTimeline.ease(TripGlobeTimeline.clamp((elapsed - TripGlobeTimeline.fly(route.index)) / 2.3))
        func stroke(from: Int, to: Int, width: CGFloat, color: Color, dash: [CGFloat] = []) {
            var path = Path(), open = false
            for i in max(0, from)...max(0, min(last, to)) {
                let (point, visible) = points[i]
                if !visible { open = false; continue }
                if open { path.addLine(to: point) } else { path.move(to: point); open = true }
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
        }
        stroke(from: 0, to: Int(Double(last) * drawn), width: 1.4, color: WIFTheme.fresh.opacity(lit ? 0.5 : 0.12), dash: [1.5, 4.5])
        let head = Int(Double(last) * flown)
        if flown > 0 {
            stroke(from: flown < 1 ? head - 34 : 0, to: head, width: flown < 1 ? 2.4 : 1.6,
                   color: WIFTheme.fresh.opacity(lit ? (flown < 1 ? 1 : 0.75) : 0.16))
        }
        // After landing, a short bright glint slides along the route every few seconds.
        if flown >= 1 {
            let phase = ((elapsed - TripGlobeTimeline.land(route.index)) / 7 + Double(route.index) * 0.31).truncatingRemainder(dividingBy: 1) * 1.4
            if phase < 1 {
                let glint = Int(Double(last) * phase)
                stroke(from: glint - 10, to: glint, width: 2.6, color: WIFTheme.sunGlow.opacity(lit ? 0.9 : 0.25))
            }
        }
        if flown > 0, flown < 1, points[head].1 {
            let a = points[max(0, head - 2)].0, b = points[min(last, head + 2)].0
            var plane = context
            plane.opacity = lit ? 1 : 0.35
            plane.translateBy(x: points[head].0.x, y: points[head].0.y)
            plane.rotate(by: .radians(atan2(b.y - a.y, b.x - a.x)))
            let shape = Self.planePath
            plane.stroke(shape, with: .color(WIFTheme.surface), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            plane.fill(shape, with: .color(route.item.traveler.color))
        }
        // Home airport chip with its local time.
        if drawn > 0.05, let point = marker(for: points, index: route.index, homeOnly: true) {
            let time = route.item.flight.status == .unverified ? "" : "  " + (direction == .outbound ? route.item.flight.departureTime : route.item.flight.arrivalTime)
            let text = context.resolve(Text(route.item.home.code + time).font(.system(size: 10, weight: .semibold)).foregroundColor(WIFTheme.primaryText))
            let width = text.measure(in: size).width + 12
            let x = min(size.width - width / 2 - 6, max(width / 2 + 6, point.x))
            var chip = context
            chip.opacity = (lit ? 1 : 0.4) * min(1, drawn * 3)
            chip.fill(Path(roundedRect: CGRect(x: x - width / 2, y: point.y - 8, width: width, height: 16), cornerRadius: 8),
                      with: .color(WIFTheme.surface.opacity(0.94)))
            chip.draw(text, at: CGPoint(x: x, y: point.y))
        }
    }

    private func drawRipples(_ context: GraphicsContext, island: CGPoint, count: Int) {
        for index in 0..<count {
            let since = elapsed - (direction == .outbound ? TripGlobeTimeline.land(index) : TripGlobeTimeline.fly(index))
            guard since > 0, since < 1.1 else { continue }
            let k = since / 1.1
            let rect = CGRect(x: island.x - (20 + 46 * k), y: island.y + 4 - (7 + 15 * k), width: 2 * (20 + 46 * k), height: 2 * (7 + 15 * k))
            context.stroke(Path(ellipseIn: rect), with: .color(WIFTheme.fresh.opacity(0.35 * (1 - k))), lineWidth: 1.5)
        }
    }

    /// Where a route's chip (its home end) or plane sits right now, for drawing and tapping.
    private func marker(for points: [(CGPoint, Bool)], index: Int, homeOnly: Bool = false) -> CGPoint? {
        let last = points.count - 1
        guard last > 0 else { return nil }
        if !homeOnly {
            let flown = TripGlobeTimeline.ease(TripGlobeTimeline.clamp((elapsed - TripGlobeTimeline.fly(index)) / 2.3))
            if flown > 0, flown < 1, points[Int(Double(last) * flown)].1 { return points[Int(Double(last) * flown)].0 }
        }
        let indices = direction == .outbound ? Array(0...last) : Array((0...last).reversed())
        guard let first = indices.first(where: { points[$0].1 }) else { return nil }
        return CGPoint(x: points[first].0.x, y: points[first].0.y - 12)
    }

    private func hop(count: Int) -> CGFloat {
        let times = (0..<count).map { direction == .outbound ? TripGlobeTimeline.land($0) : TripGlobeTimeline.fly($0) }
        return CGFloat(times.map { since -> Double in let s = elapsed - since; return s > 0 && s < 0.3 ? sin(s / 0.3 * .pi) : 0 }.max() ?? 0)
    }

    /// Everyone who has arrived gathers on the island; heading home, they leave it one by one.
    private func crew(routes: [(Int, TripGlobeTraveler)]) -> some View {
        HStack(spacing: -6) {
            ForEach(routes, id: \.1.id) { index, traveler in
                let scale = direction == .outbound
                    ? TripGlobeTimeline.pop(elapsed - TripGlobeTimeline.land(index))
                    : 1 - TripGlobeTimeline.clamp((elapsed - TripGlobeTimeline.fly(index)) / 0.3)
                TripGlobeAvatar(traveler: traveler, size: 22).scaleEffect(max(0, scale))
            }
        }
    }

    static let planePath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 9, y: 0))
        p.addQuadCurve(to: CGPoint(x: 2, y: -1.6), control: CGPoint(x: 7, y: -1.6))
        p.addLines([CGPoint(x: -2, y: -8), CGPoint(x: -4.2, y: -8), CGPoint(x: -2.2, y: -1.6), CGPoint(x: -6.5, y: -1.6),
                    CGPoint(x: -8.5, y: -4.2), CGPoint(x: -10, y: -4.2), CGPoint(x: -9, y: 0), CGPoint(x: -10, y: 4.2),
                    CGPoint(x: -8.5, y: 4.2), CGPoint(x: -6.5, y: 1.6), CGPoint(x: -2.2, y: 1.6), CGPoint(x: -4.2, y: 8),
                    CGPoint(x: -2, y: 8), CGPoint(x: 2, y: 1.6)])
        p.addQuadCurve(to: CGPoint(x: 9, y: 0), control: CGPoint(x: 7, y: 1.6))
        p.closeSubpath()
        return p
    }()
}

struct TripGlobeAvatar: View {
    let traveler: TripGlobeTraveler
    var size: CGFloat = 22
    var pending = false

    var body: some View {
        Circle()
            .fill(pending ? AnyShapeStyle(Color.clear) : AnyShapeStyle(traveler.color.gradient))
            .overlay { if pending { Circle().strokeBorder(WIFTheme.border, lineWidth: 1.5) } }
            .overlay {
                Text(traveler.initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(pending ? WIFTheme.secondaryText : .white)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: size, height: size)
            .overlay { if !pending { Circle().stroke(WIFTheme.surface, lineWidth: 2) } }
            .accessibilityHidden(true)
    }
}

/// The landing day (or departure day) as a line, with everyone placed at their local time.
struct TripGlobeStrip: View {
    let destination: AirportLocation
    let travelers: [TripGlobeTraveler]
    let direction: TripDirection
    let elapsed: Double

    private var timed: [(traveler: TripGlobeTraveler, date: Date, index: Int)] {
        travelers.compactMap { traveler -> (TripGlobeTraveler, Date)? in
            guard let flight = traveler.flight(direction) else { return nil }
            let date = direction == .outbound ? flight.arrivalSortDate : flight.departureSortDate
            return date == .distantFuture ? nil : (traveler, date)
        }
        .sorted { $0.1 < $1.1 }
        .enumerated().map { ($0.element.0, $0.element.1, $0.offset) }
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = destination.timeZone
        return calendar
    }

    var body: some View {
        let items = timed
        if let first = items.first?.date, let last = items.last?.date {
            let startDay = calendar.startOfDay(for: first)
            let multiDay = !calendar.isDate(first, inSameDayAs: last)
            let start = multiDay ? startDay : startDay.addingTimeInterval(6 * 3600)
            let end = multiDay ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last))! : startDay.addingTimeInterval(24 * 3600)
            let span = max(1, end.timeIntervalSince(start))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label(first: first, last: last, multiDay: multiDay))
                    Spacer()
                    Text("\(destination.city) time")
                }
                .font(.system(size: 10.5, weight: .semibold)).tracking(0.6).textCase(.uppercase)
                .foregroundStyle(WIFTheme.secondaryText.opacity(0.8))
                GeometryReader { proxy in
                    let reached = items.filter { elapsed >= landTime($0.index) }.map { $0.date.timeIntervalSince(start) / span }.max() ?? 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(WIFTheme.border.opacity(0.35)).frame(height: 2)
                        Capsule().fill(WIFTheme.fresh).frame(width: proxy.size.width * min(1, max(0, reached)), height: 2)
                            .animation(.easeOut(duration: 0.6), value: reached)
                        ForEach(items, id: \.traveler.id) { item in
                            TripGlobeAvatar(traveler: item.traveler, size: 22)
                                .scaleEffect(max(0, TripGlobeTimeline.pop(elapsed - landTime(item.index))))
                                .position(x: proxy.size.width * min(1, max(0, item.date.timeIntervalSince(start) / span)), y: 14)
                        }
                    }
                    .frame(height: 28)
                }
                .frame(height: 28)
                HStack {
                    if multiDay {
                        Text(local(first, .dateTime.month(.abbreviated).day()))
                        Spacer()
                        Text(local(last, .dateTime.month(.abbreviated).day()))
                    } else {
                        Text("6 am"); Spacer(); Text("noon"); Spacer(); Text("6 pm"); Spacer(); Text("midnight")
                    }
                }
                .font(.system(size: 10)).foregroundStyle(WIFTheme.secondaryText.opacity(0.7))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(items.map { "\($0.traveler.shortName) \(local($0.date, .dateTime.hour().minute()))" }.formatted(.list(type: .and)))
        }
    }

    private func local(_ date: Date, _ style: Date.FormatStyle) -> String {
        var style = style
        style.timeZone = destination.timeZone
        return date.formatted(style)
    }

    private func landTime(_ index: Int) -> Double {
        direction == .outbound ? TripGlobeTimeline.land(index) : TripGlobeTimeline.fly(index)
    }

    private func label(first: Date, last: Date, multiDay: Bool) -> String {
        let day = local(first, .dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let span = multiDay
            ? "\(local(first, .dateTime.month(.abbreviated).day())) – \(local(last, .dateTime.month(.abbreviated).day()))"
            : day
        return direction == .outbound ? String(localized: "Landing · \(span)") : String(localized: "Leaving · \(span)")
    }
}

/// One line per traveler, columns aligned like an arrivals board. Tapping opens both legs.
struct TripGlobeBoardRow: View {
    @ObservedObject var library: TripLibrary
    let trip: TripPlan
    let traveler: TripGlobeTraveler
    let direction: TripDirection
    let isSelf: Bool
    let isSelected: Bool
    let isDimmed: Bool
    let onToggle: () -> Void
    let onAddFlight: () -> Void
    let onEditFlight: (TripFlight) -> Void
    let onDeleteFlight: (TripFlight) -> Void

    private var flight: TripFlight? { traveler.flight(direction) }
    private var other: TripFlight? { traveler.flight(direction == .outbound ? .inbound : .outbound) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let flight {
                Button(action: onToggle) { line(flight: flight) }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(isSelected ? "Details expanded" : "Details collapsed")
                    .accessibilityIdentifier("flightCard-\(flight.id)")
            } else {
                missingLine
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("missingTraveler-\(traveler.id)")
            }
            if isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    leg(String(localized: "Out"), traveler.outbound, from: traveler.outbound?.origin ?? traveler.home, to: trip.destinationAirport, direction: .outbound)
                    leg(String(localized: "Back"), traveler.inbound, from: trip.destinationAirport, to: traveler.inbound?.destination ?? traveler.home, direction: .inbound)
                    if isSelf, trip.cancelledAt == nil, let flight {
                        HStack(spacing: 20) {
                            Button("Edit my flight", systemImage: "pencil") { onEditFlight(flight) }
                                .accessibilityIdentifier("editMyTripFlightButton")
                            Spacer(minLength: 0)
                            Button("Delete", systemImage: "trash", role: .destructive) { onDeleteFlight(flight) }
                                .accessibilityIdentifier("deleteMyTripFlightButton")
                        }
                        .font(.footnote).buttonStyle(.plain).foregroundStyle(WIFTheme.fresh).frame(minHeight: 36)
                    }
                }
                .padding(.leading, 32).padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Divider().overlay(WIFTheme.border.opacity(0.6))
        }
        .opacity(isDimmed ? 0.4 : 1)
    }

    private func line(flight: TripFlight) -> some View {
        HStack(spacing: 8) {
            TripGlobeAvatar(traveler: traveler, size: 22)
            Text(isSelf ? String(localized: "You") : traveler.person.name)
                .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(direction == .outbound ? flight.origin : flight.destination)
                .font(.subheadline.weight(.semibold)).frame(width: 38, alignment: .leading)
            Text(flight.flightNumber)
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(WIFTheme.secondaryText)
                .lineLimit(1).frame(width: 60, alignment: .leading)
            Text(flight.status == .unverified ? "—" : (direction == .outbound ? flight.arrivalTime : flight.departureTime))
                .font(.system(.subheadline, design: .rounded, weight: .semibold)).monospacedDigit()
                .frame(width: 46, alignment: .trailing)
            Text(other.map(dayLabel) ?? "—")
                .font(.caption).foregroundStyle(other == nil ? WIFTheme.caution : WIFTheme.secondaryText)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .foregroundStyle(WIFTheme.primaryText)
    }

    private var missingLine: some View {
        HStack(spacing: 8) {
            TripGlobeAvatar(traveler: traveler, size: 22, pending: true)
            Text(isSelf ? String(localized: "You") : traveler.person.name)
                .font(.subheadline.weight(.semibold)).foregroundStyle(WIFTheme.primaryText).lineLimit(1)
            Text(direction == .outbound ? String(localized: "No flight yet") : String(localized: "No return flight yet"))
                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isSelf, trip.cancelledAt == nil {
                Button("Add flight", action: onAddFlight)
                    .font(.caption.weight(.semibold)).foregroundStyle(WIFTheme.fresh)
                    .frame(minWidth: 44, minHeight: 36)
                    .accessibilityIdentifier("tripNeedsHelpCard")
            } else if direction == .outbound, library.canRemind(traveler.person, in: trip) {
                TripReminderButton(library: library, trip: trip, person: traveler.person)
            }
        }
        .padding(.vertical, 6)
    }

    private func dayLabel(_ flight: TripFlight) -> String {
        flight.calendarDay.label
    }

    @ViewBuilder
    private func leg(_ label: String, _ flight: TripFlight?, from: String?, to: String?, direction legDirection: TripDirection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.6).textCase(.uppercase)
                .foregroundStyle(WIFTheme.secondaryText.opacity(0.8)).frame(width: 34, alignment: .leading)
            if let flight {
                VStack(alignment: .leading, spacing: 2) {
                    (Text(flight.origin).fontWeight(.semibold).foregroundColor(WIFTheme.primaryText)
                     + Text(" \(flight.departureDayLabel.map { "\($0) " } ?? "")\(flight.departureTime)  →  ")
                     + Text(flight.destination).fontWeight(.semibold).foregroundColor(WIFTheme.primaryText)
                     + Text(" \(flight.arrivalTime)\(flight.arrivalDayLabel.map { " · \($0)" } ?? "")"))
                        .font(.caption).monospacedDigit()
                    HStack(spacing: 6) {
                        Text(flight.airline)
                        Text(flight.flightNumber).font(.system(size: 11, design: .monospaced))
                        if flight.terminal != "Not available" { Text(flight.terminal) }
                        Text(flight.status.title).foregroundStyle(flight.status.accent)
                    }
                    .font(.caption2).foregroundStyle(WIFTheme.secondaryText)
                }
            } else {
                Text(legDirection == .outbound ? String(localized: "Not added yet") : String(localized: "No return flight yet"))
                    .font(.caption).foregroundStyle(WIFTheme.caution)
                Spacer(minLength: 0)
                if isSelf, trip.cancelledAt == nil, legDirection == direction {
                    Button("Add", action: onAddFlight).font(.caption.weight(.semibold)).foregroundStyle(WIFTheme.fresh)
                }
            }
        }
        .foregroundStyle(WIFTheme.secondaryText)
    }
}
