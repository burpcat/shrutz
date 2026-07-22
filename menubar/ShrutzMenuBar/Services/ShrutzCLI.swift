import Foundation

enum ShrutzCLIError: Error {
    case notInstalled
    case decodeFailed(String)
}

/// Thin wrapper around the `shrutz` CLI. This app never reimplements
/// scheduling, idle-detection, or wallpaper-apply logic — every action
/// shells out to the real binary, and every piece of displayed state is
/// read back from it via `--json`.
enum ShrutzCLI {
    /// Must be invoked by absolute path. install.sh only appends
    /// ~/.local/bin to PATH inside .zshrc/.bashrc — a GUI app launched
    /// from Finder or a Login Item never sources those files, so relying
    /// on $PATH here would silently fail to find the binary.
    static let binaryPath = NSHomeDirectory() + "/.local/bin/shrutz"

    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: binaryPath)
    }

    @discardableResult
    static func run(_ args: [String]) async throws -> (exitCode: Int32, output: String) {
        guard isInstalled else { throw ShrutzCLIError.notInstalled }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = args

            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError = Pipe()

            process.terminationHandler = { proc in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (proc.terminationStatus, output))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Runs a `--json` variant and decodes the result. Non-zero exit with
    /// unparseable output surfaces as decodeFailed rather than silently
    /// returning stale/default data.
    static func runJSON<T: Decodable>(_ args: [String], as type: T.Type) async throws -> T {
        let (_, output) = try await run(args)
        guard let data = output.data(using: .utf8) else {
            throw ShrutzCLIError.decodeFailed("non-utf8 output")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ShrutzCLIError.decodeFailed("\(error)")
        }
    }
}
