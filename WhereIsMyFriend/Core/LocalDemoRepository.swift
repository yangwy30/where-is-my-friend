import Foundation
import CryptoKit

actor LocalDemoRepository: AppRepository {
    nonisolated let mode: RepositoryMode = .localDemo
    nonisolated let storageScope = RepositoryMode.localDemo.rawValue

    private var snapshot: AppSnapshot
    private let persistsChanges: Bool
    private var personalPlans: [PersonalTravelPlan] = []

    init(snapshot: AppSnapshot? = nil, persistsChanges: Bool = true) {
        self.persistsChanges = persistsChanges
        if let snapshot {
            self.snapshot = snapshot
        } else {
            self.snapshot = SharedAppStateStore.load(expectedOrigin: storageScope)
                ?? DemoData.initialSnapshot()
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-previewCityFallbackCompare") {
            self.snapshot.currentPresence = CurrentUserPresence(administrativeArea: "CA", city: "Bakersfield",
                countryCode: "US", updatedAt: Date(), source: .foregroundLocation)
            let places: [(String, String?, String?)] = [
                ("New York", "NY", "US"),
                ("Bakersfield", "CA", "US"),
                ("Fremont", "CA", "US"),
                ("Tokyo", nil, "JP")
            ]
            for (index, place) in places.enumerated() where index < self.snapshot.friends.count {
                self.snapshot.friends[index].city = place.0
                self.snapshot.friends[index].administrativeArea = place.1
                self.snapshot.friends[index].countryCode = place.2
            }
            self.snapshot.colocationEvents = []
            self.snapshot.colocationSessions = []
            self.snapshot.isAuthenticated = true
            SharedAppStateStore.save(self.snapshot, origin: storageScope)
        } else if ProcessInfo.processInfo.arguments.contains("-previewCityRegions") {
            self.snapshot.currentPresence = CurrentUserPresence(administrativeArea: "CA", city: "Milpitas",
                countryCode: "US", updatedAt: Date(), source: .foregroundLocation)
            let places = [("Santa Clara", "CA"), ("Burbank", "CA"), ("Hoboken", "NJ")]
            for (index, place) in places.enumerated() where index < self.snapshot.friends.count {
                self.snapshot.friends[index].city = place.0
                self.snapshot.friends[index].countryCode = "US"
                self.snapshot.friends[index].administrativeArea = place.1
            }
            self.snapshot.colocationEvents = []
            self.snapshot.colocationSessions = []
        }
        #endif
    }

    func fetchTravelPlans() async throws -> TravelPlanSnapshot {
        try requireAuthentication()
        if personalPlans.isEmpty, persistsChanges, !ProcessInfo.processInfo.arguments.contains("-resetDemoData"),
           let data = UserDefaults.standard.data(forKey: "travel-plans.v1.\(storageScope).\(snapshot.currentUser.id)") {
            personalPlans = (try? JSONDecoder().decode([PersonalTravelPlan].self, from: data)) ?? []
        }
        return personalTravelSnapshot()
    }

    func saveTravelPlan(_ plan: PersonalTravelPlan) async throws -> TravelPlanSnapshot {
        try requireAuthentication()
        var saved = try plan.validated()
        let allowed = Set(snapshot.friends.map(\.id)).subtracting(snapshot.blockedUserIDs)
        guard Set(saved.audience).isSubset(of: allowed) else { throw RepositoryError.message("Choose current friends only.") }
        if let index = personalPlans.firstIndex(where: { $0.id == plan.id }) {
            guard personalPlans[index].revision == plan.revision else { throw RepositoryError.message("Travel plan conflict. Refresh and try again.") }
            saved.revision += 1; personalPlans[index] = saved
        } else {
            guard plan.revision == 0, personalPlans.count < 100 else { throw RepositoryError.message("Travel plan unavailable or limit reached.") }
            saved.revision = 1; personalPlans.append(saved)
        }
        persistPersonalPlans()
        return personalTravelSnapshot()
    }

    func deleteTravelPlan(id: UUID, revision: Int) async throws -> TravelPlanSnapshot {
        try requireAuthentication()
        guard let index = personalPlans.firstIndex(where: { $0.id == id }), personalPlans[index].revision == revision else {
            throw RepositoryError.message("Travel plan conflict. Refresh and try again.")
        }
        personalPlans.remove(at: index); persistPersonalPlans()
        return personalTravelSnapshot()
    }

    private func persistPersonalPlans() {
        guard persistsChanges, let data = try? JSONEncoder().encode(personalPlans) else { return }
        UserDefaults.standard.set(data, forKey: "travel-plans.v1.\(storageScope).\(snapshot.currentUser.id)")
    }

    private func personalTravelSnapshot() -> TravelPlanSnapshot {
        // Explicit demo fixture; production uses the reciprocal cloud query.
        let today = TripDay(Date(), timeZone: TimeZone(identifier: "Asia/Tokyo")!).value
        let last = TripDay(Date().addingTimeInterval(7 * 86400), timeZone: TimeZone(identifier: "Asia/Tokyo")!).value
        var overlaps: [TravelOverlap] = []
        for plan in personalPlans where !plan.isPast() && plan.destination.id == TravelCity.examples[0].id {
            for friend in snapshot.friends where friend.username == "lin" && plan.audience.contains(friend.id)
                && !snapshot.blockedUserIDs.contains(friend.id) {
                let start = max(today, plan.startDay), end = min(last, plan.endDay)
                guard start <= end else { continue }
                let key = "\(snapshot.currentUser.id):\(friend.id):\(plan.destination.id):\(start):\(end)"
                let id = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined().prefix(32)
                let overlap = TravelOverlap(id: String(id), friendID: friend.id, friendName: friend.displayName,
                    city: plan.city, countryCode: plan.countryCode, region: plan.region, timeZone: plan.timeZone, startDay: start, endDay: end)
                if !overlaps.contains(where: { $0.id == overlap.id }) { overlaps.append(overlap) }
            }
        }
        let sharedPlans = snapshot.friends.compactMap { friend -> FriendTravelPlan? in
            guard !snapshot.blockedUserIDs.contains(friend.id), ["lin", "chloe"].contains(friend.username) else { return nil }
            let isTokyo = friend.username == "lin"
            let id = UUID(uuidString: isTokyo ? "a7150000-0000-0000-0000-000000000001" : "a7150000-0000-0000-0000-000000000002")!
            return FriendTravelPlan(id: id, friendID: friend.id, friendName: friend.displayName,
                city: isTokyo ? "Tokyo" : "Paris", countryCode: isTokyo ? "JP" : "FR",
                region: isTokyo ? "Tokyo" : "Île-de-France", timeZone: isTokyo ? "Asia/Tokyo" : "Europe/Paris",
                startDay: today, endDay: last)
        }
        return TravelPlanSnapshot(plans: personalPlans.sorted { $0.startDay < $1.startDay }, overlaps: overlaps, friendPlans: sharedPlans)
    }

    func loadSnapshot() async throws -> AppSnapshot {
        snapshot
    }

    func signInDemo() async throws -> AppSnapshot {
        if snapshot.friends.isEmpty {
            snapshot = DemoData.initialSnapshot()
        }
        snapshot.isAuthenticated = true
        return commit()
    }

    func signInWithApple(_ payload: AppleSignInPayload) async throws -> AppSnapshot {
        if snapshot.friends.isEmpty {
            snapshot = DemoData.initialSnapshot()
        }
        snapshot.isAuthenticated = true
        snapshot.currentUser.appleUserID = payload.appleUserID
        if let displayName = payload.displayName, !displayName.isEmpty {
            snapshot.currentUser.displayName = displayName
        }
        return commit()
    }

    func signOut() async throws -> AppSnapshot {
        personalPlans = []
        snapshot = signedOutSnapshot()
        return commit()
    }

    func deleteAccount() async throws -> AppSnapshot {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-testAccountDeletionFailure") { throw RepositoryError.networkUnavailable }
        #endif
        personalPlans = []
        persistPersonalPlans()
        snapshot = signedOutSnapshot()
        return commit()
    }

    func updateProfile(_ update: ProfileUpdate) async throws -> AppSnapshot {
        try requireAuthentication()
        let validated = try update.validated()
        snapshot.currentUser.displayName = validated.displayName
        snapshot.currentUser.username = validated.username
        snapshot.currentUser.avatarPalette = validated.avatarPalette
        return commit()
    }

    func sendFriendRequest(username: String) async throws -> AppSnapshot {
        try requireAuthentication()
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
        guard normalized != snapshot.currentUser.username.lowercased() else {
            throw RepositoryError.cannotInviteYourself
        }
        guard !snapshot.friends.contains(where: { $0.username.lowercased() == normalized }) else {
            throw RepositoryError.alreadyFriends
        }
        guard !snapshot.friendRequests.contains(where: { $0.username.lowercased() == normalized }) else {
            throw RepositoryError.requestAlreadyExists
        }
        guard let person = DemoData.person(username: normalized) else {
            throw RepositoryError.userNotFound
        }
        guard !snapshot.blockedUserIDs.contains(person.id) else {
            throw RepositoryError.alreadyBlocked
        }

        snapshot.friendRequests.append(
            FriendRequest(
                id: UUID(),
                userID: person.id,
                displayName: person.displayName,
                username: person.username,
                direction: .outgoing,
                createdAt: Date(),
                avatarPalette: person.avatarPalette
            )
        )
        return commit()
    }

    func respond(to requestID: UUID, response: FriendRequestResponse) async throws -> AppSnapshot {
        try requireAuthentication()
        guard let index = snapshot.friendRequests.firstIndex(where: { $0.id == requestID }) else {
            throw RepositoryError.requestNotFound
        }
        let request = snapshot.friendRequests[index]
        if response == .accept {
            guard !snapshot.blockedUserIDs.contains(request.userID) else {
                throw RepositoryError.alreadyBlocked
            }
            let person = DemoData.person(username: request.username)
                ?? DirectoryPerson(
                    id: request.userID,
                    displayName: request.displayName,
                    username: request.username,
                    city: nil,
                    countryCode: nil,
                    avatarPalette: request.avatarPalette
                )
            if !snapshot.friends.contains(where: { $0.id == person.id }) {
                snapshot.friends.append(person.asPresence)
                snapshot.friendPreferences.append(
                    FriendAccessPreference(
                        friendID: person.id,
                        sharesMyCity: true,
                        sameCityAlertEnabled: true
                    )
                )
            }
        }
        snapshot.friendRequests.remove(at: index)
        return commit()
    }

    func removeFriend(id: UUID) async throws -> AppSnapshot {
        try requireAuthentication()
        guard snapshot.friends.contains(where: { $0.id == id }) else {
            throw RepositoryError.friendNotFound
        }
        snapshot.friends.removeAll { $0.id == id }
        snapshot.friendPreferences.removeAll { $0.friendID == id }
        snapshot.colocationSessions.removeAll { $0.friendID == id }
        return commit()
    }

    func blockUser(id: UUID) async throws -> AppSnapshot {
        try requireAuthentication()
        guard !snapshot.blockedUserIDs.contains(id) else { throw RepositoryError.alreadyBlocked }
        let friend = snapshot.friends.first(where: { $0.id == id })
        let request = snapshot.friendRequests.first(where: { $0.userID == id })
        guard friend != nil || request != nil else { throw RepositoryError.friendNotFound }
        snapshot.blockedPeople.append(
            BlockedPerson(
                id: id,
                displayName: friend?.displayName ?? request?.displayName ?? "Blocked user",
                username: friend?.username ?? request?.username ?? "blocked",
                avatarPalette: friend?.avatarPalette ?? request?.avatarPalette ?? 4,
                blockedAt: Date()
            )
        )
        snapshot.friends.removeAll { $0.id == id }
        snapshot.friendRequests.removeAll { $0.userID == id }
        snapshot.friendPreferences.removeAll { $0.friendID == id }
        snapshot.colocationSessions.removeAll { $0.friendID == id }
        snapshot.colocationEvents.removeAll { $0.friendIDs.contains(id) }
        return commit()
    }

    func unblockUser(id: UUID) async throws -> AppSnapshot {
        try requireAuthentication()
        guard snapshot.blockedUserIDs.contains(id) else { throw RepositoryError.blockedUserNotFound }
        snapshot.blockedPeople.removeAll { $0.id == id }
        return commit()
    }

    func setFavorite(friendID: UUID, isFavorite: Bool) async throws -> AppSnapshot {
        try requireAuthentication()
        guard let index = snapshot.friends.firstIndex(where: { $0.id == friendID }) else {
            throw RepositoryError.friendNotFound
        }
        snapshot.friends[index].isFavorite = isFavorite
        return commit()
    }

    func setFriendPreference(_ preference: FriendAccessPreference) async throws -> AppSnapshot {
        try requireAuthentication()
        guard snapshot.friends.contains(where: { $0.id == preference.friendID }) else {
            throw RepositoryError.friendNotFound
        }
        snapshot.friendPreferences.removeAll { $0.friendID == preference.friendID }
        snapshot.friendPreferences.append(preference)
        ColocationEvaluator.evaluate(snapshot: &snapshot)
        return commit()
    }

    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot {
        try requireAuthentication()
        snapshot.sharingPreferences = preferences
        ColocationEvaluator.evaluate(snapshot: &snapshot)
        return commit()
    }

    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource, observedAt: Date, administrativeArea: String? = nil) async throws -> AppSnapshot {
        try requireAuthentication()
        snapshot.currentPresence = CurrentUserPresence(
            administrativeArea: administrativeArea,
            city: CityIdentity.canonicalCity(city),
            countryCode: countryCode?.uppercased(),
            updatedAt: observedAt,
            source: source
        )
        ColocationEvaluator.evaluate(snapshot: &snapshot)
        return commit()
    }

    func registerPushToken(_ token: String) async throws {
        try requireAuthentication()
        guard !token.isEmpty else { return }
    }

    func retryPendingOperations() async throws -> AppSnapshot { snapshot }

    func pendingOperationCount() async -> Int { 0 }

    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot {
        try requireAuthentication()
        switch scenario {
        case .friendArrives:
            guard let currentCity = snapshot.currentPresence.city else { return snapshot }
            let preferredIndex = snapshot.friends.firstIndex { friend in
                friend.city?.caseInsensitiveCompare(currentCity) != .orderedSame
            }
            if let index = preferredIndex {
                snapshot.friends[index].city = currentCity
                snapshot.friends[index].countryCode = snapshot.currentPresence.countryCode
                snapshot.friends[index].updatedAt = Date()
                snapshot.friends[index].sharingState = .active
                ColocationEvaluator.evaluate(snapshot: &snapshot)
            }
        case .ageLocations:
            for index in snapshot.friends.indices where snapshot.friends[index].sharingState == .active {
                snapshot.friends[index].updatedAt = Date().addingTimeInterval(-26 * 60 * 60)
            }
            ColocationEvaluator.evaluate(snapshot: &snapshot)
        case .incomingRequest:
            if let person = DemoData.directory.first(where: { candidate in
                !snapshot.friends.contains(where: { $0.id == candidate.id })
                    && !snapshot.friendRequests.contains(where: { $0.userID == candidate.id })
            }) {
                snapshot.friendRequests.append(
                    FriendRequest(
                        id: UUID(),
                        userID: person.id,
                        displayName: person.displayName,
                        username: person.username,
                        direction: .incoming,
                        createdAt: Date(),
                        avatarPalette: person.avatarPalette
                    )
                )
            }
        case .restoreDefaults:
            snapshot = DemoData.initialSnapshot()
        }
        return commit()
    }

    func lookupFlight(tripID: String, flightNumber: String, date: String) async throws -> [FlightCandidate] {
        let clean = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: " ", with: "")
        guard !clean.isEmpty else { return [] }

        // Demo data never contacts a billable provider or falls back from failed live data.
        if clean == "UA353" {
            return [
                FlightCandidate(
                    id: "EWR|LAX|\(date) 18:30-04:00",
                    flightNumber: "UA 353",
                    date: date,
                    airline: "United Airlines",
                    departure: FlightEndpoint(
                        code: "EWR",
                        icao: "KEWR",
                        city: "New York",
                        name: "Newark Liberty Intl",
                        timeZone: "America/New_York",
                        scheduledTime: FlightTimePair(local: "\(date) 18:30-04:00", utc: "\(date) 22:30Z"),
                        terminal: "C"
                    ),
                    arrival: FlightEndpoint(
                        code: "LAX",
                        icao: "KLAX",
                        city: "Los Angeles",
                        name: "Los Angeles Intl",
                        timeZone: "America/Los_Angeles",
                        scheduledTime: FlightTimePair(local: "\(date) 21:33-07:00", utc: "\(date) 04:33Z"),
                        terminal: "7"
                    ),
                    status: "landed",
                    providerStatus: "Arrived"
                )
            ]
        }

        // 3. No fictitious flights! Never invent random routes for real flight numbers.
        return []
    }

    private func requireAuthentication() throws {
        guard snapshot.isAuthenticated else { throw RepositoryError.notAuthenticated }
    }

    private func signedOutSnapshot() -> AppSnapshot {
        DemoData.signedOutSnapshot()
    }

    private func commit() -> AppSnapshot {
        snapshot.lastSyncedAt = Date()
        snapshot.syncState = .synced
        if persistsChanges {
            SharedAppStateStore.save(snapshot)
        }
        return snapshot
    }
}
