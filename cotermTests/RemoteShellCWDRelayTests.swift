import Foundation
import Testing

@Suite(.serialized)
struct RemoteShellCWDRelayTests {
    @Test
    func zshRelayPromptReportsRemotePWD() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("coterm-zsh-relay-pwd-\(UUID().uuidString)")
        let binDir = root.appendingPathComponent("bin", isDirectory: true)
        let remoteDirectory = root.appendingPathComponent("remote-cwd", isDirectory: true)
        let logPath = root.appendingPathComponent("relay.log", isDirectory: false)

        try fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: remoteDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        try writeExecutableScript(
            at: binDir.appendingPathComponent("coterm", isDirectory: false),
            contents: """
            #!/bin/sh
            printf '%s\\n' "$*" >> "\(logPath.path)"
            exit 0
            """
        )

        let output = try runInteractiveZsh(
            command: """
            : > "\(logPath.path)"
            cd "\(remoteDirectory.path)"
            _COTERM_TTY_REPORTED=1
            _COTERM_PORTS_LAST_RUN=$(_coterm_now)
            _COTERM_PWD_LAST_PWD="/tmp/local-launch"
            _coterm_precmd
            repeat 20; do
              [[ -s "\(logPath.path)" ]] && break
              sleep 0.05
            done
            cat "\(logPath.path)"
            """,
            extraEnvironment: [
                "PATH": "\(binDir.path):/usr/bin:/bin:/usr/sbin:/sbin",
                "COTERM_SOCKET_PATH": "127.0.0.1:64011",
                "COTERM_WORKSPACE_ID": "11111111-1111-1111-1111-111111111111",
                "COTERM_TAB_ID": "22222222-2222-2222-2222-222222222222",
                "COTERM_PANEL_ID": "22222222-2222-2222-2222-222222222222",
            ]
        )

        let expected = #"rpc surface.report_pwd {"workspace_id":"11111111-1111-1111-1111-111111111111","path":"\#(remoteDirectory.path)","surface_id":"22222222-2222-2222-2222-222222222222"}"#
        #expect(output.contains(expected), Comment(rawValue: output))
    }

    @Test
    func bashRelayPromptReportsRemotePWD() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("coterm-bash-relay-pwd-\(UUID().uuidString)")
        let binDir = root.appendingPathComponent("bin", isDirectory: true)
        let remoteDirectory = root.appendingPathComponent("remote-cwd", isDirectory: true)
        let logPath = root.appendingPathComponent("relay.log", isDirectory: false)

        try fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: remoteDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        try writeExecutableScript(
            at: binDir.appendingPathComponent("coterm", isDirectory: false),
            contents: """
            #!/bin/sh
            printf '%s\\n' "$*" >> "\(logPath.path)"
            exit 0
            """
        )

        let result = try runInteractiveBash(
            command: """
            : > "\(logPath.path)"
            cd "\(remoteDirectory.path)"
            _COTERM_TTY_REPORTED=1
            _COTERM_PORTS_LAST_RUN=$(_coterm_now)
            _COTERM_PWD_LAST_PWD="/tmp/local-launch"
            _coterm_prompt_command
            for _coterm_i in $(seq 1 20); do
              [ -s "\(logPath.path)" ] && break
              sleep 0.05
            done
            cat "\(logPath.path)"
            """,
            extraEnvironment: [
                "PATH": "\(binDir.path):/usr/bin:/bin:/usr/sbin:/sbin",
                "COTERM_SOCKET_PATH": "127.0.0.1:64011",
                "COTERM_WORKSPACE_ID": "11111111-1111-1111-1111-111111111111",
                "COTERM_TAB_ID": "22222222-2222-2222-2222-222222222222",
                "COTERM_PANEL_ID": "22222222-2222-2222-2222-222222222222",
            ]
        )

        let expected = #"rpc surface.report_pwd {"workspace_id":"11111111-1111-1111-1111-111111111111","path":"\#(remoteDirectory.path)","surface_id":"22222222-2222-2222-2222-222222222222"}"#
        #expect(result.stdout.contains(expected), Comment(rawValue: result.stdout))
    }

    private func runInteractiveZsh(
        command: String,
        extraEnvironment: [String: String]
    ) throws -> String {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("coterm-zsh-shell-integration-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let userZdotdir = root.appendingPathComponent("zdotdir")
        try fileManager.createDirectory(at: userZdotdir, withIntermediateDirectories: true)
        var userZshEnvFileContents = "\n"
        if let path = extraEnvironment["PATH"] {
            let escaped = path.replacingOccurrences(of: "\"", with: "\\\"")
            userZshEnvFileContents = "export PATH=\"\(escaped)\"\n"
        }
        try userZshEnvFileContents.write(
            to: userZdotdir.appendingPathComponent(".zshenv"),
            atomically: true,
            encoding: .utf8
        )

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let cotermZdotdir = repoRoot.appendingPathComponent("Resources/shell-integration")
        let ghosttyResources = repoRoot.appendingPathComponent("ghostty/src")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-i", "-c", command]
        process.environment = [
            "HOME": root.path,
            "TERM": "xterm-256color",
            "SHELL": "/bin/zsh",
            "USER": NSUserName(),
            "ZDOTDIR": cotermZdotdir.path,
            "COTERM_ZSH_ZDOTDIR": userZdotdir.path,
            "COTERM_SHELL_INTEGRATION": "1",
            "COTERM_SHELL_INTEGRATION_DIR": cotermZdotdir.path,
            "GHOSTTY_RESOURCES_DIR": ghosttyResources.path,
        ]
        for (key, value) in extraEnvironment {
            process.environment?[key] = value
        }

        let output = try runProcess(process)
        #expect(output.status == 0, Comment(rawValue: output.stderr))
        return output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runInteractiveBash(
        command: String,
        extraEnvironment: [String: String]
    ) throws -> (stdout: String, stderr: String) {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("coterm-bash-shell-integration-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let integrationPath = repoRoot.appendingPathComponent("Resources/shell-integration/coterm-bash-integration.bash")
        let rcfilePath = root.appendingPathComponent(".bashrc")
        try ". \"\(integrationPath.path)\"\n".write(to: rcfilePath, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["--noprofile", "--rcfile", rcfilePath.path, "-i", "-c", command]
        process.environment = [
            "HOME": root.path,
            "TERM": "xterm-256color",
            "SHELL": "/bin/bash",
            "USER": NSUserName(),
        ]
        for (key, value) in extraEnvironment {
            process.environment?[key] = value
        }

        let output = try runProcess(process)
        #expect(output.status == 0, Comment(rawValue: output.stderr))
        return (
            stdout: output.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func runProcess(_ process: Process) throws -> (status: Int32, stdout: String, stderr: String) {
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let deadline = Date.now.addingTimeInterval(5)
        while process.isRunning && Date.now < deadline {
            _ = RunLoop.current.run(mode: .default, before: Date.now.addingTimeInterval(0.01))
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw NSError(
                domain: "RemoteShellCWDRelayTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for shell to exit"]
            )
        }

        return (
            status: process.terminationStatus,
            stdout: String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }

    private func writeExecutableScript(at url: URL, contents: String) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
