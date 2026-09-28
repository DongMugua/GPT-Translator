import AppKit
import ApplicationServices
import Testing
@testable import GPTTranslator

@MainActor
struct SelectedTextContentTests {
    @Test func richDictionaryWordStaysAWord() {
        let value = NSAttributedString(string: "bank", attributes: [.font: NSFont.boldSystemFont(ofSize: 16)])
        #expect(SelectedTextContent.formatted(value) == "bank")
        #expect(TranslationMode.resolve(text: SelectedTextContent.formatted(value), context: .selection, source: .auto) == .dictionary)
    }

    @Test func paragraphsAndEmphasisRemainSeparate() {
        let text = NSMutableAttributedString(string: "Definition.\n\nThe original query is refined.")
        text.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: NSRange(location: 0, length: 11))
        #expect(SelectedTextContent.formatted(text) == "**Definition.**\n\nThe original query is refined.")
    }

    @Test func italicVariablesAndSuperscriptSurviveRichSelection() {
        let text = NSMutableAttributedString(string: "q* = Q(q,p), (2)\nwhere p and q denote information and query.")
        let italic = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 14), toHaveTrait: .italicFontMask)
        text.addAttribute(.font, value: italic, range: NSRange(location: 0, length: 1))
        text.addAttribute(.superscript, value: 1, range: NSRange(location: 1, length: 1))
        let p = (text.string as NSString).range(of: "p and")
        text.addAttribute(.font, value: italic, range: NSRange(location: p.location, length: 1))
        let result = SelectedTextContent.formatted(text)
        #expect(result.contains("$q^{*}$ = Q(q,p), (2)"))
        #expect(result.contains("where $p$ and q"))
    }

    @Test func accessibilitySuperscriptAndFontDictionaryAreRecognized() {
        let text = NSMutableAttributedString(string: "where q* is the query")
        text.addAttribute(.accessibilityFont, value: [
            NSAccessibility.FontAttributeKey.fontName.rawValue: "Times-Italic",
            NSAccessibility.FontAttributeKey.fontSize.rawValue: 14
        ], range: NSRange(location: 6, length: 1))
        text.addAttribute(.accessibilitySuperscript, value: 1, range: NSRange(location: 7, length: 1))
        #expect(SelectedTextContent.formatted(text).contains("$q^{*}$"))
    }

    @Test func subscriptLettersAreNotTreatedAsADictionaryWord() {
        let text = NSMutableAttributedString(string: "qi")
        text.addAttribute(.superscript, value: -1, range: NSRange(location: 1, length: 1))
        #expect(SelectedTextContent.formatted(text) == "$q_{i}$")
    }

    @Test func mathematicalAlphabetAndRichScriptsBecomeOneProtectedFormula() throws {
        let text = NSMutableAttributedString(string: "where 𝑞* and 𝑝i are variables.")
        let value = text.string as NSString
        text.addAttribute(.superscript, value: 1, range: value.range(of: "*"))
        text.addAttribute(.superscript, value: -1, range: NSRange(location: value.range(of: "𝑝i").location + 2, length: 1))
        let qRange = value.range(of: "𝑞")
        let pRange = value.range(of: "𝑝")
        text.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: qRange)
        text.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: pRange)
        let formatted = SelectedTextContent.formatted(text)
        #expect(formatted.contains("$𝑞^{*}$"))
        #expect(formatted.contains("$𝑝_{i}$"))
        let request = ProtectedTranslationInput(text: formatted)
        #expect(!request.text.contains("^{*}"))
        #expect(!request.text.contains("_{i}"))
        #expect(try request.restore(in: request.text) == formatted)
        #expect(SelectedTextContent.formatted(NSAttributedString(string: "𝑞")) == "$𝑞$")
        #expect(SelectedTextContent.formatted(NSAttributedString(string: "ℝ")) == "$ℝ$")
    }

    @Test func rtfImportIsRestrictedToMatchingSelectedText() throws {
        let source = NSAttributedString(string: "Selected paragraph.\nSecond line.", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
        let data = try source.data(from: NSRange(location: 0, length: source.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let result = SelectedTextContent.fromRTF(data, matching: source.string)
        #expect(result == "**Selected paragraph.**\n**Second line.**")
        #expect(SelectedTextContent.fromRTF(data, matching: "Unrelated selection") == nil)
    }

    @Test func plainTextRetainsParagraphsAndTableTabs() {
        #expect(SelectedTextContent.plain("Head\r\n\r\nA\tB\u{2029}Next") == "Head\n\nA\tB\n\nNext")
        #expect(SelectedTextContent.plain("infor\u{00AD}mation") == "information")
        #expect(SelectedTextContent.plain("infor\u{00AD}\nmation") == "information")
    }
}
