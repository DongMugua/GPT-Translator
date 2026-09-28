import Foundation

enum CLIProcessEnvironment {
    /// Finder-launched apps do not inherit a login shell's PATH. Keep any explicit
    /// search order, then add common CLI locations so `#!/usr/bin/env node` works.
    static func make(
        for executable: URL,
        base: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [String: String] {
        var environment = base
        let existingPaths = (base["PATH"] ?? "").split(separator: ":").map(String.init)
        let additionalPaths = [
            executable.deletingLastPathComponent().path,
            executable.resolvingSymlinksInPath().deletingLastPathComponent().path,
            homeDirectory.appendingPathComponent(".local/bin", isDirectory: true).path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        var seen = Set<String>()
        environment["PATH"] = (existingPaths + additionalPaths)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: ":")
        if environment["HOME"]?.isEmpty != false {
            environment["HOME"] = homeDirectory.path
        }
        return environment
    }
}
