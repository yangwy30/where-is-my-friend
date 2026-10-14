        // BEGIN TEMPORARY UX REVIEW FIXTURES
        if ProcessInfo.processInfo.arguments.contains("-reviewFriendRequest"),
           let request = self.snapshot.incomingRequests.first {
            self.snapshot.friendRequests = [FriendRequest(
                id: UUID(uuidString: "00000000-1111-4222-8333-444444444444")!, userID: request.userID,
                displayName: request.displayName, username: request.username, direction: .incoming,
                createdAt: Date(), avatarPalette: request.avatarPalette)]
        }
        if ProcessInfo.processInfo.arguments.contains("-reviewEmptyFriends") {
            self.snapshot.friends = []
            self.snapshot.friendRequests = []
            self.snapshot.friendPreferences = []
            self.snapshot.colocationEvents = []
            self.snapshot.colocationSessions = []
        }
        if ProcessInfo.processInfo.arguments.contains("-reviewOfflineState") {
            self.snapshot.syncState = .offline
            self.snapshot.lastSyncedAt = Date().addingTimeInterval(-3600)
        }
        if ProcessInfo.processInfo.arguments.contains("-reviewRepeatStay"),
           let friend = self.snapshot.friends.first(where: { $0.username == "mia" }),
           let city = self.snapshot.currentPresence.city,
           let cityKey = CityIdentity.presenceKey(city: city, countryCode: self.snapshot.currentPresence.countryCode,
               administrativeArea: self.snapshot.currentPresence.administrativeArea) {
            self.snapshot.friends = [friend]
            self.snapshot.colocationSessions = [ColocationSession(id: UUID(), friendID: friend.id,
                cityKey: cityKey, enteredAt: Date().addingTimeInterval(-3600), leftAt: nil)]
            self.snapshot.colocationEvents = [ColocationEvent(cityKey: cityKey, id: UUID(),
                deduplicationKey: "review-previous-visit", city: city, friendIDs: [friend.id],
                friendNames: [friend.displayName], createdAt: Date().addingTimeInterval(-7 * 86400), wasNotified: true)]
        }
        if ProcessInfo.processInfo.arguments.contains("-reviewLongNames"), !self.snapshot.friends.isEmpty {
            self.snapshot.friends[0].displayName = "Alexandra Catherine Montgomery"
            self.snapshot.friends[0].city = "San Luis Obispo"
            self.snapshot.friends[0].administrativeArea = "California"
            self.snapshot.friends[0].countryCode = "US"
            self.snapshot.friends[0].isFavorite = true
            self.snapshot.friends[0].updatedAt = Date()
            self.snapshot.currentPresence.city = "Tokyo"
            self.snapshot.currentPresence.countryCode = "JP"
            self.snapshot.currentPresence.administrativeArea = nil
        }
        // END TEMPORARY UX REVIEW FIXTURES
