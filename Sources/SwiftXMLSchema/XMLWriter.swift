// MARK: - XMLWriter

/// A lightweight, indentation-aware XML string builder used by schema serializers.
struct XMLWriter {
    private var lines: [String] = []
    private var depth: Int = 0

    private var pad: String { String(repeating: "  ", count: depth) }

    private static func attrStr(_ attrs: [(String, String)]) -> String {
        attrs.map { " \($0.0)=\"\(xmlEscapeAttr($0.1))\"" }.joined()
    }

    mutating func line(_ raw: String) {
        lines.append(raw)
    }

    mutating func open(_ tag: String, attrs: [(String, String)] = []) {
        lines.append("\(pad)<\(tag)\(XMLWriter.attrStr(attrs))>")
        depth += 1
    }

    mutating func close(_ tag: String) {
        depth -= 1
        lines.append("\(pad)</\(tag)>")
    }

    mutating func selfClose(_ tag: String, attrs: [(String, String)] = []) {
        lines.append("\(pad)<\(tag)\(XMLWriter.attrStr(attrs))/>")
    }

    mutating func text(_ content: String) {
        lines.append("\(pad)\(xmlEscapeText(content))")
    }

    func build() -> String {
        lines.joined(separator: "\n") + "\n"
    }
}

// MARK: - XML escaping

func xmlEscapeAttr(_ str: String) -> String {
    str.replacingOccurrences(of: "&", with: "&amp;")
       .replacingOccurrences(of: "<", with: "&lt;")
       .replacingOccurrences(of: "\"", with: "&quot;")
}

func xmlEscapeText(_ str: String) -> String {
    str.replacingOccurrences(of: "&", with: "&amp;")
       .replacingOccurrences(of: "<", with: "&lt;")
       .replacingOccurrences(of: ">", with: "&gt;")
}
