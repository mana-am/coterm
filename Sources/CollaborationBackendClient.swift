import Foundation

/// Resolved collaboration entitlements for the caller's active org, as computed
/// authoritatively by www from Clerk metadata + billing status.
struct CollaborationEntitlements: Codable, Equatable, Sendable {
    var plan: String
    var directorySharing: Bool
    var codesEnabled: Bool

    /// The safe default before we've talked to the backend: free/hobby, so
    /// codes work and directory sharing is hidden.
    static let hobbyDefault = CollaborationEntitlements(
        plan: "hobby",
        directorySharing: false,
        codesEnabled: true
    )
}

/// A session created through www: the signed descriptor (used for directory
/// invites), the relay room key, an optional human code, the relay URL, and the
/// owner's short-lived join grant.
struct CollaborationCreatedSession: Decodable, Sendable {
    let session: String
    let room: String
    let code: String?
    let relayURL: String
    let grant: String
    let shareSecret: String?
    let entitlements: CollaborationEntitlements
}

/// A teammate eligible for directory sharing (an org member other than self).
struct CollaborationDirectoryMember: Decodable, Sendable, Identifiable, Equatable {
    let userId: String
    let label: String
    let role: String?

    var id: String { userId }
}

/// An incoming shared-session invite delivered to this user's inbox.
struct CollaborationIncomingSession: Decodable, Sendable, Identifiable, Equatable {
    let session: String
    let ownerUserId: String
    let ownerName: String?
    let ownerImageURL: String?
    let orgId: String
    let orgName: String?
    let relayURL: String?
    let createdAt: String

    var id: String { session }
}

/// The result of joining a session: everything the relay connect needs.
struct CollaborationJoinResult: Decodable, Sendable {
    let room: String
    let code: String?
    let relayURL: String
    let grant: String
}

struct CollaborationJoinRequestPending: Decodable, Sendable {
    let status: String
    let requestId: String
    let room: String
    let code: String?
    let relayURL: String
}

struct CollaborationJoinApprovalRequest: Decodable, Sendable, Identifiable, Equatable {
    let requestId: String
    let room: String
    let requesterUserId: String
    let requesterName: String?
    let requesterImageURL: String?
    let status: String
    let createdAt: String

    var id: String { requestId }
}

enum CollaborationCodeJoinGrant: Sendable {
    case granted(CollaborationJoinResult)
    case pending(CollaborationJoinRequestPending)
}

enum CollaborationBackendError: LocalizedError {
    case invalidURL
    case http(status: Int, code: String?)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid collaboration backend URL."
        case let .http(status, code):
            return "Collaboration backend error (\(status))\(code.map { ": \($0)" } ?? "")."
        case .decoding:
            return "Could not decode the collaboration backend response."
        }
    }
}

/// Typed client for the www `/api/collab` endpoints. All calls authenticate
/// with the native `cotermv1` access token (Bearer). Used from the main actor
/// by ``CollaborationRuntime``; the caller supplies a fresh access token.
struct CollaborationBackendClient {
    let baseURL: URL
    var session: URLSession = .shared

    private static let requestTimeout: TimeInterval = 10

    private struct ErrorBody: Decodable { let error: String? }
    private struct OKBody: Decodable { let ok: Bool? }
    private struct DirectoryBody: Decodable { let members: [CollaborationDirectoryMember] }
    private struct InboxBody: Decodable { let invites: [CollaborationIncomingSession] }
    private struct JoinRequestsBody: Decodable { let requests: [CollaborationJoinApprovalRequest] }
    private struct JoinApprovalBody: Decodable { let request: CollaborationJoinApprovalRequest }

    func entitlements(accessToken: String, orgId: String) async throws -> CollaborationEntitlements {
        try await get("api/collab/entitlements", accessToken: accessToken, query: ["orgId": orgId])
    }

    func createSession(
        accessToken: String,
        orgId: String,
        relayURL: String?,
        precreatedCode: String? = nil,
        precreatedShareSecret: String? = nil
    ) async throws -> CollaborationCreatedSession {
        var body: [String: String] = ["orgId": orgId]
        if let relayURL { body["relayURL"] = relayURL }
        // A relay room the app already created from the user's machine, so its
        // Durable Object is placed near the user instead of near www. Older
        // www deployments ignore the extra field and create the room
        // themselves (the previous, higher-latency behavior).
        if let precreatedCode { body["code"] = precreatedCode }
        if let precreatedShareSecret { body["shareSecret"] = precreatedShareSecret }
        return try await post("api/collab/sessions", accessToken: accessToken, body: body)
    }

