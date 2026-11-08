import Foundation

/// 把正文切成「用户写的行」：按换行切，去掉 # - > 这些标记。
///
/// 注意：这里**不按字数硬断**。折行完全由渲染器按当前字号和卡片宽度决定
/// （见 `Renderer.wrap`）。字号小的时候一行能放更多字，字号大就折得更碎，
/// 按字数硬断会让小字号下面一行只用掉一半宽度。
func splitLines(_ text: String) -> [String] {
    var out: [String] = []

    for raw in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
        var line = raw.trimmingCharacters(in: .whitespaces)
        line = line.replacingOccurrences(
            of: #"^(#{1,6}\s+|[-*+]\s+|>\s?)"#,
            with: "",
            options: .regularExpression
        )
        line = line.replacingOccurrences(
            of: #"\*\*(.+?)\*\*|==(.+?)==|~~(.+?)~~"#,
            with: "$1$2$3",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespaces)

        if line.isEmpty { continue }
        out.append(line)
    }

    return out
}
