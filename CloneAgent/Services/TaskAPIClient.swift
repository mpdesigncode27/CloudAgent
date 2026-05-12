import Foundation

final class TaskAPIClient {
    static let shared = TaskAPIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        decoder = d
        let e = JSONEncoder()
        e.keyEncodingStrategy = .useDefaultKeys
        encoder = e
    }

    func createTask(transcript: String) async throws -> APITask {
        let base = AppConfiguration.taskAPIBaseURL
        guard let url = URL(string: "/v1/tasks", relativeTo: base)?.absoluteURL else {
            throw TaskAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Encodable { let transcript: String }
        req.httpBody = try encoder.encode(Body(transcript: transcript))
        return try await send(req)
    }

    func getTask(id: UUID) async throws -> APITask {
        let base = AppConfiguration.taskAPIBaseURL
        guard let url = URL(string: "/v1/tasks/\(id.uuidString.lowercased())", relativeTo: base)?.absoluteURL else {
            throw TaskAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await send(req)
    }

    func confirmTask(id: UUID) async throws -> APITask {
        let base = AppConfiguration.taskAPIBaseURL
        guard let url = URL(string: "/v1/tasks/\(id.uuidString.lowercased())/confirm", relativeTo: base)?.absoluteURL else {
            throw TaskAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        return try await send(req)
    }

    private func send(_ request: URLRequest) async throws -> APITask {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TaskAPIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw TaskAPIError.badStatus(-1, nil as String?)
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw TaskAPIError.badStatus(http.statusCode, body)
        }
        do {
            return try decoder.decode(APITask.self, from: data)
        } catch {
            throw TaskAPIError.decodingFailed
        }
    }
}
