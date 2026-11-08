import Foundation

/// 切行：一行就是一行大字，太长的按标点再断。
func splitLines(_ text: String, maxChars: Int) -> [String] {
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

        var rest = line
        while rest.count > maxChars {
            var cut = -1
            let floor = max(1, Int(Double(maxChars) * 0.55))
            for index in stride(from: min(maxChars, rest.count - 1), through: floor, by: -1) {
                let character = rest[rest.index(rest.startIndex, offsetBy: index)]
                if "，。！？、；：,.!?;: ".contains(character) {
                    cut = index + 1
                    break
                }
            }
            if cut < 0 { cut = maxChars }
            out.append(String(rest.prefix(cut)).trimmingCharacters(in: .whitespaces))
            rest = String(rest.dropFirst(cut)).trimmingCharacters(in: .whitespaces)
        }
        if !rest.isEmpty { out.append(rest) }
    }

    return out
}
