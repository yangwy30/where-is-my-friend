import Foundation

actor LocalDemoRepository: AppRepository {
    nonisolated let mode: RepositoryMode = .localDemo

    private var snapshot: AppSnapshot
    private let persistsChanges: Bool

    init(snapshot: AppSnapshot? = nil, persistsChanges: Bool = true) {
        self.persistsChanges = persistsChanges
        if let snapshot {
            self.snapshot = snapshot
        } else {
            self.snapshot = SharedAppStateStore.load() ?? DemoData.initialSnapshot()
        }
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
        snapshot = signedOutSnapshot()
        return commit()
    }

    func deleteAccount() async throws -> AppSnapshot {
        snapshot = signedOutSnapshot()
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
        let request = snapshot.friendRequests.remove(at: index)
        if response == .accept {
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
        return commit()
    }

    func removeFriend(id: UUID) async throws -> AppSnapshot {
        try requireAuthentication()
        guard snapshot.friends.contains(where: { $0.id == id }) else {
            throw RepositoryError.friendNotFound
        }
        snapshot.friends.removeAll { $0.id == id }
        snapshot.friendPreferences.removeAll { $0.friendID == id }
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
        return commit()
    }

    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot {
        try requireAuthentication()
        snapshot.sharingPreferences = preferences
        return commit()
    }

    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource) async throws -> AppSnapshot {
        try requireAuthentication()
        snapshot.currentPresence = CurrentUserPresence(
            city: city,
            countryCode: countryCode,
            updatedAt: Date(),
            source: source
        )
        appendNewColocationEventIfNeeded()
        return commit()
    }

    func registerPushToken(_ token: String) async throws {
        try requireAuthentication()
        guard !token.isEmpty else { return }
    }

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
                appendNewColocationEventIfNeeded()
            }
        case .ageLocations:
            for index in snapshot.friends.indices where snapshot.friends[index].sharingState == .active {
                snapshot.friends[index].updatedAt = Date().addingTimeInterval(-26 * 60 * 60)
            }
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

    private func requireAuthentication() throws {
        guard snapshot.isAuthenticated else { throw RepositoryError.notAuthenticated }
    }

    private func signedOutSnapshot() -> AppSnapshot {
        var empty = DemoData.initialSnapshot()
        empty.isAuthenticated = false
        empty.friends = []
        empty.friendRequests = []
        empty.friendPreferences = []
        empty.colocationEvents = []
        empty.currentPresence = CurrentUserPresence(city: nil, countryCode: nil, updatedAt: nil, source: .demo)
        return empty
    }

    private func appendNewColocationEventIfNeeded() {
        guard
            snapshot.sharingPreferences.citySharingEnabled,
            let city = snapshot.currentPresence.city
        else { return }

        let matches = snapshot.friends.filter { friend in
            let preference = snapshot.preference(for: friend.id)
            return preference.sameCityAlertEnabled
                && friend.city?.caseInsensitiveCompare(city) == .orderedSame
                && friend.isSameCityEligible()
        }
        guard !matches.isEmpty else { return }

        let day = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: Date())
        let dayKey = "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
        let friendKey = matches.map { $0.id.uuidString }.sorted().joined(separator: ",")
        let key = "\(city.lowercased())|\(friendKey)|\(dayKey)"
        guard !snapshot.colocationEvents.contains(where: { $0.deduplicationKey == key }) else { return }

        snapshot.colocationEvents.insert(
            ColocationEvent(
                id: UUID(),
                deduplicationKey: key,
                city: city,
                friendIDs: matches.map(\.id),
                friendNames: matches.map(\.displayName),
                createdAt: Date(),
                wasNotified: false
            ),
            at: 0
        )
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
