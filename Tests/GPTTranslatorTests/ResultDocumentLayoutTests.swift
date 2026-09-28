import AppKit
import SwiftUI
import Testing
@testable import GPTTranslator

@MainActor
private final class ResultLayoutProbe: ObservableObject {
    @Published var text: String
    var measurement = ResultContentMeasurement()

    init(text: String) { self.text = text }
}

private struct ResultLayoutFixture: View {
    @ObservedObject var probe: ResultLayoutProbe

    var body: some View {
        ResultDocumentScrollView(isLoading: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI").font(.subheadline.weight(.semibold))
                FormattedTranslationText(text: probe.text, fontSize: 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .onPreferenceChange(ResultContentMeasurementKey.self) { probe.measurement = $0 }
    }
}

@MainActor
struct ResultDocumentLayoutTests {
    @Test func longFormattedResultRemainsFullyScrollable() throws {
        let text = (0..<45).map { "**段落 \($0)**：检索之前优化查询，并保留变量 $q^{*} = Q(q,p)$ 及原有段落结构。" }
            .joined(separator: "\n\n") + "\n\n最后一段完整可见。"
        let probe = ResultLayoutProbe(text: text)
        let (window, host) = makeHost(probe: probe, width: 500, height: 170)
        defer { window.contentView = nil; window.close() }
        settle(host)

        let measured = try #require(probe.measurement.contentSize)
        #expect(abs(measured.width - 484) < 1)
        #expect(measured.height > host.bounds.height * 4)
        let textView = try #require(descendants(of: host).compactMap { $0 as? TranslationDocumentTextView }.first)
        #expect(textView.string.hasSuffix("最后一段完整可见。"))
        let requiredHeight = textView.documentSize(at: textView.frame.width).height
        #expect(textView.frame.height >= requiredHeight - 1)

        let scroll = try #require(descendants(of: host).compactMap { $0 as? NSScrollView }.first)
        let document = try #require(scroll.documentView)
        #expect(document.bounds.height >= measured.height - 1)
        let end = CGPoint(x: 0, y: max(0, document.bounds.maxY - scroll.contentView.bounds.height))
        scroll.contentView.scroll(to: end)
        scroll.reflectScrolledClipView(scroll.contentView)
        #expect(scroll.contentView.bounds.maxY >= document.bounds.maxY - 1)
        #expect(abs(window.contentRect(forFrameRect: window.frame).width - 500) < 1)
    }

    @Test func newContentRewrapsWithoutWideningItsViewport() throws {
        let probe = ResultLayoutProbe(text: "简短结果。")
        let (window, host) = makeHost(probe: probe, width: 410, height: 180)
        defer { window.contentView = nil; window.close() }
        settle(host)
        let short = try #require(probe.measurement.contentSize)

        probe.text = String(repeating: "格式化结果需要按用户选定宽度换行。", count: 90)
            + "\n\n```text\n" + String(repeating: "x_q", count: 120) + "\n```"
        settle(host)
        let long = try #require(probe.measurement.contentSize)
        #expect(abs(short.width - long.width) < 1)
        #expect(long.height > short.height * 3)
        #expect(abs(host.frame.width - 410) < 1)

        window.setContentSize(NSSize(width: 610, height: 180))
        settle(host)
        let widened = try #require(probe.measurement.contentSize)
        #expect(abs(widened.width - 594) < 1)
        #expect(widened.height < long.height)
        #expect(abs(host.frame.width - 610) < 1)
    }

    private func makeHost(probe: ResultLayoutProbe, width: CGFloat, height: CGFloat) -> (NSWindow, NSHostingView<ResultLayoutFixture>) {
        // An off-screen window owned only by this test process. No app delegate,
        // saved preferences, translation services, or installed app is used.
        _ = NSApplication.shared
        let frame = NSRect(x: -10000, y: -10000, width: width, height: height)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: ResultLayoutFixture(probe: probe))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: frame.size)
        window.contentView = host
        return (window, host)
    }

    private func settle(_ view: NSView) {
        for _ in 0..<8 {
            view.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.025))
        }
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
