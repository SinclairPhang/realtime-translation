import Combine
import Foundation

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var language1 = TranslationLanguage.chinese
    @Published var language2 = TranslationLanguage.french
    @Published var phase: TranslationPhase = .idle
    @Published var turns: [TranscriptTurn] = []
    @Published var currentTurn: TranscriptTurn?
    @Published var isSettingsPresented = false
    @Published var alertMessage: String?
    @Published var apiKey: String
    @Published var silenceDuration = 0.9
    @Published var autoResume = true
    @Published var showTranscript = true
    @Published var useSpeaker = true
    @Published var realtimeModel: RealtimeModel = .standard
    @Published var realtimeVoice: RealtimeVoice = .marin
    @Published var interpreterRole: InterpreterRole = .general
    @Published var isPreviewingVoice = false
    @Published var previewStatus = ""
    @Published var previewError: String?
    private var previewService: RealtimeTranslationService?
    private var previewTask: Task<Void, Never>?
    private var previewTimeout: Task<Void, Never>?
    private var previewID: UUID?

    let sessionStore: SessionStore
    private let realtime = RealtimeTranslationService()
    private var startedAt: Date?

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
        apiKey = KeychainStore.loadAPIKey()
        silenceDuration = UserDefaults.standard.object(forKey: "silenceDuration") as? Double ?? 0.9
        autoResume = UserDefaults.standard.object(forKey: "autoResume") as? Bool ?? true
        showTranscript = UserDefaults.standard.object(forKey: "showTranscript") as? Bool ?? true
        useSpeaker = UserDefaults.standard.object(forKey: "useSpeaker") as? Bool ?? true
        realtimeModel = RealtimeModel(rawValue: UserDefaults.standard.string(forKey: "realtimeModel") ?? "") ?? .standard
        realtimeVoice = RealtimeVoice(rawValue: UserDefaults.standard.string(forKey: "realtimeVoice") ?? "") ?? .marin
        interpreterRole = InterpreterRole(rawValue: UserDefaults.standard.string(forKey: "interpreterRole") ?? "") ?? .general
        realtime.onEvent = { [weak self] event in self?.handle(event) }
    }

    var isSessionActive: Bool {
        switch phase {
        case .idle, .failed: false
        default: true
        }
    }

    func primaryAction() {
        switch phase {
        case .idle, .failed:
            Task { await startSession() }
        case .paused:
            do {
                try realtime.resume()
                phase = .listening
            } catch {
                fail(error.localizedDescription)
            }
        case .listening, .playing, .connecting:
            realtime.pause()
            phase = .paused
        }
    }

    func startSession() async {
        stopVoicePreview()
        await previewTask?.value
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            alertMessage = "请先在设置中保存 OpenAI API Key"
            isSettingsPresented = true
            return
        }
        guard language1 != language2 else {
            alertMessage = "请选择两种不同的语言"
            return
        }

        phase = .connecting
        turns = []
        currentTurn = nil
        startedAt = Date()
        do {
            try await realtime.connect(
                apiKey: key,
                language1: language1,
                language2: language2,
                silenceDurationMilliseconds: Int(silenceDuration * 1_000),
                useSpeaker: useSpeaker,
                model: realtimeModel,
                voice: realtimeVoice,
                role: interpreterRole
            )
        } catch {
            fail(error.localizedDescription)
        }
    }

    func endSession() {
        realtime.disconnect()
        commitCurrentTurn()
        if let startedAt, !turns.isEmpty {
            sessionStore.add(
                ConversationSession(
                    startedAt: startedAt,
                    endedAt: Date(),
                    turns: turns,
                    summary: nil
                )
            )
        }
        self.startedAt = nil
        phase = .idle
    }

    func swapLanguages() {
        guard !isSessionActive else { return }
        (language1, language2) = (language2, language1)
    }

    func saveSettings() async {
        stopVoicePreview()
        await previewTask?.value
        do {
            try await realtime.setSpeakerOutput(useSpeaker)
            try KeychainStore.saveAPIKey(apiKey)
            UserDefaults.standard.set(silenceDuration, forKey: "silenceDuration")
            UserDefaults.standard.set(autoResume, forKey: "autoResume")
            UserDefaults.standard.set(showTranscript, forKey: "showTranscript")
            UserDefaults.standard.set(useSpeaker, forKey: "useSpeaker")
            UserDefaults.standard.set(realtimeModel.rawValue, forKey: "realtimeModel")
            UserDefaults.standard.set(realtimeVoice.rawValue, forKey: "realtimeVoice")
            UserDefaults.standard.set(interpreterRole.rawValue, forKey: "interpreterRole")
            isSettingsPresented = false
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func clearCurrentTranscript() {
        turns = []
        currentTurn = nil
    }

    func previewVoice() {
        guard !isSessionActive else { return }
        if isPreviewingVoice { stopVoicePreview(); return }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            previewError = "请先填写 API Key，再试听音色。"
            return
        }
        let id = UUID()
        let service = RealtimeTranslationService()
        previewService = service
        previewID = id
        isPreviewingVoice = true
        previewStatus = "正在生成试听…"
        previewError = nil
        service.onEvent = { [weak self] event in
            guard let self, self.previewID == id else { return }
            switch event {
            case .playbackStarted: self.previewStatus = "正在试听"
            case .playbackEnded: self.stopVoicePreview()
            case .failure(let message):
                self.stopVoicePreview()
                self.previewError = message
            default: break
            }
        }
        let model = realtimeModel
        let voice = realtimeVoice
        let speaker = useSpeaker
        let previousTask = previewTask
        previewTask = Task { [weak self] in
            do {
                await previousTask?.value
                try Task.checkCancellation()
                try await service.connect(
                    apiKey: key, language1: .chinese, language2: .french,
                    silenceDurationMilliseconds: 900, useSpeaker: speaker,
                    model: model, voice: voice, previewOnly: true
                )
            } catch {
                service.disconnect()
                guard let self, self.previewID == id else { return }
                self.stopVoicePreview()
                if !(error is CancellationError) { self.previewError = error.localizedDescription }
            }
        }
        previewTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, self.previewID == id else { return }
            self.stopVoicePreview()
            self.previewError = "试听超时，请检查网络后重试。"
        }
    }

    func stopVoicePreview() {
        previewID = nil
        previewTask?.cancel()
        previewTimeout?.cancel()
        previewTimeout = nil
        previewService?.onEvent = nil
        previewService?.disconnect()
        previewService = nil
        isPreviewingVoice = false
        previewStatus = ""
    }

    private func handle(_ event: RealtimeTranslationEvent) {
        switch event {
        case .connected, .listening:
            if phase != .paused { phase = .listening }
        case .playbackStarted:
            if phase != .paused { phase = .playing }
        case .playbackEnded:
            commitCurrentTurn()
            if phase != .paused { phase = autoResume ? .listening : .paused }
            if !autoResume { realtime.pause() }
        case .sourceDelta(let delta):
            mutateCurrentTurn { $0.source += delta }
        case .sourceCompleted(let text):
            mutateCurrentTurn { $0.source = text }
        case .targetDelta(let delta):
            mutateCurrentTurn { $0.target += delta }
        case .targetCompleted(let text):
            mutateCurrentTurn { $0.target = text }
        case .failure(let message):
            fail(message)
        }
    }

    private func mutateCurrentTurn(_ mutation: (inout TranscriptTurn) -> Void) {
        var turn = currentTurn ?? TranscriptTurn(
            sourceLanguage: language1.name,
            targetLanguage: language2.name
        )
        mutation(&turn)
        updateDetectedDirection(&turn)
        currentTurn = turn
    }

    private func updateDetectedDirection(_ turn: inout TranscriptTurn) {
        guard !turn.source.isEmpty else { return }
        let containsHan = turn.source.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(Int(scalar.value)) ||
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
        let source = containsHan
            ? TranslationLanguage.supported.first(where: { $0.code == "zh" })
            : TranslationLanguage.supported.first(where: { $0.code == "fr" })
        guard let source else { return }
        let target = source == language1 ? language2 : language1
        turn.sourceLanguage = source.name
        turn.targetLanguage = target.name
    }

    private func commitCurrentTurn() {
        guard let currentTurn, !currentTurn.source.isEmpty || !currentTurn.target.isEmpty else {
            self.currentTurn = nil
            return
        }
        turns.append(currentTurn)
        self.currentTurn = nil
    }

    private func fail(_ message: String) {
        realtime.disconnect()
        phase = .failed(message)
        alertMessage = message
    }
}
