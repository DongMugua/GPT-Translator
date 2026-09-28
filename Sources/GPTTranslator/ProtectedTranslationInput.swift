import Foundation

/// A request-local map: opaque tokens keep formulas and code out of the language
/// model's translation step. Nothing from one request is retained by the next.
struct ProtectedTranslationInput: Sendable {
    enum PreservationError: LocalizedError {
        case changedProtectedContent

        var errorDescription: String? {
            "翻译源未完整保留原文中的公式或代码，因此未显示可能缺失内容的结果。请重试或切换翻译源；也可以缩小选区或使用截图核对原文。"
        }
    }

    private struct Span {
        let range: NSRange
        let isMath: Bool
    }

    private struct Replacement: Sendable {
        let token: String
        let original: String
    }

    let originalText: String
    let text: String
    let hasTranslatableText: Bool
    private let replacements: [Replacement]
    private let tokenPrefix: String

    var hasProtectedContent: Bool { !replacements.isEmpty }

    init(text source: String, mode: TranslationMode = .translation) {
        originalText = source
        guard mode == .translation else {
            text = source
            replacements = []
            tokenPrefix = ""
            hasTranslatableText = true
            return
        }

        let sourceString = source as NSString
        var spans: [Span] = []
        func add(_ range: NSRange, math: Bool) {
            guard range.length > 0,
                  !spans.contains(where: { NSIntersectionRange($0.range, range).length > 0 }) else { return }
            spans.append(Span(range: range, isMath: math))
        }
        func addMatches(_ pattern: String, math: Bool) {
            for range in Self.matches(pattern, in: source) { add(range, math: math) }
        }

        // Process outer containers first so `$` inside source code is never
        // interpreted as a formula, and inline delimiters cannot split a block.
        addMatches(#"(?ms)^\s*(`{3,}|~{3,})[^\n]*\n.*?^\s*\1[ \t]*(?:\n|$)"#, math: false)
        addMatches(#"(?<!`)(`+)[^`\r\n]+\1(?!`)"#, math: false)
        addMatches(#"(?s)(?<!\\)\$\$.*?(?<!\\)\$\$"#, math: true)
        addMatches(#"(?s)\\\[.*?\\\]"#, math: true)
        addMatches(#"(?s)\\\(.*?\\\)"#, math: true)
        addMatches(#"(?<![\\$])\$(?!\$)(?:\\.|[^$\r\n])+?(?<!\\)\$(?![$\p{N}])"#, math: true)

        // A PDF's plain-text fallback can retain an entire equation line even
        // when its rich-text attributes are absent. Be conservative: ordinary
        // prose containing '=' must still be translated.
        for range in Self.matches(#"(?m)^[^\r\n]+$"#, in: source) {
            let line = sourceString.substring(with: range)
            if Self.isEquationLine(line) {
                let overlaps = spans.filter { NSIntersectionRange($0.range, range).length > 0 }
                // A complete equation can mix attributed $q^{*}$ with plain
                // Q(q,p). Protect the entire line, replacing its contained math
                // spans, but never absorb a code block or split multiline math.
                if overlaps.allSatisfy({ $0.isMath && NSIntersectionRange($0.range, range) == $0.range }) {
                    spans.removeAll { NSIntersectionRange($0.range, range).length > 0 }
                    add(range, math: true)
                }
            }
        }

        // Mathematical alphabet glyphs (𝑞, 𝒑, …) are variables, including when
        // the application exposes no attributed-string selection API.
        addMatches(#"[\x{1D400}-\x{1D7FF}ℂℍℕℙℚℝℤℬℰℱℋℒℳℛℎℓ]+(?:[∗*′″⁰¹²³⁴⁵⁶⁷⁸⁹₀₁₂₃₄₅₆₇₈₉]+)?"#, math: true)

        // Infer plain inline p/q references from the source equations. Never
        // blanket-protect every Latin letter: English articles and pronouns
        // still need translation. Explicit $a$ / $I$ remain fully protected.
        var variables = Set<String>()
        for span in spans where span.isMath {
            let normalized = Self.normalizeMathematicalAlphabet(sourceString.substring(with: span.range))
                .replacingOccurrences(of: #"\\[A-Za-z]+"#, with: " ", options: .regularExpression)
            for range in Self.matches(#"(?<![\p{L}\p{N}_])[A-Za-z\p{Greek}](?![\p{L}\p{N}])"#, in: normalized) {
                let variable = (normalized as NSString).substring(with: range)
                if !["a", "A", "i", "I"].contains(variable) { variables.insert(variable) }
            }
        }
        if !variables.isEmpty {
            let choices = variables.sorted().map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            let pattern = #"(?<![\p{L}\p{N}_])(?:"# + choices
                + #")(?:[_^](?:\{[^{}\r\n]+\}|[A-Za-z0-9*+\-])|[∗*′″⁰¹²³⁴⁵⁶⁷⁸⁹₀₁₂₃₄₅₆₇₈₉])*(?![\p{L}\p{N}_])"#
            addMatches(pattern, math: true)
        }

        // Numeric references are content identifiers, not words to translate.
        addMatches(#"\[\d+(?:[ \t]*[,;–—-][ \t]*\d+)*\]"#, math: false)
        spans.sort { $0.range.location < $1.range.location }
        let prefix = "ZXQKEEP" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        tokenPrefix = prefix
        let mutable = NSMutableString(string: source)
        replacements = spans.enumerated().map { index, span in
            Replacement(token: "\(prefix)N\(index)QXZ", original: sourceString.substring(with: span.range))
        }
        for (span, replacement) in zip(spans, replacements).reversed() {
            mutable.replaceCharacters(in: span.range, with: replacement.token)
        }
        text = mutable as String
        let prose = NSMutableString(string: source)
        for span in spans.reversed() { prose.replaceCharacters(in: span.range, with: "") }
        hasTranslatableText = spans.isEmpty || (prose as String).range(of: #"\p{L}"#, options: .regularExpression) != nil
    }

    /// Every token must occur exactly once. An omitted, duplicated or damaged
    /// token is a failed translation, rather than a silently lost equation.
    func restore(in output: String) throws -> String {
        guard hasProtectedContent else { return output }
        for replacement in replacements {
            guard output.components(separatedBy: replacement.token).count == 2 else {
                throw PreservationError.changedProtectedContent
            }
        }
        var restored = output
        for replacement in replacements {
            restored = restored.replacingOccurrences(of: replacement.token, with: replacement.original)
        }
        guard !restored.contains(tokenPrefix) else { throw PreservationError.changedProtectedContent }
        return restored
    }

    /// Fold only mathematical presentation letters/digits. Applying NFKC to
    /// the whole selection would also erase meaningful superscripts/subscripts.
    static func normalizeMathematicalAlphabet(_ text: String) -> String {
        let letterlike = Set("ℂℍℕℙℚℝℤℬℰℱℋℒℳℛℎℓ".unicodeScalars)
        return text.unicodeScalars.map { scalar in
            if (0x1D400...0x1D7FF).contains(scalar.value) || letterlike.contains(scalar) {
                return String(scalar).decomposedStringWithCompatibilityMapping
            }
            return String(scalar)
        }.joined()
    }

    private static func matches(_ pattern: String, in text: String) -> [NSRange] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range)
    }

    private static func isEquationLine(_ source: String) -> Bool {
        let line = normalizeMathematicalAlphabet(source).trimmingCharacters(in: .whitespaces)
        guard line.count <= 500,
              line.range(of: #"[=≈≃≅≠≤≥∈∉↦←→⇔⇒]"#, options: .regularExpression) != nil else { return false }
        let withoutCommands = line.replacingOccurrences(of: #"\\[A-Za-z]+"#, with: " ", options: .regularExpression)
        let words = matches(#"[\p{L}]{2,}"#, in: withoutCommands).map { (withoutCommands as NSString).substring(with: $0) }
        let mathFunctions: Set<String> = ["sin", "cos", "tan", "log", "ln", "exp", "max", "min", "sum", "lim", "arg", "det", "Pr", "mod"]
        return words.allSatisfy { mathFunctions.contains($0) }
            && line.range(of: #"[\p{L}\p{N}]"#, options: .regularExpression) != nil
    }
}
