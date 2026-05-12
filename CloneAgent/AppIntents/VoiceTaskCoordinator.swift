import Foundation

@MainActor
enum VoiceTaskCoordinator {
    /// Set by `SubmitVoiceTaskIntent` before the app is brought to foreground.
    static var pendingTranscript: String?
}
