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

enum TravelCityHistory {
    static let limit = 4

    static func recent(origin: String, ownerID: UUID, defaults: UserDefaults = .standard) -> [TravelCity] {
        guard let data = defaults.data(forKey: key(origin: origin, ownerID: ownerID)),
              let cities = try? JSONDecoder().decode([TravelCity].self, from: data) else { return [] }
        return Array(cities.prefix(limit))
    }

    static func remember(_ city: TravelCity, origin: String, ownerID: UUID, defaults: UserDefaults = .standard) {
        var cities = recent(origin: origin, ownerID: ownerID, defaults: defaults)
        cities.removeAll { $0.id == city.id }
        cities.insert(city, at: 0)
        if let data = try? JSONEncoder().encode(Array(cities.prefix(limit))) {
            defaults.set(data, forKey: key(origin: origin, ownerID: ownerID))
        }
    }

    static func key(origin: String, ownerID: UUID) -> String {
        "travel-city.recent.v1.\(origin).\(ownerID)"
    }
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
    // Selected friends can browse by default; the owner can turn this off per plan.
    var allowFriendBrowsing = true
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
        allowFriendBrowsing = try values.decodeIfPresent(Bool.self, forKey: .allowFriendBrowsing) ?? true
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
    // Copy only destination and dates; the new plan has no selected audience or alert consent.
    func privateDraft() -> PersonalTravelPlan {
        PersonalTravelPlan(city: city, countryCode: countryCode, region: region, timeZone: timeZone,
                           startDay: startDay, endDay: endDay)
    }
}

struct FriendPlanSummary: Codable, Equatable {
    let friendID: UUID
    let count: Int
    let nextPlan: FriendTravelPlan
}

struct FriendPlanCursor: Codable, Equatable, Sendable {
    let startDay: String
    let id: UUID
    let version: String
}

struct FriendPlanPage: Codable, Sendable {
    var items: [FriendTravelPlan]
    var nextCursor: FriendPlanCursor?
    var version: String
    var resetRequired: Bool = false
}

struct TravelPlanSnapshot: Codable {
    var plans: [PersonalTravelPlan] = []
    var overlaps: [TravelOverlap] = []
    var friendPlans: [FriendTravelPlan] = []
    var friendPlanSummaries: [FriendPlanSummary]?
    var includesOwnPlans = true
}

extension TravelPlanSnapshot {
    enum CodingKeys: String, CodingKey { case plans, overlaps, friendPlans, friendPlanSummaries, includesOwnPlans }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        plans = try values.decode([PersonalTravelPlan].self, forKey: .plans)
        overlaps = try values.decode([TravelOverlap].self, forKey: .overlaps)
        friendPlans = try values.decodeIfPresent([FriendTravelPlan].self, forKey: .friendPlans) ?? []
        friendPlanSummaries = try values.decodeIfPresent([FriendPlanSummary].self, forKey: .friendPlanSummaries)
        includesOwnPlans = try values.decodeIfPresent(Bool.self, forKey: .includesOwnPlans) ?? true
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
    @Published private(set) var accountScope: String?
    @Published private(set) var accessRevision = 0
    private var allowedFriendIDs: Set<UUID>?
    private var friendSummaries: [FriendPlanSummary]?
    private var lastRefreshAt: Date?
    private var repository: (any AppRepository)?
    private var scope: String?
    private var ownerID: UUID?
    private var cacheEpoch = 0
    private var generation = 0
    private var mutationEpoch = 0
    private var refreshTask: Task<TravelPlanSnapshot, Error>?
    private var refreshID: UUID?
    var isDemo: Bool { repository?.mode == .localDemo }

    func connect(repository: any AppRepository, userID: UUID?) {
        let newScope = userID.map { "travel-plans.v1.\(repository.storageScope).\($0)" }
        guard newScope != scope else { return }
        generation += 1
        cancelRefresh()
        self.repository = repository; ownerID = userID; scope = newScope; accountScope = newScope
        friendSummaries = nil; lastRefreshAt = nil; allowedFriendIDs = nil; accessRevision += 1
        cacheEpoch = newScope.map { AccountLocalData.epoch(for: $0) } ?? 0
        plans = []; overlaps = []; friendPlans = []; errorMessage = nil; hasSynced = false; isLoading = false; isSaving = false
        if let newScope, let data = UserDefaults.standard.data(forKey: newScope),
           let saved = try? JSONDecoder().decode([PersonalTravelPlan].self, from: data) { plans = saved }
    }

    func updateFriendAccess(_ ids: Set<UUID>) {
        guard let previous = allowedFriendIDs else { allowedFriendIDs = ids; return }
        guard previous != ids else { return }
        allowedFriendIDs = ids; accessRevision += 1; cancelRefresh()
        friendPlans = []; friendSummaries = nil; overlaps = []; hasSynced = false; lastRefreshAt = nil
    }

