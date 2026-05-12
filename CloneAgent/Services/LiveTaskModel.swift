import Combine
import Foundation
import SwiftUI

@MainActor
final class LiveTaskModel: ObservableObject {
    let taskId: UUID
    let transcript: String

    @Published private(set) var task: APITask?
    @Published private(set) var loadError: String?
    @Published private(set) var isConfirming = false

    private var pollTimer: AnyCancellable?

    init(taskId: UUID, transcript: String) {
        self.taskId = taskId
        self.transcript = transcript
    }

    func onAppear() {
        Task { await refresh() }
        startPollingIfNeeded()
    }

    func onDisappear() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    func refresh() async {
        loadError = nil
        do {
            let t = try await TaskAPIClient.shared.getTask(id: taskId)
            let previous = task?.status
            task = t
            if previous == .executing, t.status == .completed || t.status == .failed {
                TaskNotifications.notifyTaskTerminal(taskId: taskId, status: t.status)
            }
            if t.status == .executing {
                startPollingIfNeeded()
            } else {
                pollTimer?.cancel()
                pollTimer = nil
            }
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? String(localized: "Laden fehlgeschlagen.")
        }
    }

    func confirm() async {
        guard task?.status == .summaryReady || task?.status == .awaitingConfirmation else { return }
        isConfirming = true
        defer { isConfirming = false }
        loadError = nil
        do {
            let t = try await TaskAPIClient.shared.confirmTask(id: taskId)
            task = t
            if t.status == .completed || t.status == .failed {
                TaskNotifications.notifyTaskTerminal(taskId: taskId, status: t.status)
            }
            if t.status == .executing {
                startPollingIfNeeded()
            } else {
                pollTimer?.cancel()
                pollTimer = nil
            }
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? String(localized: "Bestätigung fehlgeschlagen.")
        }
    }

    private func startPollingIfNeeded() {
        guard task?.status == .executing else { return }
        pollTimer?.cancel()
        pollTimer = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refresh() }
            }
    }
}
