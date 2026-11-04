import Foundation

/// The exchange format stays unchanged; only delimited math goes to the native typesetter.
public struct MathDocument: Equatable, Sendable {
    public enum Part: Equatable, Sendable {
        case text(String)
        case formula(String, display: Bool)
    }
    public let parts: [Part]

    public init(_ text: String) {
        var parts: [Part] = []
        var cursor = text.startIndex
        while cursor < text.endIndex {
            let rest = text[cursor...]
            guard let opening = rest.range(of: #"\\\(|\\\["#, options: .regularExpression) else {
                parts.append(.text(String(rest)))
                break
            }
            let display = text[opening] == #"\["#
            let closing = display ? #"\]"# : #"\)"#
            guard let end = text[opening.upperBound...].range(of: closing) else {
                parts.append(.text(String(rest)))
                break
            }
            if cursor < opening.lowerBound { parts.append(.text(String(text[cursor..<opening.lowerBound]))) }
            parts.append(.formula(String(text[opening.upperBound..<end.lowerBound]), display: display))
            cursor = end.upperBound
        }
        self.parts = parts
    }
}

extension MathDocument {
    /// Break only between top-level equalities/list entries, never inside a fraction or exponent.
    public static func equationFragments(_ latex: String) -> [String] {
        if latex.contains(#"\begin"#) || latex.contains(#"\left"#) { return [latex] }
        var depth = 0
        var escaped = false
        var current = ""
        var fragments: [String] = []
        for character in latex {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" {
                current.append(character)
                escaped = true
                continue
            }
            if "{([".contains(character) { depth += 1 }
            if "})]".contains(character) { depth = max(0, depth - 1) }
            if depth == 0, character == "=", !current.isEmpty {
                fragments.append(current)
                current = ""
            }
            current.append(character)
            if depth == 0, character == "," {
                fragments.append(current)
                current = ""
            }
        }
        if !current.isEmpty { fragments.append(current) }
        return fragments
    }
}
