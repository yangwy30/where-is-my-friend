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
            self.snapshot = SharedAppStateStore.load(expectedOrigin: RepositoryMode.localDemo.rawValue)
                ?? DemoData.initialSnapshot()
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

    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource) async throws -> AppSnapshot {
        try requireAuthentication()
        snapshot.currentPresence = CurrentUserPresence(
            city: CityIdentity.canonicalCity(city),
            countryCode: countryCode?.uppercased(),
            updatedAt: Date(),
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
