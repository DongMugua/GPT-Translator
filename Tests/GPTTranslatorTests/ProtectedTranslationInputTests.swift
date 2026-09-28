import Foundation
import Testing
@testable import GPTTranslator

struct ProtectedTranslationInputTests {
    @Test func protectsPaperEquationAndPlainInlineVariables() throws {
        let source = """
        4.1.1 Definition. The process is formally defined as follows:

        q* = Q(q, p), (2)

        where p and q denote the personalized information and original query, and q* is the optimized query.
        """
        let input = ProtectedTranslationInput(text: source)
        #expect(input.hasProtectedContent)
        #expect(input.hasTranslatableText)
        #expect(!input.text.contains("q* = Q(q, p)"))
        #expect(!input.text.contains("where p and q"))
        #expect(input.text.contains("4.1.1 Definition."))
        let translated = input.text.replacingOccurrences(of: "where", with: "其中")
        let result = try input.restore(in: translated)
        #expect(result.contains("q* = Q(q, p), (2)"))
        #expect(result.contains("其中 p and q"))
        #expect(result.contains("and q* is"))
        #expect(!result.contains("ZXQKEEP"))
    }

    @Test func protectsAllExplicitMathDelimitersAndRestoresExactContent() throws {
        let source = #"Use $p$ with \(q^{*}\), then $$q^*=Q(q,p)\tag{2}$$ and \[x_i=\frac{a}{b}\]."#
        let input = ProtectedTranslationInput(text: source)
        #expect(!input.text.contains("frac"))
        #expect(!input.text.contains("$p$"))
        #expect(try input.restore(in: input.text) == source)
    }

    @Test func codeAndCitationsArePreservedWithoutProtectingOrdinaryWords() throws {
        let source = """
        ## 4.1 Pre-retrieval

        See [5, 100] and use `value = "$cost"`.

        ```python
        q = "A sentence to keep."
        print(q)
        ```

        1. Translate this item.
        2. Keep the list.
        """
        let input = ProtectedTranslationInput(text: source)
        #expect(!input.text.contains("A sentence to keep"))
        #expect(input.text.contains("Translate this item."))
        #expect(input.text.contains("## 4.1 Pre-retrieval"))
        #expect(try input.restore(in: input.text) == source)
    }

    @Test func missingDuplicatedOrDamagedTokensFailInsteadOfLosingMath() throws {
        let input = ProtectedTranslationInput(text: "The value is $q$.")
        #expect(throws: ProtectedTranslationInput.PreservationError.self) {
            try input.restore(in: "这个值。")
        }
        #expect(throws: ProtectedTranslationInput.PreservationError.self) {
            try input.restore(in: input.text + input.text)
        }
        #expect(throws: ProtectedTranslationInput.PreservationError.self) {
            try input.restore(in: input.text.replacingOccurrences(of: "QXZ", with: "Q X Z"))
        }
        #expect(try input.restore(in: input.text) == input.originalText)
    }

    @Test func tokenMapsCannotLeakAcrossRequests() throws {
        let first = ProtectedTranslationInput(text: "The value is $q$.")
        let second = ProtectedTranslationInput(text: "The value is $p$.")
        #expect(first.text != second.text)
        #expect(throws: ProtectedTranslationInput.PreservationError.self) {
            try second.restore(in: first.text)
        }
    }

    @Test func pureEquationOrCodeNeedsNoTranslationRequest() {
        for text in ["q* = Q(q, p), (2)", #"$$x=\frac{a}{b}$$"#, "`some_code()`"] {
            let input = ProtectedTranslationInput(text: text)
            #expect(input.hasProtectedContent)
            #expect(!input.hasTranslatableText)
            #expect(input.originalText == text)
        }
    }

    @Test func mixedAttributedAndPlainEquationProtectsEntireFormula() throws {
        let source = #"$q^{*}$ = Q(q, p), (2)"# + "\nwhere p and q describe the query."
        let input = ProtectedTranslationInput(text: source)
        #expect(!input.text.contains("Q(q, p)"))
        #expect(!input.text.contains("where p and q"))
        #expect(try input.restore(in: input.text) == source)
    }

    @Test func dollarPricesRemainTranslatableProse() {
        let source = "It costs $5 and $10."
        let input = ProtectedTranslationInput(text: source)
        #expect(input.text == source)
        #expect(!input.hasProtectedContent)
    }

    @Test func pureFormulaBypassesProviderCredentialsAndProcesses() async throws {
        let formula = #"$$q^{*}=Q(q,p)$$"#
        #expect(try await CodexCLIService().translate(text: formula, source: .english, target: .chineseSimplified, model: "", reasoning: .none) == formula)
        #expect(try await AntigravityCLIService().translate(text: formula, source: .english, target: .chineseSimplified) == formula)
        #expect(try await DirectProviderService().translate(text: formula, source: .english, target: .chineseSimplified, provider: .customAPI, model: "", reasoning: .none, apiKey: "") == formula)
    }

    @Test func dictionaryInputAndNormalProseAreUnchanged() throws {
        let dictionary = ProtectedTranslationInput(text: "bank", mode: .dictionary)
        #expect(dictionary.text == "bank")
        #expect(!dictionary.hasProtectedContent)
        #expect(dictionary.hasTranslatableText)
        let prose = "A choice = a decision.\nA short wrapped line."
        let input = ProtectedTranslationInput(text: prose)
        #expect(input.text == prose)
        #expect(try input.restore(in: "译文") == "译文")
    }

    @Test func mathematicalAlphabetsNormalizeWithoutLosingSuperscripts() throws {
        #expect(ProtectedTranslationInput.normalizeMathematicalAlphabet("𝑞² + 𝒑₀ = ℝ") == "q² + p₀ = R")
        let source = "where 𝑝 and 𝑞 denote information."
        let input = ProtectedTranslationInput(text: source)
        #expect(!input.text.contains("𝑝"))
        #expect(try input.restore(in: input.text) == source)
    }

    @Test func equationVariablesDoNotFreezeEnglishArticlesAndPronouns() {
        let input = ProtectedTranslationInput(text: "a = q + p\nI need a query, and q denotes that query.")
        #expect(input.text.contains("I need a query"))
        #expect(!input.text.contains("and q denotes"))
    }

    @Test func promptSeparatesPDFWrapsFromDocumentStructure() {
        let prompt = TranslationPrompt.instructions(source: .english, target: .chineseSimplified, mode: .translation)
        #expect(prompt.contains("PDF typesetting wrap"))
        #expect(prompt.contains("blank-line paragraph boundaries"))
        #expect(prompt.contains("section numbers"))
        #expect(prompt.contains("Never translate or rename mathematical variables"))
        #expect(prompt.contains("Copy each token exactly once"))
    }
}
