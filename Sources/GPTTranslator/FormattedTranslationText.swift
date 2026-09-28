import AppKit
import SwiftUI

/// A selectable document with an intrinsic height at the width supplied by its parent.
/// Its enclosing result view owns scrolling; this view never adds a second scroll area.
struct FormattedTranslationText: NSViewRepresentable {
    let text: String
    let fontSize: CGFloat

    func makeNSView(context: Context) -> TranslationDocumentTextView {
        let view = TranslationDocumentTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.heightTracksTextView = false
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = false
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateNSView(_ nsView: TranslationDocumentTextView, context: Context) {
        nsView.setDocument(text, fontSize: fontSize)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: TranslationDocumentTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? (nsView.bounds.width > 0 ? nsView.bounds.width : 320)
        return nsView.documentSize(at: width)
    }
}

final class TranslationDocumentTextView: NSTextView {
    private var renderedText: String?
    private var renderedFontSize: CGFloat?

    func setDocument(_ text: String, fontSize: CGFloat) {
        guard text != renderedText || fontSize != renderedFontSize else { return }
        renderedText = text
        renderedFontSize = fontSize
        textStorage?.setAttributedString(FormattedTranslationRenderer.attributedString(text: text, fontSize: fontSize))
        invalidateIntrinsicContentSize()
    }

    func documentSize(at proposedWidth: CGFloat) -> CGSize {
        let width = max(1, proposedWidth.isFinite ? proposedWidth : 320)
        guard let textContainer, let layoutManager else { return CGSize(width: width, height: 1) }
        // TextKit must measure with the same width that SwiftUI will display, including
        // during streaming updates. Measuring an unconstrained text view causes jumps.
        if frame.width != width {
            setFrameSize(NSSize(width: width, height: max(1, frame.height)))
        }
        textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = max(layoutManager.usedRect(for: textContainer).maxY,
                             layoutManager.extraLineFragmentUsedRect.maxY)
        return CGSize(width: width, height: max(1, ceil(usedHeight)))
    }
}

@MainActor
enum FormattedTranslationRenderer {
    private struct Literal {
        let token: String
        let original: String
        let mathBody: String?
    }

