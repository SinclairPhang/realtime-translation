import Foundation

enum RealtimeModel: String, CaseIterable, Identifiable, Sendable {
    case standard = "gpt-realtime-2.1"
    case mini = "gpt-realtime-2.1-mini"
    var id: String { rawValue }
    var title: String { self == .standard ? "Realtime 2.1" : "Realtime 2.1 Mini" }
}

enum RealtimeVoice: String, CaseIterable, Identifiable, Sendable {
    case marin, cedar, alloy, ash, ballad, coral, echo, sage, shimmer, verse
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum InterpreterRole: String, CaseIterable, Identifiable, Sendable {
    case general, business, engineering, everyday
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "通用翻译"
        case .business: "商务会议"
        case .engineering: "工程现场"
        case .everyday: "日常交流"
        }
    }
    var detail: String {
        switch self {
        case .general: "自然、忠实地表达原意。"
        case .business: "正式得体，准确表达商务与会议用语。"
        case .engineering: "注重设备、工序、单位与安全术语。"
        case .everyday: "自然口语化，适合日常对话。"
        }
    }
    var instruction: String {
        switch self {
        case .general: "Use neutral, natural phrasing faithful to the speaker's register."
        case .business: "Use professional business and meeting terminology when appropriate. Preserve commitments and levels of certainty exactly."
        case .engineering: "Use precise engineering and construction terminology when appropriate. Preserve equipment names, measurements, units and safety instructions exactly."
        case .everyday: "Use natural conversational phrasing while preserving the speaker's meaning and tone."
        }
    }
}

struct TranslationLanguage: Identifiable, Codable, Hashable, Sendable {
    let code: String
    let name: String
    let localeIdentifier: String

    var id: String { code }

    static let chinese = TranslationLanguage(code: "zh", name: "中文", localeIdentifier: "zh-CN")
    static let french = TranslationLanguage(code: "fr", name: "Français", localeIdentifier: "fr-FR")
    static let supported: [TranslationLanguage] = [.chinese, .french]
}

struct TranscriptTurn: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var source = ""
    var target = ""
    var startedAt = Date()
    var sourceLanguage = ""
    var targetLanguage = ""
}

struct SessionSummary: Codable, Hashable, Sendable {
    var title: String
    var overview: String
    var keyPoints: [String]
    var decisions: [String]
    var actionItems: [String]

    enum CodingKeys: String, CodingKey {
        case title, overview, decisions
        case keyPoints = "key_points"
        case actionItems = "action_items"
    }
}

struct ConversationSession: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date
    var turns: [TranscriptTurn]
    var summary: SessionSummary?

    var languagePair: String {
        guard let first = turns.first else { return "双语翻译" }
        return "\(first.sourceLanguage) ⇄ \(first.targetLanguage)"
    }
}

enum TranslationPhase: Equatable, Sendable {
    case idle
    case connecting
    case listening
    case playing
    case paused
    case failed(String)

    var label: String {
        switch self {
        case .idle: "准备开始"
        case .connecting: "正在连接"
        case .listening: "正在聆听"
        case .playing: "播放译音中"
        case .paused: "已暂停"
        case .failed: "连接异常"
        }
    }
}

enum AppTab: Hashable {
    case translation
    case records
}
