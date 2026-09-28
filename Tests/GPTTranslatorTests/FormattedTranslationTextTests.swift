import AppKit
import Testing
@testable import GPTTranslator

@MainActor
struct FormattedTranslationTextTests {
    @Test func paragraphsListsAndMarkdownStylesRetainTheirStructure() {
        let text = "## Definition\n\n**Important** paragraph.\n\n1. First meaning\n2. *Second* meaning\n"
        let rendered = FormattedTranslationRenderer.attributedString(text: text, fontSize: 14)
        #expect(rendered.string == "Definition\n\nImportant paragraph.\n\n1. First meaning\n2. Second meaning\n")
        let important = (rendered.string as NSString).range(of: "Important").location
        let second = (rendered.string as NSString).range(of: "Second").location
        let bold = rendered.attribute(.font, at: important, effectiveRange: nil) as? NSFont
        let italic = rendered.attribute(.font, at: second, effectiveRange: nil) as? NSFont
        #expect(bold != NSFont.systemFont(ofSize: 14))
        #expect(italic.map { NSFontManager.shared.traits(of: $0).contains(.italicFontMask) } == true)
    }

    @Test func mathVariablesAndSimpleScriptsRenderWithoutBeingTranslatedOrInterpretedAsMarkdown() {
        let rendered = FormattedTranslationRenderer.attributedString(text: #"**Equation:** $q^{*} = Q(q, p)$; $q_i = \alpha + \beta$."#, fontSize: 16)
        #expect(rendered.string == "Equation: q* = Q(q, p); qi = α + β.")
        let star = (rendered.string as NSString).range(of: "*").location
        let index = (rendered.string as NSString).range(of: "qi").location + 1
        #expect((rendered.attribute(.baselineOffset, at: star, effectiveRange: nil) as? CGFloat ?? 0) > 0)
        #expect((rendered.attribute(.baselineOffset, at: index, effectiveRange: nil) as? CGFloat ?? 0) < 0)
    }

    @Test func unsupportedMathStaysCompleteAndLiteral() {
        let formula = #"$q^{*} = \frac{a_1}{b_2}$"#
        let rendered = FormattedTranslationRenderer.attributedString(text: "公式：\(formula)", fontSize: 14)
        #expect(rendered.string == "公式：\(formula)")
    }

    @Test func multilineSimpleMathRendersWhileIncompleteMathRemainsVisible() {
        let completed = FormattedTranslationRenderer.attributedString(text: "说明：\n\n$$\nq^{*} = Q(q, p)\n$$\n\n下一段", fontSize: 14)
        #expect(completed.string == "说明：\n\nq* = Q(q, p)\n\n下一段")
        let partial = "说明：\n$$\nq^{*} ="
        #expect(FormattedTranslationRenderer.attributedString(text: partial, fontSize: 14).string == partial)
    }

    @Test func codeAndTableRowsRemainLiteralAndOnSeparateLines() {
        let rendered = FormattedTranslationRenderer.attributedString(
            text: "```swift\nlet formula = \"$q^{*}$\"\nlet **value** = 2\n```\n\n| Item | Value |\n| --- | --- |\n| q | 2 |", fontSize: 14)
        #expect(rendered.string == "let formula = \"$q^{*}$\"\nlet **value** = 2\n\n| Item | Value |\n| --- | --- |\n| q | 2 |")
    }

    @Test func currencyAndInlineCodeDoNotBecomeMath() {
        let rendered = FormattedTranslationRenderer.attributedString(text: "Prices: $5 and $10. Code: `$q^{*}$`.", fontSize: 14)
        #expect(rendered.string == "Prices: $5 and $10. Code: $q^{*}$.")
    }

    @Test func longEquationsWrapAndFullDocumentHeightTracksTheUserWidth() {
        let view = TranslationDocumentTextView()
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.heightTracksTextView = false
        view.setDocument("```\n" + String(repeating: "q_i+", count: 120) + "\n```\n\n最后一段必须显示。", fontSize: 14)
        let narrow = view.documentSize(at: 180)
        let wide = view.documentSize(at: 420)
        #expect(narrow.width == 180)
        #expect(wide.width == 420)
        #expect(narrow.height > wide.height)
        #expect(wide.height > 30)
        #expect(view.string.hasSuffix("最后一段必须显示。"))
        if let container = view.textContainer, let manager = view.layoutManager {
            #expect(manager.usedRect(for: container).width <= 421)
        }
    }
}
