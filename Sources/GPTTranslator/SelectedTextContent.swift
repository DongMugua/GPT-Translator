import AppKit
import ApplicationServices

/// Converts the selected range only into portable text before it leaves the
/// source app. No document, image attachment or remote resource is imported.
@MainActor
enum SelectedTextContent {
    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n\n")
            .replacingOccurrences(of: #"\x{00AD}[ \t]*\n[ \t]*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\u{00AD}", with: "")
    }

    static func fromRTF(_ data: Data, matching plainText: String?) -> String? {
        guard let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else { return nil }
        if let plainText, !matches(attributed.string, plainText) { return nil }
        return formatted(attributed)
    }

    static func matches(_ first: String, _ second: String) -> Bool {
        // Some applications use different line separators for AX and RTF.
        plain(first).trimmingCharacters(in: .whitespacesAndNewlines)
            == plain(second).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func formatted(_ text: NSAttributedString) -> String {
        guard text.length > 0 else { return "" }
        var hasScript = false
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, _, _ in
            hasScript = hasScript || ((attributes[.superscript] as? NSNumber)?.intValue ?? 0) != 0
                || ((attributes[.accessibilitySuperscript] as? NSNumber)?.intValue ?? 0) != 0
                || abs((attributes[.baselineOffset] as? NSNumber)?.doubleValue ?? 0) >= 1
        }
        // Styling a selected dictionary headword must not change its mode,
        // but a mathematical subscript such as q_i is not a headword.
        if !hasScript, TranslationMode.selectedWord(in: text.string) != nil { return plain(text.string) }
        let source = text.string as NSString
        var output = ""
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, range, _ in
            let value = plain(source.substring(with: range))
            let font = selectedFont(attributes)
            let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []
            let script = (attributes[.superscript] as? NSNumber)?.intValue
                ?? (attributes[.accessibilitySuperscript] as? NSNumber)?.intValue
                ?? 0
            let offset = (attributes[.baselineOffset] as? NSNumber)?.doubleValue ?? 0
            let effectiveScript = script != 0 ? script : (abs(offset) >= 1 ? (offset > 0 ? 1 : -1) : 0)

            // Keep line/paragraph separators outside style delimiters.
            output += value.components(separatedBy: "\n").map { line in
                let originalCore = line.trimmingCharacters(in: .whitespaces)
                guard !originalCore.isEmpty, let coreRange = line.range(of: originalCore) else { return line }
                let normalized = ProtectedTranslationInput.normalizeMathematicalAlphabet(originalCore)
                let isMathematicalLetter = normalized != originalCore && isSingleVariable(normalized)
                let core = originalCore
                let prefix = String(line[..<coreRange.lowerBound])
                let suffix = String(line[coreRange.upperBound...])
                let styled: String
                if effectiveScript != 0, core.count <= 16, !core.contains(" ") {
                    styled = (effectiveScript > 0 ? "^{" : "_{") + core + "}"
                } else if isSingleVariable(core), traits.contains(.italicFontMask) || isMathematicalLetter {
                    styled = "$\(core)$"
                } else if traits.contains(.boldFontMask), traits.contains(.italicFontMask) {
                    styled = "***\(core)***"
                } else if traits.contains(.boldFontMask) {
                    styled = "**\(core)**"
                } else if traits.contains(.italicFontMask) {
                    styled = "*\(core)*"
                } else {
                    styled = core
                }
                return prefix + styled + suffix
            }.joined(separator: "\n")
        }
        // An italic base and its raised/lowered run usually have different
        // fonts. Rejoin those runs into one protected mathematical expression.
        output = replacingMatches(in: output, pattern: #"\$([^$\n]+)\$((?:\^\{[^}\n]+\}|_\{[^}\n]+\})+)"#) { groups in
            "$\(groups[1])\(groups[2])$"
        }
        output = replacingMatches(in: output, pattern: #"(?<![\p{L}$])([A-Za-zΑ-Ωα-ω\x{1D400}-\x{1D7FF}ℂℍℕℙℚℝℤℬℰℱℋℒℳℛℎℓ])((?:\^\{[^}\n]+\}|_\{[^}\n]+\})+)(?!\$)"#) { groups in
            "$\(groups[1])\(groups[2])$"
        }
        return output
    }

    private static func selectedFont(_ attributes: [NSAttributedString.Key: Any]) -> NSFont? {
        if let font = attributes[.font] as? NSFont { return font }
        // AX attributed strings use their own font dictionary, not NSFont.
        guard let description = attributes[.accessibilityFont] as? [String: Any],
              let name = description[NSAccessibility.FontAttributeKey.fontName.rawValue] as? String else { return nil }
        let size = (description[NSAccessibility.FontAttributeKey.fontSize.rawValue] as? NSNumber)?.doubleValue ?? 12
        return NSFont(name: name, size: size)
    }

    private static func isSingleVariable(_ value: String) -> Bool {
        ProtectedTranslationInput.normalizeMathematicalAlphabet(value)
            .range(of: #"^[A-Za-zΑ-Ωα-ω]$"#, options: .regularExpression) != nil
    }

    private static func replacingMatches(in text: String, pattern: String, replacement: ([String]) -> String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let original = text as NSString
        let result = NSMutableString(string: text)
        for match in expression.matches(in: text, range: NSRange(location: 0, length: original.length)).reversed() {
            let groups = (0..<match.numberOfRanges).map { original.substring(with: match.range(at: $0)) }
            result.replaceCharacters(in: match.range, with: replacement(groups))
        }
        return result as String
    }
}