    func directory(accessToken: String, orgId: String) async throws -> [CollaborationDirectoryMember] {
        let body: DirectoryBody = try await get(
            "api/collab/org-directory",
            accessToken: accessToken,
            query: ["orgId": orgId]
        )
        return body.members
    }

    func invite(
        accessToken: String,
        session: String,
        inviteeUserId: String,
        relayURL: String?
    ) async throws {
        var body: [String: String] = ["session": session, "inviteeUserId": inviteeUserId]
        if let relayURL { body["relayURL"] = relayURL }
        let _: OKBody = try await post("api/collab/invite", accessToken: accessToken, body: body)
    }

    func inbox(accessToken: String) async throws -> [CollaborationIncomingSession] {
        let body: InboxBody = try await get("api/collab/inbox", accessToken: accessToken, query: [:])
        return body.invites
    }

    /// Like ``inbox(accessToken:)`` but asks www to probe each invite's relay room
    /// and prune sessions that have ended, so the returned list only contains
    /// joinable sessions. Used when the user opens the incoming-sessions picker.
    func reconcileInbox(accessToken: String) async throws -> [CollaborationIncomingSession] {
        let body: InboxBody = try await post("api/collab/inbox/reconcile", accessToken: accessToken, body: [:])
        return body.invites
    }

    /// Revoke a directory invite previously sent to `inviteeUserId` for the given
    /// signed session descriptor. Used when a session ends so the teammate's
    /// inbox stops surfacing an invite for a session that no longer exists.
    func withdraw(
        accessToken: String,
        session: String,
        inviteeUserId: String
    ) async throws {
        let body: [String: String] = ["session": session, "inviteeUserId": inviteeUserId]
        let _: OKBody = try await post("api/collab/withdraw", accessToken: accessToken, body: body)
    }

    func joinByDescriptor(
        accessToken: String,
        session: String,
        relayURL: String?
    ) async throws -> CollaborationJoinResult {
        var body: [String: String] = ["session": session]
        if let relayURL { body["relayURL"] = relayURL }
        return try await post("api/collab/join", accessToken: accessToken, body: body)
    }

    func joinByCode(
        accessToken: String,
        code: String,
        shareSecret: String,
        relayURL: String?
    ) async throws -> CollaborationCodeJoinGrant {
        var body: [String: String] = ["code": code, "shareSecret": shareSecret]
        if let relayURL { body["relayURL"] = relayURL }
        return try await postJoin("api/collab/join", accessToken: accessToken, body: body)
    }

    func claimJoinRequest(
        accessToken: String,
        room: String,
        requestId: String
    ) async throws -> CollaborationCodeJoinGrant {
        try await postJoin(
            "api/collab/join-requests/claim",
            accessToken: accessToken,
            body: ["room": room, "requestId": requestId]
        )
    }

    func joinRequests(accessToken: String) async throws -> [CollaborationJoinApprovalRequest] {
        let body: JoinRequestsBody = try await get("api/collab/join-requests", accessToken: accessToken, query: [:])
        return body.requests
    }

    func approveJoinRequest(
        accessToken: String,
        requestId: String,
        approved: Bool
    ) async throws -> CollaborationJoinApprovalRequest {
        let body: JoinApprovalBody = try await postJSON(
            "api/collab/join-requests/approve",
            accessToken: accessToken,
            body: ["requestId": requestId, "approved": approved]
        )
        return body.request
    }

    // MARK: - Transport

    private func get<T: Decodable>(
        _ path: String,
        accessToken: String,
        query: [String: String]
    ) async throws -> T {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw CollaborationBackendError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw CollaborationBackendError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    private func post<T: Decodable>(
        _ path: String,
        accessToken: String,
        body: [String: String]
    ) async throws -> T {
        try await postJSON(path, accessToken: accessToken, body: body)
    }

    private func postJSON<T: Decodable>(
        _ path: String,
        accessToken: String,
        body: [String: Any]
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    private func postJoin(
        _ path: String,
        accessToken: String,
        body: [String: String]
    ) async throws -> CollaborationCodeJoinGrant {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CollaborationBackendError.http(status: -1, code: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw CollaborationBackendError.http(status: http.statusCode, code: code)
        }
        do {
            if http.statusCode == 202 {
                return .pending(try JSONDecoder().decode(CollaborationJoinRequestPending.self, from: data))
            }
            return .granted(try JSONDecoder().decode(CollaborationJoinResult.self, from: data))
        } catch {
            throw CollaborationBackendError.decoding
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CollaborationBackendError.http(status: -1, code: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw CollaborationBackendError.http(status: http.statusCode, code: code)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CollaborationBackendError.decoding
        }
    }
}
