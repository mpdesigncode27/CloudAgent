//
//  TaskSummaryView.swift
//  CloneAgent
//
//  Live task UI backed by `TaskAPIClient` + `LiveTaskModel` (specs/001-voice-cursor-tasks).
//

import SwiftUI

struct TaskSummaryView: View {
    let transcript: String
    let taskId: UUID

    @StateObject private var model: LiveTaskModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previewURL: URL?
    @State private var showSafari = false

    init(transcript: String, taskId: UUID) {
        self.transcript = transcript
        self.taskId = taskId
        _model = StateObject(wrappedValue: LiveTaskModel(taskId: taskId, transcript: transcript))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                statusHeader
                if let err = model.loadError {
                    errorBanner(err)
                }
                if let t = model.task {
                    summaryCard(markdown: t.summaryMarkdown ?? "")
                    if t.status == .completed, let url = t.previewUrl {
                        previewButton(url: url)
                    }
                    if t.status == .failed, let em = t.errorMessage {
                        failedCallout(em)
                    }
                } else if model.loadError == nil {
                    loadingBlock
                }
            }
            .screenHorizontalPadding()
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
        .navigationTitle(String(localized: "Auftrag"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomChrome }
        .refreshable { await model.refresh() }
        .onAppear {
            model.onAppear()
            Task { await TaskNotifications.requestAuthorizationIfNeeded() }
        }
        .onDisappear { model.onDisappear() }
        .sheet(isPresented: $showSafari) {
            if let previewURL {
                PreviewWebView(url: previewURL)
                    .ignoresSafeArea()
            }
        }
    }

    private var statusHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: statusSymbol)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(statusTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(transcript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Auftragsstatus"))
        .accessibilityValue("\(statusTitle). \(transcript)")
    }

    private var statusSymbol: String {
        guard let s = model.task?.status else { return "ellipsis.circle" }
        switch s {
        case .awaitingSummary, .summaryReady, .awaitingConfirmation:
            return "text.bubble"
        case .executing:
            return "hammer"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusTitle: String {
        guard let s = model.task?.status else { return String(localized: "Laden …") }
        switch s {
        case .awaitingSummary:
            return String(localized: "Zusammenfassung wird erstellt …")
        case .summaryReady, .awaitingConfirmation:
            return String(localized: "Bereit zur Bestätigung")
        case .executing:
            return String(localized: "Wird umgesetzt …")
        case .completed:
            return String(localized: "Fertig")
        case .failed:
            return String(localized: "Fehlgeschlagen")
        }
    }

    private var loadingBlock: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
            Text(String(localized: "Auftrag wird geladen …"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xl)
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.button, style: .continuous).fill(Color.red.opacity(0.12)))
    }

    private func summaryCard(markdown: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(String(localized: "Zusammenfassung"))
                .font(.headline)
            markdownText(markdown)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .readableContentWidth()
        .adaptiveGlassCard()
    }

    private func previewButton(url: URL) -> some View {
        Button {
            previewURL = url
            showSafari = true
        } label: {
            Label(String(localized: "Vorschau im Web"), systemImage: "safari")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .adaptiveSecondaryButtonStyle()
        .accessibilityHint(String(localized: "Öffnet die Ergebnis-URL"))
    }

    private func failedCallout(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.button, style: .continuous).fill(Color.orange.opacity(0.12)))
    }

    @ViewBuilder
    private var bottomChrome: some View {
        AdaptiveGlassChrome(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                if let s = model.task?.status, (s == .summaryReady || s == .awaitingConfirmation) {
                    Button(String(localized: "Umsetzen")) {
                        Task { await model.confirm() }
                    }
                    .adaptivePrimaryButtonStyle()
                    .frame(maxWidth: .infinity)
                    .disabled(model.isConfirming)
                } else if model.task?.status == .executing {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.accentColor)
                        .accessibilityLabel(String(localized: "Ausführung läuft"))
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.sm)
    }

    @ViewBuilder
    private func markdownText(_ raw: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: raw,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(raw)
                .font(.body)
        }
    }
}

#Preview("Live shell") {
    NavigationStack {
        TaskSummaryView(
            transcript: "Demo transcript",
            taskId: UUID()
        )
    }
}
