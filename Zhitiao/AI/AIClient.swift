import Foundation
import UIKit

/// 模型接入：只做两件事——挑强调词、给插画主体。
///
/// 接口是 OpenAI 兼容格式（阿里云百炼的 `/compatible-mode/v1` 也可以）。
/// 地址、Key、模型名来自配置（Info.plist 或设置页），不写在代码里。
enum AIClient {

    struct Config: Codable, Equatable {
        var baseURL: String
        var apiKey: String
        var model: String
        var temperature: Double
        var maxTokens: Int
        var timeout: Double
        /// true 时不联网，用本地规则模拟模型
        var mock: Bool
        var systemPrompt: String

        static let `default` = Config(
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            apiKey: "",
            model: "qwen-plus",
            temperature: 0.8,
            maxTokens: 1024,
            timeout: 20,
            mock: true,
            systemPrompt: AIClient.defaultSystemPrompt
        )
    }

    struct Analysis: Equatable {
        var emphasis: [String] = []
        var illustrationSubjects: [String] = []
    }

    enum ClientError: LocalizedError {
        case missingConfig
        case badStatus(Int, String)
        case badJSON
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .missingConfig: return "还没有配置模型接口"
            case .badStatus(let code, let body): return "模型返回 \(code)：\(body.prefix(160))"
            case .badJSON: return "模型返回的不是 JSON"
            case .emptyResponse: return "模型返回里没有内容"
            }
        }
    }

    static let defaultSystemPrompt = """
    你是一个社交平台「文字卡片」的设计助手。用户会给你一段文字，你只需要做两件事：

    1. 强调词：从原文里挑出 1-3 个最值得被看见的词或短语。必须是原文里连续出现的片段，最长不超过 8 个字，不要整句话，不要改写。优先挑信息量最大的那个词。

    2. 插画主体：给出 3-5 个可以画出来的英文主体短语。每个是一个具体的可见物体（最多 6 个英文词），例如 a small potted plant、an open book、a cup of coffee。不要动作、场景、人物，也不要任何文字。文字类、清单类内容可以少给或不给。

    规则：
    - 不改写、不删减、不添加原文没有的信息。
    - 只输出 JSON，不要解释，不要 markdown 代码块。

    输出格式：
    {"emphasis":["注意力"],"illustrationSubjects":["a small potted plant","an open book"]}
    """

    // MARK: - 请求

    static func analyze(text: String, config: Config) async throws -> Analysis {
        if config.mock || config.apiKey.isEmpty {
            return mockAnalysis(text: text)
        }

        let url = URL(string: config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) + "/chat/completions")
        guard let url else { throw ClientError.missingConfig }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": config.model,
            "temperature": config.temperature,
            "max_tokens": config.maxTokens,
            "messages": [
                ["role": "system", "content": config.systemPrompt],
                ["role": "user", "content": String(text.prefix(4000))]
            ]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.badJSON }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.badStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let content = message?["content"] as? String, !content.isEmpty else {
            throw ClientError.emptyResponse
        }

        guard let parsed = extractJSON(content) else { throw ClientError.badJSON }
        return normalize(parsed, sourceText: text)
    }

    // MARK: - 解析与校验

    /// 从模型返回的文本里提取 JSON（可能带围栏或前后解释）
    static func extractJSON(_ raw: String) -> [String: Any]? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fence = text.range(of: "```") {
            let afterFence = text[fence.upperBound...]
            if let end = afterFence.range(of: "```") {
                text = String(afterFence[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            return nil
        }
        let slice = String(text[start...end])
        guard let data = slice.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// 逐字段校验：不合法的单独丢掉，不整体报错
    static func normalize(_ raw: [String: Any], sourceText: String) -> Analysis {
        let emphasis = (raw["emphasis"] as? [String] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 12 && sourceText.contains($0) }
            .prefix(3)

        let subjects = (raw["illustrationSubjects"] as? [String] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(5)

        return Analysis(emphasis: Array(emphasis), illustrationSubjects: Array(subjects))
    }

    // MARK: - 本地规则（没有 Key 或调试模式时）

    static func mockAnalysis(text: String) -> Analysis {
        let isList = text.range(of: #"(?m)^\s*[-*]"#, options: .regularExpression) != nil
        let isQuestion = text.contains("？") || text.contains("怎么") || text.contains("如何") || text.contains("为什么")
        let isCalm = ["慢", "安静", "呼吸", "睡觉", "休息", "独处", "失眠"].contains { text.contains($0) }

        // 强调词：优先 2-6 字的词，没有就用最长的一行当短语
        var words = text
            .replacingOccurrences(of: "[\\n\\r，,。.！!？?、；;：:]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 2 && $0.count <= 6 }
        if words.isEmpty {
            let longest = text.split(separator: "\n").map(String.init).max { $0.count < $1.count }
            if let longest, longest.count <= 10 { words = [longest] }
        }

        let subjects: [String]
        if isList {
            subjects = ["a small checklist notebook", "a pen resting on paper"]
        } else if isQuestion {
            subjects = ["a light bulb", "a magnifying glass"]
        } else if isCalm {
            subjects = ["a small leafy branch", "a simple sun shape", "a cup of tea"]
        } else {
            subjects = ["a small potted plant", "an open book", "a cup of coffee"]
        }

        return Analysis(emphasis: Array(words.prefix(2)), illustrationSubjects: subjects)
    }
}
