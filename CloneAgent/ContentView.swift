//
//  ContentView.swift
//  CloneAgent
//
//  Navigation + task creation (voice coordinator + demo).
//

import SwiftUI

private struct TaskRoute: Hashable {
    var id: UUID
    var transcript: String
}

struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var isCreating = false
    @State private var createError: String?

    private let demoTranscript = String(localized: "Baue eine kleine Landing Page für mein Portfolio.")

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        Task { await createTaskAndNavigate(transcript: demoTranscript) }
                    } label: {
                        Label(String(localized: "Neuen Auftrag (Demo-Text)"), systemImage: "plus.circle")
                    }
                    .disabled(isCreating)
                } header: {
                    Text(String(localized: "Auftrag"))
                } footer: {
                    Text(String(localized: "Siri: Kurzbefehl „Sprachauftrag senden“ mit Transkript. Backend-URL unter Build-Einstellung CloneAgentTaskAPIBaseURL."))
                }
            }
            .navigationTitle(String(localized: "CloneAgent"))
            .navigationDestination(for: TaskRoute.self) { route in
                TaskSummaryView(transcript: route.transcript, taskId: route.id)
            }
            .overlay {
                if isCreating {
                    ProgressView(String(localized: "Erstelle Auftrag …"))
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert(String(localized: "Fehler"), isPresented: Binding(
                get: { createError != nil },
                set: { if !$0 { createError = nil } },
            )) {
                Button(String(localized: "OK"), role: .cancel) { createError = nil }
            } message: {
                Text(createError ?? "")
            }
            .task { await consumePendingVoiceTranscript() }
        }
    }

    @MainActor
    private func createTaskAndNavigate(transcript: String) async {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            let task = try await TaskAPIClient.shared.createTask(transcript: trimmed)
            path.append(TaskRoute(id: task.id, transcript: trimmed))
        } catch {
            createError = (error as? LocalizedError)?.errorDescription ?? String(localized: "Auftrag konnte nicht erstellt werden.")
        }
    }

    @MainActor
    private func consumePendingVoiceTranscript() async {
        guard let pending = VoiceTaskCoordinator.pendingTranscript else { return }
        VoiceTaskCoordinator.pendingTranscript = nil
        await createTaskAndNavigate(transcript: pending)
    }
}

#Preview {
    ContentView()
}
