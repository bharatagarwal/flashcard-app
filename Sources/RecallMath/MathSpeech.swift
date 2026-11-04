import Foundation

/// Give VoiceOver words for natively typeset math, including nested fractions and powers.
public enum MathSpeech {
    public static func read(_ latex: String) -> String {
        var reader = Reader(characters: Array(latex))
        return reader.expression().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private struct Reader {
        let characters: [Character]
        var index = 0
        mutating func argument() -> String {
            while index < characters.count, characters[index].isWhitespace { index += 1 }
            guard index < characters.count else { return "" }
            if characters[index] == "{" {
                index += 1
                return expression(untilBrace: true)
            }
            return atom()
        }
        mutating func expression(untilBrace: Bool = false) -> String {
            var result = ""
            while index < characters.count {
                if characters[index] == "}", untilBrace {
                    index += 1
                    break
                }
                result += atom()
            }
            return result
        }
        mutating func atom() -> String {
            let character = characters[index]
            index += 1
            switch character {
            case "{": return expression(untilBrace: true)
            case "}": return ""
            case "^":
                let exponent = argument().trimmingCharacters(in: .whitespaces)
                return exponent == "prime" ? " prime " : " to the power \(exponent) end power "
            case "_": return " subscript \(argument()) end subscript "
            case "'": return " prime "
            case "=": return " equals "
            case "+": return " plus "
            case "-": return " minus "
            case "<": return " less than "
            case ">": return " greater than "
            case "\\":
                var command = ""
                while index < characters.count, characters[index].isLetter {
                    command.append(characters[index])
                    index += 1
                }
                if command.isEmpty {
                    guard index < characters.count else { return "" }
                    let escaped = characters[index]
                    index += 1
                    return [",", ";", "!", " ", "\\"].contains(escaped) ? " " : String(escaped)
                }
                switch command {
                case "frac", "dfrac", "tfrac":
                    let numerator = argument()
                    return " fraction \(numerator) over \(argument()) end fraction "
                case "sqrt": return " square root of \(argument()) end root "
                case "text", "mathrm", "mathbb", "mathbf", "operatorname": return argument()
                case "left", "right", "displaystyle", "textstyle": return ""
                case "quad", "qquad": return " "
                default:
                    let names = [
                        "ln": "natural log", "log": "log", "sin": "sine", "cos": "cosine",
                        "tan": "tangent", "prime": "prime", "cdot": "times", "times": "times",
                        "ne": "not equal to", "neq": "not equal to", "ge": "greater than or equal to",
                        "le": "less than or equal to", "pm": "plus or minus", "to": "approaches",
                        "in": "in", "mid": "divides", "nmid": "does not divide",
                        "setminus": "set difference", "varnothing": "empty set", "lor": "or",
                    ]
                    return " \(names[command] ?? command) "
                }
            default: return String(character)
            }
        }
    }
}
