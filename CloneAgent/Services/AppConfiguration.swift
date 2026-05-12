import Foundation

enum AppConfiguration {
    /// Base URL for the task API (no trailing slash), e.g. `http://127.0.0.1:8787`.
    nonisolated static var taskAPIBaseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "CloneAgentTaskAPIBaseURL") as? String,
           let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.path = ""
            if let normalized = components.url {
                return normalized
            }
        }
        return URL(string: "http://127.0.0.1:8787")!
    }
}
