import Foundation

enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case awaitingSummary = "awaiting_summary"
    case summaryReady = "summary_ready"
    case awaitingConfirmation = "awaiting_confirmation"
    case executing = "executing"
    case completed = "completed"
    case failed = "failed"
}

struct APITask: Codable, Equatable, Sendable {
    var id: UUID
    var status: TaskStatus
    var summaryMarkdown: String?
    var previewUrl: URL?
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date
    var remoteAgentId: String?
    var remoteRunIdPhase1: String?
    var remoteRunIdPhase2: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case summaryMarkdown
        case previewUrl
        case errorMessage
        case createdAt
        case updatedAt
        case remoteAgentId
        case remoteRunIdPhase1
        case remoteRunIdPhase2
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try c.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: idString) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Invalid UUID")
        }
        id = uuid
        status = try c.decode(TaskStatus.self, forKey: .status)
        summaryMarkdown = try c.decodeIfPresent(String.self, forKey: .summaryMarkdown)
        if let s = try c.decodeIfPresent(String.self, forKey: .previewUrl), !s.isEmpty {
            previewUrl = URL(string: s)
        } else {
            previewUrl = nil
        }
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
        let created = try c.decode(String.self, forKey: .createdAt)
        let updated = try c.decode(String.self, forKey: .updatedAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let cd = formatter.date(from: created) ?? ISO8601DateFormatter().date(from: created) {
            createdAt = cd
        } else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: c, debugDescription: "Invalid date")
        }
        if let ud = formatter.date(from: updated) ?? ISO8601DateFormatter().date(from: updated) {
            updatedAt = ud
        } else {
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: c, debugDescription: "Invalid date")
        }
        remoteAgentId = try c.decodeIfPresent(String.self, forKey: .remoteAgentId)
        remoteRunIdPhase1 = try c.decodeIfPresent(String.self, forKey: .remoteRunIdPhase1)
        remoteRunIdPhase2 = try c.decodeIfPresent(String.self, forKey: .remoteRunIdPhase2)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id.uuidString.lowercased(), forKey: .id)
        try c.encode(status.rawValue, forKey: .status)
        try c.encodeIfPresent(summaryMarkdown, forKey: .summaryMarkdown)
        try c.encodeIfPresent(previewUrl?.absoluteString, forKey: .previewUrl)
        try c.encodeIfPresent(errorMessage, forKey: .errorMessage)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try c.encode(formatter.string(from: createdAt), forKey: .createdAt)
        try c.encode(formatter.string(from: updatedAt), forKey: .updatedAt)
        try c.encodeIfPresent(remoteAgentId, forKey: .remoteAgentId)
        try c.encodeIfPresent(remoteRunIdPhase1, forKey: .remoteRunIdPhase1)
        try c.encodeIfPresent(remoteRunIdPhase2, forKey: .remoteRunIdPhase2)
    }
}

enum TaskAPIError: LocalizedError {
    case invalidURL
    case badStatus(Int, String?)
    case decodingFailed
    case transport(any Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "Ungültige Serveradresse.")
        case let .badStatus(code, _): String(localized: "Serverfehler (\(code)).")
        case .decodingFailed: String(localized: "Antwort konnte nicht gelesen werden.")
        case .transport(let error):
            (error as? LocalizedError)?.errorDescription ?? String(localized: "Netzwerkfehler.")
        }
    }
}
