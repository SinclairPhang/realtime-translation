import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    archiveHero
                    HStack {
                        Text("历史会话").font(.headline)
                        Spacer()
                        Text("\(sessionStore.sessions.count) 个会话")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.horizontal, 3)

                    if sessionStore.sessions.isEmpty {
                        ContentUnavailableView(
                            "暂无会话记录",
                            systemImage: "text.bubble",
                            description: Text("结束一次翻译会话后，记录会显示在这里。")
                        )
                        .frame(minHeight: 300)
                    } else {
                        ForEach(sessionStore.sessions) { session in
                            NavigationLink(value: session.id) { SessionRow(session: session) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationDestination(for: UUID.self) { id in
                if let session = sessionStore.sessions.first(where: { $0.id == id }) {
                    RecordDetailView(session: session)
                }
            }
            .navigationTitle("记录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var archiveHero: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("SESSION ARCHIVE").font(.caption2.bold()).tracking(1.7).foregroundStyle(.white.opacity(0.68))
            Text("翻译记录").font(.title2.bold()).foregroundStyle(.white)
            Text("查看每次会话的完整转录与导出文件").font(.caption).foregroundStyle(.white.opacity(0.74))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            LinearGradient(colors: [AppTheme.navy, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(alignment: .topTrailing) {
            Circle().stroke(.white.opacity(0.10), lineWidth: 24).frame(width: 110, height: 110).offset(x: 24, y: -34)
        }
        .clipped()
    }
}

private struct SessionRow: View {
    let session: ConversationSession

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "waveform")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.blue)
                .frame(width: 46, height: 46)
                .background(AppTheme.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text("\(session.turns.count) 轮对话 · \(session.languagePair)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(AppTheme.muted)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.line))
    }
}

struct RecordDetailView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var viewModel: TranslationViewModel
    let session: ConversationSession

    @State private var summary: SessionSummary?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    init(session: ConversationSession) {
        self.session = session
        _summary = State(initialValue: session.summary)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                detailHeader
                actionButtons
                if let summary { SummaryCard(summary: summary) }
                ForEach(session.turns) { turn in TranscriptDetailCard(turn: turn) }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("会话详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("无法生成纪要", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("知道了", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("SESSION DETAIL").font(.caption2.bold()).tracking(1.5).foregroundStyle(AppTheme.muted)
            Text(session.startedAt.formatted(date: .long, time: .shortened)).font(.title3.bold()).foregroundStyle(AppTheme.ink)
            Text("\(session.turns.count) 轮对话 · \(session.languagePair)").font(.caption).foregroundStyle(AppTheme.muted)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 9) {
            if let summary {
                ShareLink(
                    item: ExportBuilder.fileURL(
                        name: "duo-translate-summary-\(session.id.uuidString).txt",
                        contents: ExportBuilder.summaryText(summary)
                    )
                ) {
                    actionLabel("导出纪要", icon: "square.and.arrow.up")
                }
            } else {
                Button { Task { await generateSummary() } } label: {
                    actionLabel(isGenerating ? "正在生成纪要…" : "生成纪要", icon: "sparkles")
                }
                .disabled(isGenerating)
            }

            ShareLink(
                item: ExportBuilder.fileURL(
                    name: "duo-translate-transcript-\(session.id.uuidString).txt",
                    contents: ExportBuilder.transcriptText(session)
                )
            ) {
                actionLabel("导出完整文本", icon: "doc.text")
            }
        }
    }

    private func actionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(AppTheme.navy)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.line))
    }

    private func generateSummary() async {
        let key = viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            errorMessage = "请先在翻译页设置 OpenAI API Key"
            return
        }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let result = try await SummaryService.generate(for: session, apiKey: key)
            summary = result
            sessionStore.updateSummary(sessionID: session.id, summary: result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TranscriptDetailCard: View {
    let turn: TranscriptTurn

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(turn.startedAt.formatted(date: .omitted, time: .shortened)) · \(turn.sourceLanguage) → \(turn.targetLanguage)")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.blue)
            Text(turn.source.isEmpty ? "（未识别到原文）" : turn.source)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
            Text(turn.target.isEmpty ? "（未生成译文）" : turn.target)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(AppTheme.line))
    }
}

private struct SummaryCard: View {
    let summary: SessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary.title).font(.headline).foregroundStyle(AppTheme.ink)
            Text(summary.overview).font(.subheadline).foregroundStyle(AppTheme.muted)
            summarySection("关键要点", summary.keyPoints)
            summarySection("决定事项", summary.decisions)
            summarySection("待跟进事项", summary.actionItems)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func summarySection(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.caption.bold()).foregroundStyle(AppTheme.blue)
                ForEach(items, id: \.self) { Text("• \($0)").font(.subheadline).foregroundStyle(AppTheme.ink) }
            }
        }
    }
}

