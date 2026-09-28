import Testing
@testable import GPTTranslator

struct SelectionReadTriggerTests {
    @Test func stationaryDoubleClickGetsSameCaptureAsDrag() {
        let drag = SelectionReadTrigger(didDrag: true, clickCount: 1)
        let doubleClick = SelectionReadTrigger(didDrag: false, clickCount: 2)
        #expect(drag.allowsClipboardFallback)
        #expect(doubleClick.allowsClipboardFallback)
        #expect(doubleClick.delay(doubleClickInterval: 0.5) == drag.delay(doubleClickInterval: 0.5))
    }

    @Test func firstClickWaitsForPossibleSecondClickWithoutCopying() {
        let first = SelectionReadTrigger(didDrag: false, clickCount: 1)
        let second = SelectionReadTrigger(didDrag: false, clickCount: 2)
        #expect(!first.allowsClipboardFallback)
        #expect(first.delay(doubleClickInterval: 0.7) >= 0.7)
        #expect(second.delay(doubleClickInterval: 0.7) < first.delay(doubleClickInterval: 0.7))
        #expect(first.delay(doubleClickInterval: 0.1) >= 0.18)
    }

    @Test func tripleClickParagraphSelectionAlsoAllowsFallback() {
        let trigger = SelectionReadTrigger(didDrag: false, clickCount: 3)
        #expect(trigger.allowsClipboardFallback)
        #expect(TranslationMode.resolve(text: "A selected paragraph.", context: .selection, source: .auto) == .translation)
        #expect(TranslationMode.resolve(text: "bank", context: .selection, source: .auto) == .dictionary)
    }
}
