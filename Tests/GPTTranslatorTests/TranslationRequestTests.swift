import Foundation
import Testing
@testable import GPTTranslator

struct TranslationRequestTests {
    @Test func testSingleWordAllowsSurroundingPunctuationAndInternalApostrophesOrHyphens() {
        let cases: [(String, String)] = [
            ("bank", "bank"),
            ("  “bank,”\n", "bank"),
            ("(run)", "run"),
            ("【word】", "word"),
            ("don't", "don't"),
            ("isn’t", "isn’t"),
            ("mother-in-law", "mother-in-law"),
            ("state-of-the-art", "state-of-the-art"),
            ("café", "café"),
            ("naïve", "naïve"),
            ("acción", "acción"),
            ("cafe\u{0301}", "cafe\u{0301}"),
            ("Straße", "Straße"),
            ("I", "I")
        ]
        for (input, expected) in cases {
            #expect(TranslationMode.selectedWord(in: input) == expected, "Input: \(input)")
            #expect(TranslationMode.resolve(text: input, context: .selection, source: .auto) == .dictionary, "Input: \(input)")
        }
    }

    @Test func testPhrasesSentencesURLsNumbersAndNonLatinScriptsRemainTranslations() {
        for input in [
            "", "  ", "...", "bank account", "The bank is open.", "a\nb",
            "https://example.com", "example.com", "person@example.com",
            "123", "word2", "3.14", "C++", "snake_case", "foo/bar",
            "-word", "word-", "two--words", "词语", "こんにちは", "\u{0301}",
            "\u{0301}word", "a-\u{0301}", "a'\u{0301}"
        ] {
            #expect(TranslationMode.selectedWord(in: input) == nil, "Input: \(input)")
            #expect(TranslationMode.resolve(text: input, context: .selection, source: .auto) == .translation, "Input: \(input)")
        }
    }

    @Test func testScreenshotsAndSourcesWithoutSupportedWordBoundariesDoNotTriggerDictionary() {
        #expect(TranslationMode.resolve(text: "bank", context: .screenshot, source: .auto) == .translation)
        for source in [LanguageOption.chineseSimplified, .japanese, .korean] {
            #expect(TranslationMode.resolve(text: "bank", context: .selection, source: source) == .translation)
        }
    }

    @Test func testExplicitLatinLanguageSelectionsReceiveDictionaryEntries() {
        #expect(TranslationMode.resolve(text: "bank", context: .selection, source: .english) == .dictionary)
        #expect(TranslationMode.resolve(text: "acción", context: .selection, source: .spanish) == .dictionary)
        #expect(TranslationMode.resolve(text: "café", context: .selection, source: .french) == .dictionary)
        #expect(TranslationMode.resolve(text: "Straße", context: .selection, source: .german) == .dictionary)
    }

    @Test func testDictionaryPromptRequestsUsefulSensesWithoutInventingMeanings() {
        let prompt = TranslationPrompt.combined(text: "“bank,”", source: .english, target: .chineseSimplified, mode: .dictionary)
        #expect(prompt.contains("dictionary entry"))
        #expect(prompt.contains("part of speech"))
        #expect(prompt.contains("distinct common senses"))
        #expect(prompt.contains("Do not invent extra meanings"))
        #expect(prompt.contains("only one common meaning"))
        #expect(prompt.contains("pronunciation reliably"))
        #expect(prompt.contains("example in the source language"))
        #expect(prompt.contains("Simplified Chinese"))
        #expect(prompt.contains("<text>\nbank\n</text>"))
    }

    @Test func testAutomaticDictionaryDoesNotAssumeEveryLatinWordIsEnglish() {
        let prompt = TranslationPrompt.instructions(source: .auto, target: .spanish, mode: .dictionary)
        #expect(prompt.contains("do not assume it is English"))
        #expect(prompt.contains("Spanish"))
    }

    @Test func testPersistentSessionAllowsAlternatingTranslationAndDictionaryRequests() {
        #expect(TranslationPrompt.sessionInstructions.contains("Never use tools"))
        #expect(TranslationPrompt.sessionInstructions.contains("Each request is independent"))
        #expect(TranslationPrompt.sessionInstructions.contains("dictionary entry for dictionary requests"))
        #expect(TranslationPrompt.sessionInstructions.contains("translation for translation requests"))
    }

    @Test func testNormalTranslationPreservesTextAndDoesNotRequestDictionaryOutput() {
        let text = "The bank is open.\nKeep this line."
        let prompt = TranslationPrompt.combined(text: text, source: .auto, target: .chineseSimplified, mode: .translation)
        #expect(prompt.contains(text))
        #expect(prompt.contains("Return only the translated text"))
        #expect(!prompt.contains("dictionary entry"))
        #expect(TranslationPrompt.input(text: "“bank,”", mode: .translation) == "“bank,”")
    }

    @Test func testCacheSeparatesDictionaryTranslationAndProviderConfigurations() {
        func key(mode: TranslationMode, sourceID: String = "source-a", target: LanguageOption = .chineseSimplified) -> TranslationCacheKey {
            TranslationCacheKey(sourceID: sourceID, model: "model", reasoning: .none, source: .english, target: target, text: "bank", mode: mode)
        }
        var cache = [key(mode: .translation): "银行"]
        cache[key(mode: .dictionary)] = "银行；河岸"
        #expect(cache.count == 2)
        #expect(cache[key(mode: .translation)] == "银行")
        #expect(cache[key(mode: .dictionary)] == "银行；河岸")
        #expect(cache[key(mode: .dictionary, sourceID: "source-b")] == nil)
        #expect(cache[key(mode: .dictionary, target: .spanish)] == nil)
    }

    @Test func testMachineTranslationCapabilitiesAreVisibleOnlyForDictionaryRequests() {
        #expect(TranslationMode.dictionary.notice(for: .appleTranslation) != nil)
        #expect(TranslationMode.dictionary.notice(for: .googleWeb) != nil)
        for provider in ModelProvider.allCases {
            #expect(TranslationMode.translation.notice(for: provider) == nil)
            if !provider.isMachineTranslation {
                #expect(TranslationMode.dictionary.notice(for: provider) == nil)
            }
        }
    }

    @Test func testGoogleDictionaryKeepsAvailablePartsOfSpeechAndDeduplicatesMeanings() {
        let fixture: [Any] = [
            [["银行", "bank", NSNull(), NSNull(), 1]],
            [
                ["noun", ["银行", "河岸", "银行", " "]],
                ["verb", ["存入银行", "倾斜转弯"]]
            ]
        ]
        #expect(GoogleDictionaryResponse.entry(from: fixture, headword: "bank") == "bank\n\nnoun\n1. 银行\n2. 河岸\n\nverb\n1. 存入银行\n2. 倾斜转弯")
    }

    @Test func testGoogleMissingOrMalformedDictionaryFallsBackWithoutInventingEntries() {
        let fixtures: [[Any]] = [
            [],
            [[["银行"]]],
            [[["银行"]], NSNull()],
            [[["银行"]], []],
            [[["银行"]], [["noun", []]]],
            [[["银行"]], [["noun", "unexpected"]]],
            [[["银行"]], [["noun", [" "]]]]
        ]
        for fixture in fixtures {
            #expect(GoogleDictionaryResponse.entry(from: fixture, headword: "bank") == nil)
        }
    }
}
