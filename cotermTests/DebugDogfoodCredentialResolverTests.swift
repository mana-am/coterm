import Foundation
import Testing

#if canImport(Coterm_DEV)
    @testable import Coterm_DEV
#elseif canImport(Coterm)
    @testable import Coterm
#endif

// The resolver only exists in DEBUG (it is the macOS dogfood auto-sign-in seam,
// compiled out of release builds), so the whole suite is DEBUG-gated. In a
// release test build there is nothing to test: the auto-sign-in path does not
// exist, which is the production guarantee.
#if DEBUG
@Suite struct DebugDogfoodCredentialResolverTests {
    /// Build a resolver over an ordered list of `(path, contents)` secret-file
    /// fakes, so a test never reads the real `~/.secrets` files and the file
    /// precedence order is deterministic (a plain `[String: String]` would
    /// iterate in undefined key order).
    private func makeResolver(
        environment: [String: String],
        files: [(path: String, contents: String)] = []
    ) -> DebugDogfoodCredentialResolver {
        let table = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0.contents) })
        return DebugDogfoodCredentialResolver(
            environment: environment,
            secretFilePaths: files.map(\.path),
            readFile: { table[$0] }
        )
    }

    @Test func noCredentialsAnywhereResolvesNil() {
        let resolver = makeResolver(environment: ["HOME": "/Users/test"])
        #expect(resolver.resolve() == nil)
    }

    @Test func dogfoodEnvCredentialsResolve() {
        let resolver = makeResolver(environment: [
            "COTERM_DOGFOOD_STACK_EMAIL": "lawrence@emergent.inc",
            "COTERM_DOGFOOD_STACK_PASSWORD": "dog-pw",
        ])
        #expect(
            resolver.resolve()
                == .init(email: "lawrence@emergent.inc", password: "dog-pw")
        )
    }

    @Test func uitestEnvCredentialsResolveWhenNoDogfood() {
        let resolver = makeResolver(environment: [
            "COTERM_UITEST_STACK_EMAIL": "agent-dev@emergent.inc",
            "COTERM_UITEST_STACK_PASSWORD": "agent-pw",
        ])
        #expect(
            resolver.resolve()
                == .init(email: "agent-dev@emergent.inc", password: "agent-pw")
        )
    }

    @Test func dogfoodAccountWinsOverUitestAccountAcrossSources() {
        // The dog Mac case: the agent (uitest) creds are in the environment, but
        // the human dogfood creds are only in a secret file. Dogfood must win so
        // the dog Mac comes up as lawrence, not the agent account.
        let resolver = makeResolver(
            environment: [
                "COTERM_UITEST_STACK_EMAIL": "agent-dev@emergent.inc",
                "COTERM_UITEST_STACK_PASSWORD": "agent-pw",
            ],
            files: [
                (
                    "/secrets/coterm-dev.env",
                    """
                    COTERM_DOGFOOD_STACK_EMAIL=lawrence@emergent.inc
                    COTERM_DOGFOOD_STACK_PASSWORD=dog-pw
                    """
                ),
            ]
        )
        #expect(
            resolver.resolve()
                == .init(email: "lawrence@emergent.inc", password: "dog-pw")
        )
    }

    @Test func envWinsOverFileWithinSameAccount() {
        let resolver = makeResolver(
            environment: [
                "COTERM_DOGFOOD_STACK_EMAIL": "env@emergent.inc",
                "COTERM_DOGFOOD_STACK_PASSWORD": "env-pw",
            ],
            files: [
                (
                    "/secrets/coterm-dev.env",
                    """
                    COTERM_DOGFOOD_STACK_EMAIL=file@emergent.inc
                    COTERM_DOGFOOD_STACK_PASSWORD=file-pw
                    """
                ),
            ]
        )
        #expect(
            resolver.resolve()
                == .init(email: "env@emergent.inc", password: "env-pw")
        )
    }

    @Test func earlierFileWinsOverLaterFile() {
        // coterm-dev.env is listed before coterm.env, so it takes precedence.
        let resolver = DebugDogfoodCredentialResolver(
            environment: [:],
            secretFilePaths: ["/secrets/coterm-dev.env", "/secrets/coterm.env"],
            readFile: { path in
                switch path {
                case "/secrets/coterm-dev.env":
                    return """
                    COTERM_DOGFOOD_STACK_EMAIL=devfile@emergent.inc
                    COTERM_DOGFOOD_STACK_PASSWORD=dev-pw
                    """
                case "/secrets/coterm.env":
                    return """
                    COTERM_DOGFOOD_STACK_EMAIL=cotermfile@emergent.inc
                    COTERM_DOGFOOD_STACK_PASSWORD=coterm-pw
                    """
                default:
                    return nil
                }
            }
        )
        #expect(
            resolver.resolve()
                == .init(email: "devfile@emergent.inc", password: "dev-pw")
        )
    }

    @Test func fallsThroughToCotermEnvFileWhenDevFileLacksCreds() {
        let resolver = DebugDogfoodCredentialResolver(
            environment: [:],
            secretFilePaths: ["/secrets/coterm-dev.env", "/secrets/coterm.env"],
            readFile: { path in
                switch path {
                case "/secrets/coterm-dev.env":
                    return "# no stack creds here\nE2B_API_KEY=abc\n"
                case "/secrets/coterm.env":
                    return """
                    COTERM_UITEST_STACK_EMAIL=agent@emergent.inc
                    COTERM_UITEST_STACK_PASSWORD=agent-pw
                    """
                default:
                    return nil
                }
            }
        )
        #expect(
            resolver.resolve()
                == .init(email: "agent@emergent.inc", password: "agent-pw")
        )
    }

    @Test func partialCredentialPairIsIgnored() {
        // Email without password must not yield a half-resolved credential.
        let resolver = makeResolver(environment: [
            "COTERM_DOGFOOD_STACK_EMAIL": "lawrence@emergent.inc",
        ])
        #expect(resolver.resolve() == nil)
    }

    @Test func emptyCredentialValuesAreIgnored() {
        let resolver = makeResolver(environment: [
            "COTERM_DOGFOOD_STACK_EMAIL": "",
            "COTERM_DOGFOOD_STACK_PASSWORD": "",
        ])
        #expect(resolver.resolve() == nil)
    }

    @Test func parsesQuotedAndCommentedEnvFile() {
        let parsed = DebugDogfoodCredentialResolver.parseEnvFile(
            """
            # comment line
            COTERM_DOGFOOD_STACK_EMAIL="lawrence@emergent.inc"
            COTERM_DOGFOOD_STACK_PASSWORD='secret value'

            BLANK_AFTER=1
            """
        )
        #expect(parsed["COTERM_DOGFOOD_STACK_EMAIL"] == "lawrence@emergent.inc")
        #expect(parsed["COTERM_DOGFOOD_STACK_PASSWORD"] == "secret value")
        #expect(parsed["BLANK_AFTER"] == "1")
    }
}

