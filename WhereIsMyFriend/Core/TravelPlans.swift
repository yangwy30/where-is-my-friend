import Foundation
import SwiftUI

struct TravelCity: Codable, Hashable, Identifiable {
    var name: String
    var countryCode: String
    var region: String
    var timeZone: String
    var matchingKey: String? { CityIdentity.presenceKey(city: name, countryCode: countryCode, administrativeArea: region).map { $0 + "|" + timeZone } }
    var id: String { matchingKey ?? "unresolved|\(countryCode)|\(name)|\(timeZone)" }
    var subtitle: String { [region, Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode].filter { !$0.isEmpty }.joined(separator: ", ") }
    static let examples = [
        TravelCity(name: "Tokyo", countryCode: "JP", region: "Tokyo", timeZone: "Asia/Tokyo"),
        TravelCity(name: "New York", countryCode: "US", region: "NY", timeZone: "America/New_York"),
        TravelCity(name: "Palm Springs", countryCode: "US", region: "CA", timeZone: "America/Los_Angeles")
    ]
}

struct PersonalTravelPlan: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var city: String
    var countryCode: String
    var region: String
    var timeZone: String
    var startDay: String
    var endDay: String
    var audience: [UUID] = []
    var alertsEnabled = false
    var revision = 0
    // Older plans authorized matching only. Browsing full dates needs separate consent.
    var allowFriendBrowsing = false
    var destination: TravelCity { TravelCity(name: city, countryCode: countryCode, region: region, timeZone: timeZone) }
    var dateLabel: String { TravelDateRangeSelection.label(start: startDay, end: endDay) }
    func isPast(at now: Date = Date()) -> Bool { endDay < TripDay(now, timeZone: TimeZone(identifier: timeZone) ?? .gmt).value }
    func validated() throws -> Self {
        guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, city.count <= 120,
              countryCode.range(of: "^[A-Z]{2}$", options: .regularExpression) != nil,
              region.count <= 120, TimeZone(identifier: timeZone) != nil,
              let start = Self.parseDay(startDay), let end = Self.parseDay(endDay),
              end >= start, end.timeIntervalSince(start) <= 366 * 86400,
              audience.count <= 100, revision >= 0 else { throw RepositoryError.message("Choose a city and a valid date range (up to one year).") }
        return self
    }
    static func parseDay(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }
}

extension PersonalTravelPlan {
    enum CodingKeys: String, CodingKey {
        case id, city, countryCode, region, timeZone, startDay, endDay, audience, alertsEnabled, revision, allowFriendBrowsing
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        city = try values.decode(String.self, forKey: .city)
        countryCode = try values.decode(String.self, forKey: .countryCode)
        region = try values.decode(String.self, forKey: .region)
        timeZone = try values.decode(String.self, forKey: .timeZone)
        startDay = try values.decode(String.self, forKey: .startDay)
        endDay = try values.decode(String.self, forKey: .endDay)
        audience = try values.decode([UUID].self, forKey: .audience)
        alertsEnabled = try values.decode(Bool.self, forKey: .alertsEnabled)
        revision = try values.decode(Int.self, forKey: .revision)
        allowFriendBrowsing = try values.decodeIfPresent(Bool.self, forKey: .allowFriendBrowsing) ?? false
    }
}

struct TravelPlanPayload: Encodable {
    let city: String, countryCode: String, region: String, timeZone: String, startDay: String, endDay: String
    let audience: [UUID]
    let alertsEnabled: Bool
    let revision: Int
    let allowFriendBrowsing: Bool
    init(_ plan: PersonalTravelPlan) {
        city = plan.city; countryCode = plan.countryCode; region = plan.region; timeZone = plan.timeZone
        startDay = plan.startDay; endDay = plan.endDay; audience = plan.audience
        alertsEnabled = plan.alertsEnabled; revision = plan.revision
        allowFriendBrowsing = plan.allowFriendBrowsing
    }
}

struct TravelOverlap: Identifiable, Codable, Equatable {
    var id: String
    var friendID: UUID
    var friendName: String
    var city: String
    var countryCode: String
    var region: String
    var timeZone: String
    var startDay: String
    var endDay: String
    var dateLabel: String { TravelDateRangeSelection.label(start: startDay, end: endDay) }
    var daysTogether: Int {
        guard let start = PersonalTravelPlan.parseDay(startDay), let end = PersonalTravelPlan.parseDay(endDay) else { return 0 }
        return Int(end.timeIntervalSince(start) / 86400) + 1
    }
    func isPast(at now: Date = Date()) -> Bool { endDay < TripDay(now, timeZone: TimeZone(identifier: timeZone) ?? .gmt).value }
}

struct FriendTravelPlan: Identifiable, Codable, Equatable {
    let id: UUID
    let friendID: UUID
    let friendName: String
    let city: String
    let countryCode: String
    let region: String
    let timeZone: String
    let startDay: String
    let endDay: String

