import Foundation
import UIKit

/// 插画生成：主体由文本模型给，画面风格固定（彩色简笔画、简约）。
///
/// 图像模型返回的是别人的域名，直接画进画布会污染上下文导致无法导出，
/// 所以图先经自己的代理取回（`/image-proxy`）再落到本地。
enum IllustrationGenerator {

    struct Config: Codable, Equatable {
        /// 图像接口地址，例如 https://dashscope.aliyuncs.com/api/v1
        var baseURL: String
        var apiKey: String
        var model: String
        /// 取图用的代理地址，为空表示不经过代理
        var proxyURL: String
        var timeout: Double

        static let `default` = Config(
            baseURL: "https://dashscope.aliyuncs.com/api/v1",
            apiKey: "",
            model: "wan2.7-image",
            proxyURL: "",
            timeout: 90
        )
    }

    enum GeneratorError: LocalizedError {
        case noConfig
        case badStatus(Int)
        case noImage
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .noConfig: return "没有配置图像模型"
            case .badStatus(let code): return "图像接口返回 \(code)"
            case .noImage: return "图像接口没有返回图片"
            case .downloadFailed: return "图片下载失败"
            }
        }
    }

    /// 固定的风格模板：主体不同、风格一致
    static let styleTemplate = """
    a simple flat colorful doodle illustration of {subject},
    thick clean outlines, flat solid colors, muted pastel palette, limited colors,
    no shading, no gradient, no texture, single subject centered,
    generous white space around the subject, plain pure white background
    """

    static let negative = """
    no text, no letters, no watermark, no signature, no shadow, no gradient,
    no photorealism, no background scene, no extra objects, no cropped subject, no blurry edges
    """

    /// 生成一张插画；失败返回 nil，由调用方退回内置素材
    static func generate(subject: String, config: Config) async -> UIImage? {
        guard !config.apiKey.isEmpty else { return nil }

        let url = URL(string: config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            + "/services/aigc/multimodal-generation/generation")
        guard let url else { return nil }

        let prompt = styleTemplate.replacingOccurrences(of: "{subject}", with: subject) + ". " + negative

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": config.model,
            "input": ["messages": [["role": "user", "content": [["text": prompt]]]]],
            "parameters": ["size": "1024*1024"]
        ])

        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let output = json["output"] as? [String: Any],
            let choices = output["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? [[String: Any]],
            let imageURL = content.first?["image"] as? String,
            let remote = URL(string: imageURL)
        else { return nil }

        return await download(remote, config: config)
    }

    /// 取图：优先走自己的代理，避免跨域污染画布
    private static func download(_ remote: URL, config: Config) async -> UIImage? {
        if !config.proxyURL.isEmpty {
            let base = config.proxyURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            let encoded = remote.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let proxied = URL(string: base + "/image-proxy?url=" + encoded) {
                if let image = await fetchImage(proxied) { return image }
            }
        }
        return await fetchImage(remote)
    }

    private static func fetchImage(_ url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return UIImage(data: data)
    }
}