/// Integration coverage for the `MacAuthComposition` wrapper that feeds resolved
/// creds into `AuthLaunchOptions`. The wrapper, not the resolver, is where a
/// regression would re-introduce the "agent creds in env shadow the dogfood
/// file" bug, so these tests drive the wrapper directly with injected file
/// fakes.
@Suite struct MacAuthCompositionDogfoodAutoSignInTests {
    @Test func dogfoodFileWinsOverAgentEnvCredsOnDogMac() {
        // Dog-Mac scenario: agent (uitest) creds in the environment, human
        // dogfood creds only in the secret file. The build must come up as the
        // human dogfood account, so the file creds win and overwrite the env
        // uitest keys that AuthLaunchOptions reads.
        let merged = MacAuthComposition.environmentWithDogfoodAutoSignIn(
            [
                "COTERM_UITEST_STACK_EMAIL": "agent-dev@emergent.inc",
                "COTERM_UITEST_STACK_PASSWORD": "agent-pw",
            ],
            secretFilePaths: ["/secrets/coterm-dev.env"],
            readFile: { _ in
                """
                COTERM_DOGFOOD_STACK_EMAIL=lawrence@emergent.inc
                COTERM_DOGFOOD_STACK_PASSWORD=dog-pw
                """
            }
        )
        #expect(merged["COTERM_UITEST_STACK_EMAIL"] == "lawrence@emergent.inc")
        #expect(merged["COTERM_UITEST_STACK_PASSWORD"] == "dog-pw")
    }

    @Test func leavesAgentEnvCredsWhenNoDogfoodFile() {
        // CI UI-test scenario: only uitest env creds, no secret file. The
        // resolver returns that same pair, so the merge is a no-op.
        let merged = MacAuthComposition.environmentWithDogfoodAutoSignIn(
            [
                "COTERM_UITEST_STACK_EMAIL": "agent-dev@emergent.inc",
                "COTERM_UITEST_STACK_PASSWORD": "agent-pw",
            ],
            secretFilePaths: ["/secrets/coterm-dev.env"],
            readFile: { _ in nil }
        )
        #expect(merged["COTERM_UITEST_STACK_EMAIL"] == "agent-dev@emergent.inc")
        #expect(merged["COTERM_UITEST_STACK_PASSWORD"] == "agent-pw")
    }

    @Test func injectsNothingWhenNoCredentialsAvailable() {
        let merged = MacAuthComposition.environmentWithDogfoodAutoSignIn(
            ["HOME": "/Users/test"],
            secretFilePaths: ["/secrets/coterm-dev.env"],
            readFile: { _ in nil }
        )
        #expect(merged["COTERM_UITEST_STACK_EMAIL"] == nil)
        #expect(merged["COTERM_UITEST_STACK_PASSWORD"] == nil)
    }
}
#endif
