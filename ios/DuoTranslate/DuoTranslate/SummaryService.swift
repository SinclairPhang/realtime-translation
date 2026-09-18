import Foundation

enum SummaryService {
    static func generate(for session: ConversationSession, apiKey: String) async throws -> SessionSummary {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "overview": ["type": "string"],
                "key_points": ["type": "array", "items": ["type": "string"]],
                "decisions": ["type": "array", "items": ["type": "string"]],
                "action_items": ["type": "array", "items": ["type": "string"]]
            ],
            "required": ["title", "overview", "key_points", "decisions", "action_items"],
            "additionalProperties": false
        ]
        let body: [String: Any] = [
            "model": "gpt-4.1-mini",
            "store": false,
            "instructions": "只根据对话文本生成简洁、忠实的中文纪要。不要添加原文没有的信息。没有内容的项目返回空数组。",
            "input": ExportBuilder.transcriptText(session),
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "conversation_summary",
                    "strict": true,
                    "schema": schema
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("duo-translate-ios", forHTTPHeaderField: "OpenAI-Safety-Identifier")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }?["message"] as? String
            throw SummaryError.requestFailed(message ?? "纪要生成失败")
        }
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SummaryError.invalidResponse
        }
        let outputText = extractOutputText(payload)
        guard let summaryData = outputText.data(using: .utf8) else { throw SummaryError.invalidResponse }
        return try JSONDecoder().decode(SessionSummary.self, from: summaryData)
    }

    private static func extractOutputText(_ payload: [String: Any]) -> String {
        if let direct = payload["output_text"] as? String { return direct }
        guard let output = payload["output"] as? [[String: Any]] else { return "" }
        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            if let text = content.first(where: { $0["type"] as? String == "output_text" })?["text"] as? String {
                return text
            }
        }
        return ""
    }
}

enum SummaryError: LocalizedError {
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message): message
        case .invalidResponse: "模型没有返回有效纪要"
        }
    }
}

enum ExportBuilder {
    static func transcriptText(_ session: ConversationSession) -> String {
        var lines = [
            "Duo Translate 完整对话文本",
            "会话时间：\(session.startedAt.formatted(date: .numeric, time: .shortened))",
            "对话轮数：\(session.turns.count)",
            ""
        ]
        for (index, turn) in session.turns.enumerated() {
            lines.append("第 \(index + 1) 轮 · \(turn.startedAt.formatted(date: .omitted, time: .shortened)) · \(turn.sourceLanguage) → \(turn.targetLanguage)")
            if !turn.source.isEmpty { lines.append("原文：\(turn.source)") }
            if !turn.target.isEmpty { lines.append("译文：\(turn.target)") }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static func summaryText(_ summary: SessionSummary) -> String {
        var lines = ["Duo Translate 会话纪要", "", "主题：\(summary.title)", "", "概览", summary.overview, ""]
        append("关键要点", items: summary.keyPoints, to: &lines)
        append("决定事项", items: summary.decisions, to: &lines)
        append("待跟进事项", items: summary.actionItems, to: &lines)
        return lines.joined(separator: "\n")
    }

    static func fileURL(name: String, contents: String) -> URL {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
        try? Data(contents.utf8).write(to: url, options: .atomic)
        return url
    }

    private static func append(_ title: String, items: [String], to lines: inout [String]) {
        guard !items.isEmpty else { return }
        lines.append(title)
        lines.append(contentsOf: items.map { "• \($0)" })
        lines.append("")
    }
}

