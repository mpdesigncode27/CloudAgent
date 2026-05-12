import AppIntents

struct SubmitVoiceTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Sprachauftrag senden"
    static var description = IntentDescription("Übergibt den erkannten Text an CloneAgent.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Transkript")
    var transcript: String

    init() {
        transcript = ""
    }

    init(transcript: String) {
        self.transcript = transcript
    }

    func perform() async throws -> some IntentResult {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run {
            VoiceTaskCoordinator.pendingTranscript = trimmed.isEmpty ? nil : trimmed
        }
        return .result()
    }
}

struct SubmitVoiceTaskShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SubmitVoiceTaskIntent(),
            phrases: [
                "Sprachauftrag in \(.applicationName)",
                "Auftrag an \(.applicationName)",
            ],
            shortTitle: "Sprachauftrag",
            systemImageName: "mic.badge.plus",
        )
    }
}