    var dateLabel: String { privateDraft().dateLabel }
    func isPast(at now: Date = Date()) -> Bool { privateDraft().isPast(at: now) }
    // Copy only destination and dates, never permissions, identifiers or alert consent.
    func privateDraft() -> PersonalTravelPlan {
        PersonalTravelPlan(city: city, countryCode: countryCode, region: region, timeZone: timeZone,
                           startDay: startDay, endDay: endDay)
    }
}

struct TravelPlanSnapshot: Codable {
    var plans: [PersonalTravelPlan] = []
    var overlaps: [TravelOverlap] = []
    var friendPlans: [FriendTravelPlan] = []
}

extension TravelPlanSnapshot {
    enum CodingKeys: String, CodingKey { case plans, overlaps, friendPlans }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        plans = try values.decode([PersonalTravelPlan].self, forKey: .plans)
        overlaps = try values.decode([TravelOverlap].self, forKey: .overlaps)
        friendPlans = try values.decodeIfPresent([FriendTravelPlan].self, forKey: .friendPlans) ?? []
    }
}

enum UpcomingTravelLink {
    static func parse(_ url: URL, scheme: String = SharedAppLink.urlScheme) -> String? {
        guard url.scheme == scheme, url.host == "upcoming", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 1, parts[0].range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil else { return nil }
        return parts[0]
    }
}

@MainActor
final class TravelPlanLibrary: ObservableObject {
    @Published private(set) var plans: [PersonalTravelPlan] = []
    @Published private(set) var overlaps: [TravelOverlap] = []
    @Published private(set) var friendPlans: [FriendTravelPlan] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var hasSynced = false
    private var repository: (any AppRepository)?
    private var scope: String?
    private var ownerID: UUID?
    private var cacheEpoch = 0
    private var generation = 0
    private var mutationEpoch = 0
    var isDemo: Bool { repository?.mode == .localDemo }

    func connect(repository: any AppRepository, userID: UUID?) {
        let newScope = userID.map { "travel-plans.v1.\(repository.storageScope).\($0)" }
        guard newScope != scope else { return }
        generation += 1
        self.repository = repository; ownerID = userID; scope = newScope
        cacheEpoch = newScope.map { AccountLocalData.epoch(for: $0) } ?? 0
        plans = []; overlaps = []; friendPlans = []; errorMessage = nil; hasSynced = false; isLoading = false; isSaving = false
        if let newScope, let data = UserDefaults.standard.data(forKey: newScope),
           let saved = try? JSONDecoder().decode([PersonalTravelPlan].self, from: data) { plans = saved }
    }

    func refresh() async {
        guard !isLoading, !isSaving, let repository, ownerID != nil else { return }
        let version = generation
        let epoch = mutationEpoch
        isLoading = true
        defer { if version == generation { isLoading = false } }
        do {
            let result = try await repository.fetchTravelPlans()
            guard version == generation, epoch == mutationEpoch else { return }
            apply(result)
        } catch {
            guard version == generation, epoch == mutationEpoch else { return }
            overlaps = []; friendPlans = []; errorMessage = String(localized: "Couldn’t load shared plans. Try again."); hasSynced = false
        }
    }

    func save(_ plan: PersonalTravelPlan) async -> Bool {
        guard !isSaving, let repository, ownerID != nil else { return false }
        let version = generation
        mutationEpoch += 1
        isSaving = true
        defer { if generation == version { isSaving = false } }
        do {
            let result = try await repository.saveTravelPlan(try plan.validated())
            guard generation == version else { return false }
            apply(result); return true
        } catch {
            guard generation == version else { return false }
            errorMessage = mutationError(error)
            return false
        }
    }

    func delete(_ plan: PersonalTravelPlan) async -> Bool {
        guard !isSaving, let repository, ownerID != nil else { return false }
        let version = generation
        mutationEpoch += 1
        isSaving = true
        defer { if generation == version { isSaving = false } }
        do {
            let result = try await repository.deleteTravelPlan(id: plan.id, revision: plan.revision)
            guard generation == version else { return false }
            apply(result); return true
        } catch {
            guard generation == version else { return false }
            errorMessage = mutationError(error); return false
        }
    }

    private func mutationError(_ error: Error) -> String {
        if error as? RepositoryError == .networkUnavailable || error as? RepositoryError == .serverTemporarilyUnavailable || error is URLError {
            return "Changes weren’t saved. Check your connection and try again; this edit isn’t queued."
        }
        return error.localizedDescription
    }

    private func apply(_ result: TravelPlanSnapshot) {
        guard let scope, AccountLocalData.epoch(for: scope) == cacheEpoch else { return }
        plans = result.plans; overlaps = result.overlaps; hasSynced = true; errorMessage = nil
        // Shared full dates are memory-only: no offline or cross-account browsing cache.
        friendPlans = result.friendPlans.sorted {
            if $0.startDay != $1.startDay { return $0.startDay < $1.startDay }
            return $0.id.uuidString < $1.id.uuidString
        }
        if let data = try? JSONEncoder().encode(plans) { UserDefaults.standard.set(data, forKey: scope) }
    }

    func visibleFriendPlans(friendIDs: Set<UUID>, at now: Date = Date()) -> [FriendTravelPlan] {
        friendPlans.filter { friendIDs.contains($0.friendID) && !$0.isPast(at: now) }
    }
}