    func refresh(minimumInterval: TimeInterval = 0) async {
        if refreshTask == nil, hasSynced, let lastRefreshAt, Date().timeIntervalSince(lastRefreshAt) < minimumInterval { return }
        guard !Task.isCancelled, !isSaving, let repository, ownerID != nil else { return }
        let version = generation
        let epoch = mutationEpoch
        let task: Task<TravelPlanSnapshot, Error>
        let ticket: UUID
        if let existing = refreshTask, let existingID = refreshID {
            task = existing
            ticket = existingID
        } else {
            ticket = UUID()
            // The shared library owns this read. A disappearing view may stop
            // waiting, but must not cancel a request another screen needs.
            task = Task { try await repository.fetchTravelPlans() }
            refreshTask = task
            refreshID = ticket
            isLoading = true
        }
        defer {
            if refreshID == ticket {
                refreshTask = nil
                refreshID = nil
                isLoading = false
            }
        }
        do {
            let result = try await task.value
            guard refreshID == ticket, version == generation, epoch == mutationEpoch else { return }
            apply(result)
        } catch {
            guard refreshID == ticket, version == generation, epoch == mutationEpoch else { return }
            // Cancellation is control flow during account/navigation changes,
            // not evidence that the server rejected a shared plan.
            guard !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            overlaps = []; friendPlans = []; friendSummaries = nil; errorMessage = String(localized: "Couldn’t load shared plans. Try again."); hasSynced = false
        }
    }

    private func cancelRefresh() {
        ownRefreshID = nil; ownRefreshTask?.cancel(); ownRefreshTask = nil
        refreshID = nil
        refreshTask?.cancel()
        refreshTask = nil
        isLoading = false
    }

    func save(_ plan: PersonalTravelPlan) async -> Bool {
        guard !isSaving, let repository, ownerID != nil else { return false }
        let version = generation, sharingVersion = accessRevision
        mutationEpoch += 1
        cancelRefresh()
        isSaving = true
        defer { if generation == version { isSaving = false } }
        do {
            let result = try await repository.saveTravelPlan(try plan.validated())
            guard generation == version else { return false }
            apply(result, expectedAccess: sharingVersion); return true
        } catch {
            guard generation == version else { return false }
            errorMessage = mutationError(error)
            return false
        }
    }

