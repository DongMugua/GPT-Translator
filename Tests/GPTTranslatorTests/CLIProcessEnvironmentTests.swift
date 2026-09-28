import Foundation
import Testing
@testable import GPTTranslator

struct CLIProcessEnvironmentTests {
    private let home = URL(fileURLWithPath: "/Users/test-user", isDirectory: true)

    @Test func testMinimalGUIEnvironmentFindsHomebrewAndSystemExecutables() {
        let environment = CLIProcessEnvironment.make(
            for: URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            base: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
            homeDirectory: home
        )
        let paths = pathEntries(environment)
        #expect(Array(paths.prefix(4)) == ["/usr/bin", "/bin", "/usr/sbin", "/sbin"])
        #expect(paths.contains("/opt/homebrew/bin"))
        #expect(paths.contains("/usr/local/bin"))
        #expect(paths.contains("/Users/test-user/.local/bin"))
    }

    @Test func testExistingSearchOrderAndOtherEnvironmentValuesArePreserved() {
        let environment = CLIProcessEnvironment.make(
            for: URL(fileURLWithPath: "/custom/tool/bin/codex"),
            base: [
                "PATH": "/custom/node/bin:/opt/homebrew/bin:/usr/bin",
                "HOME": "/custom/home",
                "LANG": "en_US.UTF-8",
                "CUSTOM_SETTING": "unchanged"
            ],
            homeDirectory: home
        )
        #expect(Array(pathEntries(environment).prefix(3)) == ["/custom/node/bin", "/opt/homebrew/bin", "/usr/bin"])
        #expect(environment["HOME"] == "/custom/home")
        #expect(environment["LANG"] == "en_US.UTF-8")
        #expect(environment["CUSTOM_SETTING"] == "unchanged")
    }

    @Test func testEmptyAndRepeatedEntriesAreRemovedWithoutReordering() {
        let environment = CLIProcessEnvironment.make(
            for: URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            base: ["PATH": ":/opt/homebrew/bin::/usr/bin:/opt/homebrew/bin:/bin:/usr/bin:"],
            homeDirectory: home
        )
        let paths = pathEntries(environment)
        #expect(Array(paths.prefix(3)) == ["/opt/homebrew/bin", "/usr/bin", "/bin"])
        #expect(Set(paths).count == paths.count)
        #expect(!paths.contains(""))
        #expect(environment["PATH"]?.contains("::") == false)
    }

    @Test func testMissingAndEmptyPATHReceiveFallbacks() {
        for base in [[String: String](), ["PATH": ""], ["PATH": "::"]] {
            let environment = CLIProcessEnvironment.make(
                for: URL(fileURLWithPath: "/custom/cli/bin/codex"),
                base: base,
                homeDirectory: home
            )
            let paths = pathEntries(environment)
            #expect(paths.first == "/custom/cli/bin")
            #expect(paths.contains("/opt/homebrew/bin"))
            #expect(paths.contains("/usr/local/bin"))
            #expect(paths.contains("/usr/bin"))
            #expect(paths.contains("/bin"))
            #expect(paths.contains("/usr/sbin"))
            #expect(paths.contains("/sbin"))
        }
    }

    @Test func testExecutableDirectoryIsIncludedForDifferentProviders() {
        for executablePath in ["/custom/codex/bin/codex", "/custom/gemini/bin/gemini", "/custom/claude/bin/claude"] {
            let executable = URL(fileURLWithPath: executablePath)
            let environment = CLIProcessEnvironment.make(for: executable, base: [:], homeDirectory: home)
            #expect(pathEntries(environment).first == executable.deletingLastPathComponent().path)
        }
    }

    @Test func testSymlinkAndResolvedExecutableDirectoriesAreBothIncluded() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let linkDirectory = directory.appendingPathComponent("bin", isDirectory: true)
        let targetDirectory = directory.appendingPathComponent("package/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: linkDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let target = targetDirectory.appendingPathComponent("codex.js")
        try Data().write(to: target)
        let executable = linkDirectory.appendingPathComponent("codex")
        try FileManager.default.createSymbolicLink(at: executable, withDestinationURL: target)

        let environment = CLIProcessEnvironment.make(for: executable, base: [:], homeDirectory: home)
        let paths = pathEntries(environment)
        #expect(paths.first == linkDirectory.path)
        #expect(paths.contains(targetDirectory.resolvingSymlinksInPath().path))
    }

    @Test func testHOMEIsFilledOnlyWhenMissingOrEmpty() {
        for base in [[String: String](), ["HOME": ""]] {
            let environment = CLIProcessEnvironment.make(
                for: URL(fileURLWithPath: "/custom/bin/codex"), base: base, homeDirectory: home
            )
            #expect(environment["HOME"] == home.path)
        }
        let environment = CLIProcessEnvironment.make(
            for: URL(fileURLWithPath: "/custom/bin/codex"),
            base: ["HOME": "/alternate/home"],
            homeDirectory: home
        )
        #expect(environment["HOME"] == "/alternate/home")
    }

    @Test func testEnvNodeShebangStartsFromGUIEnvironmentWithoutRealNode() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("test-cli")
        // `true` stands in for Node: this test launches no shell, real Node,
        // provider CLI, network request, or credential lookup.
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("node"),
            withDestinationURL: URL(fileURLWithPath: "/usr/bin/true")
        )
        try Data("#!/usr/bin/env node\nThis is deliberately not valid JavaScript.\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let process = Process()
        process.executableURL = executable
        process.environment = CLIProcessEnvironment.make(
            for: executable,
            base: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
            homeDirectory: directory
        )
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let stderr = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(process.terminationReason == .exit)
        #expect(process.terminationStatus == 0, "Unexpected process error: \(stderr)")
        #expect(stderr.isEmpty)
    }

    private func pathEntries(_ environment: [String: String]) -> [String] {
        (environment["PATH"] ?? "").split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GPTTranslator-CLIEnvironmentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
