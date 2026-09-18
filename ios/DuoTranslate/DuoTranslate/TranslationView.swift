import SwiftUI

struct TranslationView: View {
    @EnvironmentObject private var viewModel: TranslationViewModel

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        header
                        LanguagePairCard()
                        statusRow
                        transcript
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 210)
                }
                .background(AppTheme.background.ignoresSafeArea())
                .onChange(of: viewModel.currentTurn) { _, _ in
                    withAnimation { proxy.scrollTo("live-turn", anchor: .bottom) }
                }
            }
            .overlay(alignment: .bottom) {
                FloatingMicControl()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("REALTIME TRANSLATION")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.muted)
                Text("同声翻译")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.ink)
            }
            Spacer()
        }
        .padding(.top, 12)
    }

    private var statusRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("LIVE INTERPRETATION")
                    .font(.caption2.bold())
                    .tracking(1.3)
                    .foregroundStyle(AppTheme.muted)
                Label(viewModel.phase.label, systemImage: "circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .symbolRenderingMode(.monochrome)
                    .tint(statusColor)
            }
            Spacer()
            Text("Realtime · 半双工")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.navy)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.blue.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var transcript: some View {
        if !viewModel.showTranscript || (viewModel.turns.isEmpty && viewModel.currentTurn == nil) {
            VStack(spacing: 14) {
                Image(systemName: "mic.and.signal.meter")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(AppTheme.blue)
                    .frame(width: 72, height: 72)
                    .background(AppTheme.blue.opacity(0.09), in: Circle())
                Text("准备好开始对话").font(.headline).foregroundStyle(AppTheme.ink)
                Text("点击下方按钮开始实时监听\n播放译音时会自动暂停收音")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 310)
        } else {
            ForEach(viewModel.turns) { turn in TranscriptTurnCard(turn: turn) }
            if let current = viewModel.currentTurn {
                TranscriptTurnCard(turn: current, pending: true).id("live-turn")
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.phase {
        case .listening: AppTheme.green
        case .playing: AppTheme.blue
        case .connecting: AppTheme.amber
        case .paused: AppTheme.amber
        case .failed: AppTheme.red
        case .idle: AppTheme.muted
        }
    }
}

private struct LanguagePairCard: View {
    @EnvironmentObject private var viewModel: TranslationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("LIVE LANGUAGE PAIR")
                    .font(.caption2.bold())
                    .tracking(1.7)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button("设置") { viewModel.isSettingsPresented = true }
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
            }

            HStack(spacing: 10) {
                languagePicker(title: "语言 1", selection: $viewModel.language1)
                Button(action: viewModel.swapLanguages) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 42, height: 42)
                        .foregroundStyle(AppTheme.navy)
                        .background(.white.opacity(0.9), in: Circle())
                }
                .disabled(viewModel.isSessionActive)
                languagePicker(title: "语言 2", selection: $viewModel.language2)
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [AppTheme.navy, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 28)
                .frame(width: 150, height: 150)
                .offset(x: 35, y: -55)
                .allowsHitTesting(false)
        }
        .shadow(color: AppTheme.navy.opacity(0.18), radius: 18, y: 10)
        .clipped()
    }

    private func languagePicker(title: String, selection: Binding<TranslationLanguage>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.72))
            Picker(title, selection: selection) {
                ForEach(TranslationLanguage.supported) { language in
                    Text(language.name).tag(language)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .padding(.horizontal, 10)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TranscriptTurnCard: View {
    let turn: TranscriptTurn
    var pending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(turn.sourceLanguage) → \(turn.targetLanguage)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.blue)
                Spacer()
                Text(turn.startedAt, style: .time).font(.caption).foregroundStyle(AppTheme.muted)
            }
            if !turn.source.isEmpty {
                Text(turn.source).font(.subheadline).foregroundStyle(AppTheme.muted)
            }
            Text(turn.target.isEmpty && pending ? "正在翻译…" : turn.target)
                .font(.body.weight(.semibold))
                .foregroundStyle(turn.target.isEmpty ? AppTheme.muted : AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.line))
        .shadow(color: AppTheme.navy.opacity(0.05), radius: 10, y: 5)
    }
}

private struct FloatingMicControl: View {
    @EnvironmentObject private var viewModel: TranslationViewModel
    @State private var holdProgress = 0.0
    @State private var longPressCompleted = false
    @State private var isHolding = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: glowColor.opacity(0.3), location: 0),
                            .init(color: glowColor.opacity(0.16), location: 0.45),
                            .init(color: glowColor.opacity(0.05), location: 0.72),
                            .init(color: .clear, location: 1)
                        ],
                        center: .center, startRadius: 0, endRadius: 72
                    ))
                    .frame(width: 144, height: 144)
                    .allowsHitTesting(false)
                Circle().fill(RadialGradient(
                    colors: [buttonColor.opacity(0.8), buttonColor],
                    center: .topLeading, startRadius: 0, endRadius: 86
                ))
                    .frame(width: 78, height: 78)
                    .shadow(color: buttonColor.opacity(0.18), radius: 10, y: 4)
                Image(systemName: isHolding ? "stop.fill" : (viewModel.phase == .idle ? "mic.fill" : "pause.fill"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(viewModel.phase == .paused ? AppTheme.navy : .white)
                // Only the hold-progress arc uses a circular stroke.
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(ringGradient(.orange.opacity(0.5)),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 96, height: 96)
                    .shadow(color: .orange.opacity(0.3), radius: 7)
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(Color(red: 1, green: 0.9, blue: 0.55),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 96, height: 96)
            }
            .frame(width: 108, height: 108)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 2, maximumDistance: 36) {
                longPressCompleted = true
                isHolding = false
                holdProgress = 0
                if viewModel.isSessionActive { viewModel.endSession() }
            } onPressingChanged: { pressing in
                if pressing {
                    longPressCompleted = false
                    isHolding = viewModel.isSessionActive
                    holdProgress = 0
                    if viewModel.isSessionActive {
                        withAnimation(.linear(duration: 2)) { holdProgress = 1 }
                    }
                } else {
                    isHolding = false
                    withAnimation(.easeOut(duration: 0.15)) { holdProgress = 0 }
                    if !longPressCompleted { viewModel.primaryAction() }
                }
            }

            Text(isHolding ? "继续按住，结束会话" : controlTitle)
                .font(.headline).foregroundStyle(isHolding ? AppTheme.red : AppTheme.ink)
            Text(isHolding ? "进度环走满即结束 · 提前松开为单击操作" : "单击暂停/继续，长按 2 秒结束会话")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var glowColor: Color { isHolding ? .orange : buttonColor }

    private func ringGradient(_ color: Color) -> RadialGradient {
        RadialGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: color.opacity(0.3), location: 0.22),
            .init(color: color, location: 0.5),
            .init(color: color.opacity(0.3), location: 0.78),
            .init(color: .clear, location: 1)
        ], center: .center, startRadius: 37, endRadius: 59)
    }

    private var buttonColor: Color {
        switch viewModel.phase {
        case .listening: AppTheme.red
        case .playing, .connecting: AppTheme.muted
        case .paused: AppTheme.pauseOrange
        case .idle, .failed: AppTheme.blue
        }
    }

    private var controlTitle: String {
        switch viewModel.phase {
        case .idle, .failed: "开始监听"
        case .paused: "继续翻译"
        case .listening: "暂停翻译"
        case .playing: "播放译音中"
        case .connecting: "正在连接"
        }
    }
}