    func delete(_ plan: PersonalTravelPlan) async -> Bool {
        guard !isSaving, let repository, ownerID != nil else { return false }
        let version = generation, sharingVersion = accessRevision
        mutationEpoch += 1
        cancelRefresh()
        isSaving = true
        defer { if generation == version { isSaving = false } }
        do {
            let result = try await repository.deleteTravelPlan(id: plan.id, revision: plan.revision)
            guard generation == version else { return false }
            apply(result, expectedAccess: sharingVersion); return true
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

    private func apply(_ incoming: TravelPlanSnapshot, expectedAccess: Int? = nil) {
        var result = incoming
        let accessChanged = expectedAccess.map { $0 != accessRevision } ?? false
        if accessChanged { result.friendPlans = []; result.friendPlanSummaries = []; result.overlaps = [] }
        guard let scope, AccountLocalData.epoch(for: scope) == cacheEpoch else { return }
        if result.includesOwnPlans { plans = result.plans }; overlaps = result.overlaps; hasSynced = true; errorMessage = nil
        lastRefreshAt = accessChanged ? nil : Date(); friendSummaries = result.friendPlanSummaries
        if accessChanged { hasSynced = false }
        // Shared full dates are memory-only: no offline or cross-account browsing cache.
        friendPlans = (result.friendPlanSummaries?.map(\.nextPlan) ?? result.friendPlans).sorted {
            if $0.startDay != $1.startDay { return $0.startDay < $1.startDay }
            return $0.id.uuidString < $1.id.uuidString
        }
        if let data = try? JSONEncoder().encode(plans) { UserDefaults.standard.set(data, forKey: scope) }
    }

    private var ownRefreshTask: Task<[PersonalTravelPlan], Error>?
    private var ownRefreshID: UUID?
    func refreshOwnPlans() async {
        guard let repository, ownerID != nil, !isSaving else { return }
        let currentGeneration = generation, currentMutation = mutationEpoch
        let ticket: UUID, read: Task<[PersonalTravelPlan], Error>
        if let existing = ownRefreshTask, let id = ownRefreshID { read = existing; ticket = id }
        else { ticket = UUID(); read = Task { try await repository.fetchOwnTravelPlans() }; ownRefreshTask = read; ownRefreshID = ticket }
        defer { if ownRefreshID == ticket { ownRefreshTask = nil; ownRefreshID = nil } }
        do {
            let result = try await read.value
            guard generation == currentGeneration, mutationEpoch == currentMutation, ownRefreshID == ticket,
                  let scope, AccountLocalData.epoch(for: scope) == cacheEpoch else { return }
            plans = result; errorMessage = nil
            if let data = try? JSONEncoder().encode(plans) { UserDefaults.standard.set(data, forKey: scope) }
        } catch {
            guard generation == currentGeneration, mutationEpoch == currentMutation, !(error is CancellationError) else { return }
            errorMessage = String(localized: "Couldn’t load your plans. Try again.")
        }
    }

    func friendPlanCount(friendIDs: Set<UUID>, at now: Date = Date()) -> Int {
        if let friendSummaries {
            return friendSummaries.filter { friendIDs.contains($0.friendID) && !$0.nextPlan.isPast(at: now) }.reduce(0) { $0 + $1.count }
        }
        return visibleFriendPlans(friendIDs: friendIDs, at: now).count
    }

    func fetchFriendPlanPage(cursor: FriendPlanCursor?, friendID: UUID?, planID: UUID?) async throws -> FriendPlanPage {
        guard let repository, ownerID != nil else { throw CancellationError() }
        let version = generation, access = accessRevision
        let result = try await repository.fetchFriendPlanPage(cursor: cursor, friendID: friendID, planID: planID)
        guard version == generation, access == accessRevision else { throw CancellationError() }
        return result
    }

    func visibleFriendPlans(friendIDs: Set<UUID>, at now: Date = Date()) -> [FriendTravelPlan] {
        friendPlans.filter { friendIDs.contains($0.friendID) && !$0.isPast(at: now) }
    }
}

/// Memory-only, account-scoped paging. A changed server version restarts the list.
@MainActor
final class FriendPlanFeed: ObservableObject {
    @Published private(set) var items: [FriendTravelPlan] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var nextCursor: FriendPlanCursor?
    @Published private(set) var errorMessage: String?
    private(set) var accountScope: String?
    private var accessRevision = 0
    func matches(_ library: TravelPlanLibrary) -> Bool { accountScope == library.accountScope && accessRevision == library.accessRevision }
    private weak var library: TravelPlanLibrary?
    private var friendID: UUID?
    private var planID: UUID?
    private var version: String?
    private var epoch = 0
    private var requestID: UUID?
    private var task: Task<FriendPlanPage, Error>?
    private var lastRefreshAt: Date?

    func connect(_ library: TravelPlanLibrary, friendID: UUID? = nil, planID: UUID? = nil) {
        guard self.library !== library || !matches(library) || self.friendID != friendID || self.planID != planID else { return }
        epoch += 1; task?.cancel(); task = nil; requestID = nil
        self.library = library; accountScope = library.accountScope; accessRevision = library.accessRevision; self.friendID = friendID; self.planID = planID
        items = []; nextCursor = nil; version = nil; errorMessage = nil; hasLoaded = false; isLoading = false; lastRefreshAt = nil
    }

    func refresh(minimumInterval: TimeInterval = 0) async {
        if hasLoaded, let lastRefreshAt, Date().timeIntervalSince(lastRefreshAt) < minimumInterval { return }
        await load(cursor: nil)
    }

    func loadMore() async {
        guard !isLoading, let nextCursor else { return }
        await load(cursor: nextCursor)
    }

    private func load(cursor: FriendPlanCursor?) async {
        guard !Task.isCancelled, let library, accountScope != nil, matches(library) else { return }
        // Join repeated refreshes; loading a new first page retires an older page request.
        if let task, cursor == nil, requestCursor == nil { _ = try? await task.value; return }
        if task != nil { epoch += 1; task?.cancel() }
        let currentEpoch = epoch, ticket = UUID(), scope = accountScope
        let friend = friendID, plan = planID
        let read = Task { try await library.fetchFriendPlanPage(cursor: cursor, friendID: friend, planID: plan) }
        task = read; requestID = ticket; requestCursor = cursor; isLoading = true; errorMessage = nil
        var restart = false
        do {
            let page = try await read.value
            guard requestID == ticket, epoch == currentEpoch, scope == library.accountScope, matches(library) else { return }
            if page.resetRequired || (cursor != nil && version != page.version) {
                items = []; nextCursor = nil; version = nil; hasLoaded = false
                restart = true
            } else if cursor == nil {
                if version != page.version || page.version == "local" || !hasLoaded {
                    items = page.items; nextCursor = page.nextCursor; version = page.version
                }
                hasLoaded = true; lastRefreshAt = Date()
            } else {
                let existing = Set(items.map(\.id))
                items.append(contentsOf: page.items.filter { !existing.contains($0.id) })
                nextCursor = page.nextCursor
            }
        } catch {
            guard requestID == ticket, epoch == currentEpoch, scope == library.accountScope, matches(library) else { return }
            if !(error is CancellationError), (error as? URLError)?.code != .cancelled {
                if cursor == nil { items = []; nextCursor = nil; hasLoaded = false }
                errorMessage = String(localized: "Couldn’t load shared plans. Try again.")
            }
        }
        if requestID == ticket { task = nil; requestID = nil; requestCursor = nil; isLoading = false }
        // The first page cannot itself request a restart. At most one replacement read.
        if restart { await load(cursor: nil) }
    }

    private var requestCursor: FriendPlanCursor?
}