    static func attributedString(text: String, fontSize: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var fence: String?
        var displayMathEnd: String?
        var displayMathLines: [String] = []
        var hasOutputLine = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let activeFence = fence {
                if trimmed.hasPrefix(activeFence), trimmed.dropFirst(activeFence.count).allSatisfy({ $0 == "`" || $0 == "~" || $0.isWhitespace }) {
                    fence = nil
                    continue
                }
                appendLine(literal(line, fontSize: fontSize), to: result, hasOutputLine: &hasOutputLine, fontSize: fontSize)
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = trimmed.first!
                fence = String(trimmed.prefix(while: { $0 == marker }))
                continue
            }
            if let end = displayMathEnd {
                displayMathLines.append(line)
                if trimmed.hasSuffix(end) {
                    let original = displayMathLines.joined(separator: "\n")
                    let body = String(original.trimmingCharacters(in: .whitespaces).dropFirst(2).dropLast(2))
                        .trimmingCharacters(in: .newlines)
                    appendLine(simpleMath(body, fontSize: fontSize) ?? literal(original, fontSize: fontSize),
                               to: result, hasOutputLine: &hasOutputLine, fontSize: fontSize)
                    displayMathEnd = nil
                    displayMathLines = []
                }
                continue
            }
            if (trimmed.hasPrefix("$$") && !trimmed.dropFirst(2).contains("$$")) ||
                (trimmed.hasPrefix("\\[") && !trimmed.dropFirst(2).contains("\\]")) {
                displayMathEnd = trimmed.hasPrefix("$$") ? "$$" : "\\]"
                displayMathLines = [trimmed]
                continue
            }
            if trimmed.hasPrefix("|") && trimmed.dropFirst().contains("|") {
                appendLine(literal(line, fontSize: fontSize), to: result, hasOutputLine: &hasOutputLine, fontSize: fontSize)
                continue
            }

            var content = line
            var headingLevel = 0
            let hashes = trimmed.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), trimmed.dropFirst(hashes).first == " " {
                headingLevel = hashes
                content = String(trimmed.dropFirst(hashes + 1))
            }
            let pointSize = headingLevel == 0 ? fontSize : fontSize * (headingLevel <= 2 ? 1.18 : 1.08)
            let formatted = inline(content, fontSize: pointSize, heading: headingLevel > 0)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = 3
            if content.range(of: #"^\s*(?:[-+*]|\d+[.)])\s+"#, options: .regularExpression) != nil {
                paragraph.headIndent = fontSize * 1.15
            }
            formatted.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: formatted.length))
            appendLine(formatted, to: result, hasOutputLine: &hasOutputLine, fontSize: fontSize)
        }
        if !displayMathLines.isEmpty {
            appendLine(literal(displayMathLines.joined(separator: "\n"), fontSize: fontSize),
                       to: result, hasOutputLine: &hasOutputLine, fontSize: fontSize)
        }
        return result
    }

    private static func appendLine(_ line: NSAttributedString, to result: NSMutableAttributedString, hasOutputLine: inout Bool, fontSize: CGFloat) {
        if hasOutputLine {
            result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: fontSize), .foregroundColor: NSColor.labelColor]))
        }
        result.append(line)
        hasOutputLine = true
    }

    private static func literal(_ text: String, fontSize: CGFloat) -> NSMutableAttributedString {
        let paragraph = NSMutableParagraphStyle()
        // Character wrapping also keeps an unbroken equation or code token inside
        // the user-selected result width instead of growing the window.
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.lineSpacing = 3
        return NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ])
    }

    private static func inline(_ input: String, fontSize: CGFloat, heading: Bool) -> NSMutableAttributedString {
        let (protected, literals) = protectMath(in: input)
        let parsed = (try? AttributedString(markdown: protected,
                                          options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(protected)
        let output = NSMutableAttributedString(string: "")
        for run in parsed.runs {
            let intent = run.inlinePresentationIntent ?? []
            let isCode = intent.contains(.code)
            var font = isCode ? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular) :
                NSFont.systemFont(ofSize: fontSize, weight: heading || intent.contains(.stronglyEmphasized) ? .semibold : .regular)
            if intent.contains(.emphasized) {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            if intent.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if let link = run.link { attributes[.link] = link }
            output.append(NSAttributedString(string: String(parsed[run.range].characters), attributes: attributes))
        }
        for item in literals {
            let range = (output.string as NSString).range(of: item.token)
            guard range.location != NSNotFound else { continue }
            let rendered = item.mathBody.flatMap { simpleMath($0, fontSize: fontSize) } ?? literal(item.original, fontSize: fontSize)
            output.replaceCharacters(in: range, with: rendered)
        }
        return output
    }

    /// Shield math from Markdown's emphasis rules. Unknown or incomplete math is
    /// preserved, never sent through a lossy best-effort LaTeX conversion.
    private static func protectMath(in input: String) -> (String, [Literal]) {
        var prefix = "\u{E000}math"
        while input.contains(prefix) { prefix += "x" }
        var output = ""
        var literals: [Literal] = []
        var index = input.startIndex
        while index < input.endIndex {
            let suffix = input[index...]
            // A code span already protects its contents from Markdown; leave it alone.
            if suffix.first == "`" {
                let delimiter = String(suffix.prefix(while: { $0 == "`" }))
                let bodyStart = input.index(index, offsetBy: delimiter.count)
                if let end = input.range(of: delimiter, range: bodyStart..<input.endIndex) {
                    output += input[index..<end.upperBound]
                    index = end.upperBound
                    continue
                }
            }
            let pair: (String, String)?
            if suffix.hasPrefix("\\(") { pair = ("\\(", "\\)") }
            else if suffix.hasPrefix("\\[") { pair = ("\\[", "\\]") }
            else if suffix.hasPrefix("$$") { pair = ("$$", "$$") }
            else if suffix.hasPrefix("$") && (index == input.startIndex || input[input.index(before: index)] != "\\") { pair = ("$", "$") }
            else { pair = nil }
            if let (opening, closing) = pair {
                let bodyStart = input.index(index, offsetBy: opening.count)
                if let end = input.range(of: closing, range: bodyStart..<input.endIndex), end.lowerBound > bodyStart {
                    let token = "\(prefix)\(literals.count)\u{E001}"
                    let original = String(input[index..<end.upperBound])
                    let body = String(input[bodyStart..<end.lowerBound])
                    // "$5 and $10" is currency, not a math span. Inline math
                    // delimiters conventionally touch their contents.
                    if opening == "$", body.first?.isWhitespace == true || body.last?.isWhitespace == true || body.contains("`") {
                        output.append(input[index])
                        index = input.index(after: index)
                        continue
                    }
                    literals.append(Literal(token: token, original: original, mathBody: body))
                    output += token
                    index = end.upperBound
                    continue
                }
            }
            output.append(input[index])
            index = input.index(after: index)
        }
        return (output, literals)
    }

    private static let mathSymbols: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "varepsilon": "ε",
        "zeta": "ζ", "eta": "η", "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ",
        "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ", "pi": "π", "rho": "ρ", "sigma": "σ",
        "tau": "τ", "upsilon": "υ", "phi": "φ", "varphi": "ϕ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π", "Sigma": "Σ",
        "Upsilon": "Υ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω", "times": "×", "cdot": "·", "pm": "±",
        "mp": "∓", "le": "≤", "leq": "≤", "ge": "≥", "geq": "≥", "ne": "≠", "neq": "≠",
        "approx": "≈", "equiv": "≡", "infty": "∞", "to": "→", "rightarrow": "→", "leftarrow": "←",
        "in": "∈", "notin": "∉", "subset": "⊂", "subseteq": "⊆", "cup": "∪", "cap": "∩",
        "sum": "∑", "prod": "∏", "int": "∫", "partial": "∂", "nabla": "∇", "ell": "ℓ",
        "ldots": "…", "cdots": "⋯", "ast": "∗", "prime": "′"
    ]

    private static func simpleMath(_ body: String, fontSize: CGFloat) -> NSAttributedString? {
        let characters = Array(body)
        var position = 0
        let output = NSMutableAttributedString(string: "")
        func atom() -> String? {
            guard position < characters.count else { return nil }
            let character = characters[position]
            position += 1
            if character == "\\" {
                let start = position
                while position < characters.count && characters[position].isLetter { position += 1 }
                if position > start { return mathSymbols[String(characters[start..<position])] }
                guard position < characters.count else { return nil }
                let escaped = characters[position]
                position += 1
                if "{}_%#$&".contains(escaped) { return String(escaped) }
                if escaped == "," || escaped == ";" || escaped == " " { return " " }
                return nil
            }
            guard character != "{" && character != "}" && character != "^" && character != "_" else { return nil }
            return String(character)
        }
        while position < characters.count {
            var baseline: CGFloat = 0
            var size = fontSize
            var value = ""
            if characters[position] == "^" || characters[position] == "_" {
                let isSuperscript = characters[position] == "^"
                position += 1
                guard output.length > 0, position < characters.count else { return nil }
                baseline = fontSize * (isSuperscript ? 0.38 : -0.2)
                size = fontSize * 0.75
                if characters[position] == "{" {
                    position += 1
                    while position < characters.count && characters[position] != "}" {
                        guard let next = atom() else { return nil }
                        value += next
                    }
                    guard position < characters.count, !value.isEmpty else { return nil }
                    position += 1
                } else {
                    guard let next = atom() else { return nil }
                    value = next
                }
            } else {
                guard let next = atom() else { return nil }
                value = next
            }
            output.append(NSAttributedString(string: value, attributes: [
                .font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.labelColor, .baselineOffset: baseline
            ]))
        }
        return output
    }
}
