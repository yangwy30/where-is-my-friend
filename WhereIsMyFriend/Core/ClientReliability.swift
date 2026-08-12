import CryptoKit
import Foundation
import Security

struct PendingInvite: Identifiable, Codable, Equatable, Sendable {
    var id: String { username }
    let username: String
    let receivedAt: Date
}

enum InviteLinkParser {
    static func parse(
        _ url: URL,
        appScheme: String = SharedAppLink.urlScheme,
        trustedInviteHosts: Set<String> = InviteLinkConfiguration.trustedHosts(),
        now: Date = Date()
    ) -> PendingInvite? {
        let components = url.pathComponents.filter { $0 != "/" }
        let rawUsername: String?
        if url.scheme?.lowercased() == appScheme.lowercased(), url.host == "invite" {
            rawUsername = components.first
        } else if url.scheme == "https",
                  let host = url.host?.lowercased(),
                  trustedInviteHosts.contains(host),
                  let inviteIndex = components.firstIndex(of: "invite"),
                  components.indices.contains(inviteIndex + 1) {
            rawUsername = components[inviteIndex + 1]
        } else {
            rawUsername = nil
        }
        guard let rawUsername else { return nil }
        let decodedUsername = rawUsername.removingPercentEncoding ?? rawUsername
        let username = decodedUsername
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
        guard (3...20).contains(username.count) else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        guard username.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return PendingInvite(username: username, receivedAt: now)
    }
}

enum InviteLinkConfiguration {
    static func trustedHosts(bundle: Bundle = .main) -> Set<String> {
        guard let raw = bundle.object(forInfoDictionaryKey: "WIFInviteBaseURL") as? String,
              let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              !host.hasSuffix(".invalid") else {
            return []
        }
        return [host]
    }
}

enum InviteURLFactory {
    static func make(username: String, bundle: Bundle = .main) -> URL {
        let normalized = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        if let base = bundle.object(forInfoDictionaryKey: "WIFInviteBaseURL") as? String,
           let baseURL = URL(string: base), baseURL.scheme == "https" {
            return baseURL.appending(path: "invite").appending(path: normalized)
        }
        return SharedAppLink.make(host: "invite", path: normalized)
    }
}

enum AppleSignInNonce {
    enum NonceError: LocalizedError {
        case randomGenerationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .randomGenerationFailed:
                "A secure Apple sign-in request could not be created. Please try again."
            }
        }
    }

    static func make(length: Int = 32) throws -> String {
        precondition(length > 0)
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        while result.count < length {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { throw NonceError.randomGenerationFailed(status) }
            if random < alphabet.count {
                result.append(alphabet[Int(random)])
            }
        }
        return result
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum PendingInviteStore {
    private static let key = "app.pending-invite.v1"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedPresenceStore.appGroupIdentifier) ?? .standard
    }

    static func load() -> PendingInvite? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PendingInvite.self, from: data)
    }

    static func save(_ invite: PendingInvite) {
        guard let data = try? JSONEncoder().encode(invite) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear() { defaults.removeObject(forKey: key) }
}

struct PendingPresenceUpload: Codable, Equatable, Sendable {
    let city: String
    let countryCode: String?
    let source: PresenceSource
    let clientUpdatedAt: Date
}

enum PendingRemoteMutationPayload: Codable, Equatable, Sendable {
    case presence(PendingPresenceUpload)
    case pushToken(String)
    case sharingPreferences(SharingPreferences)

    var coalescingKey: String {
        switch self {
        case .presence: "presence"
        case .pushToken: "push-token"
        case .sharingPreferences: "sharing-preferences"
        }
    }
}

struct QueuedRemoteMutation: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    var payload: PendingRemoteMutationPayload
    var createdAt: Date
    var attempts: Int
    var nextAttemptAt: Date
}

actor OfflineMutationQueue {
    static let shared = OfflineMutationQueue()

    private let defaults: UserDefaults
    private let storageKey: String
    private var mutations: [QueuedRemoteMutation]

    init(
        defaults: UserDefaults = UserDefaults(suiteName: SharedPresenceStore.appGroupIdentifier) ?? .standard,
        storageKey: String = "remote-mutation-queue.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([QueuedRemoteMutation].self, from: data) {
            mutations = decoded
        } else {
            mutations = []
        }
    }

    func enqueue(_ payload: PendingRemoteMutationPayload, ownerID: UUID, now: Date = Date()) {
        mutations.removeAll {
            $0.ownerID == ownerID && $0.payload.coalescingKey == payload.coalescingKey
        }
        mutations.append(
            QueuedRemoteMutation(
                id: UUID(),
                ownerID: ownerID,
                payload: payload,
                createdAt: now,
                attempts: 0,
                nextAttemptAt: now
            )
        )
        persist()
    }

    func due(ownerID: UUID, at date: Date = Date()) -> [QueuedRemoteMutation] {
        mutations
            .filter { $0.ownerID == ownerID && $0.nextAttemptAt <= date }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func all(ownerID: UUID) -> [QueuedRemoteMutation] {
        mutations.filter { $0.ownerID == ownerID }.sorted { $0.createdAt < $1.createdAt }
    }

    func remove(id: UUID) {
        mutations.removeAll { $0.id == id }
        persist()
    }

    func markFailed(id: UUID, now: Date = Date()) {
        guard let index = mutations.firstIndex(where: { $0.id == id }) else { return }
        mutations[index].attempts += 1
        let exponent = min(mutations[index].attempts - 1, 8)
        let delay = min(15 * pow(2, Double(exponent)), 60 * 60)
        mutations[index].nextAttemptAt = now.addingTimeInterval(delay)
        persist()
    }

    func count(ownerID: UUID) -> Int { mutations.count { $0.ownerID == ownerID } }

    func reset(ownerID: UUID? = nil) {
        if let ownerID {
            mutations.removeAll { $0.ownerID == ownerID }
        } else {
            mutations = []
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(mutations) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
