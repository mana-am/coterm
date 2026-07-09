import Testing
@testable import CotermMobileSupport

@Suite struct UITestConfigTests {
    @Test func explicitDisableWinsOverTestHost() {
        let env = [
            "COTERM_UITEST_MOCK_DATA": "0",
            "XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration",
        ]
        #if DEBUG
        #expect(UITestConfig.mockDataEnabled(from: env) == false)
        #else
        #expect(UITestConfig.mockDataEnabled(from: env) == false)
        #endif
    }

    @Test func explicitEnableTurnsOnMockData() {
        let env = ["COTERM_UITEST_MOCK_DATA": "1"]
        #if DEBUG
        #expect(UITestConfig.mockDataEnabled(from: env) == true)
        #else
        #expect(UITestConfig.mockDataEnabled(from: env) == false)
        #endif
    }

    @Test func testHostPresenceEnablesMockDataInDebug() {
        let env = ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]
        #if DEBUG
        #expect(UITestConfig.mockDataEnabled(from: env) == true)
        #else
        #expect(UITestConfig.mockDataEnabled(from: env) == false)
        #endif
    }

    @Test func emptyEnvironmentDisablesMockData() {
        #expect(UITestConfig.mockDataEnabled(from: [:]) == false)
    }

    @Test func valueReturnsTrimmedNonEmptyWhenMockEnabled() {
        let env = [
            "COTERM_UITEST_MOCK_DATA": "1",
            "COTERM_UITEST_ADD_DEVICE_NAME": "  Work Mac  ",
        ]
        #if DEBUG
        #expect(UITestConfig.value(for: "COTERM_UITEST_ADD_DEVICE_NAME", env: env) == "Work Mac")
        #else
        #expect(UITestConfig.value(for: "COTERM_UITEST_ADD_DEVICE_NAME", env: env) == nil)
        #endif
    }

    @Test func valueIsNilWhenMockDisabled() {
        let env = ["COTERM_UITEST_ADD_DEVICE_NAME": "Work Mac"]
        #expect(UITestConfig.value(for: "COTERM_UITEST_ADD_DEVICE_NAME", env: env) == nil)
    }

    @Test func valueIsNilWhenBlank() {
        let env = [
            "COTERM_UITEST_MOCK_DATA": "1",
            "COTERM_UITEST_ADD_DEVICE_HOST": "   ",
        ]
        #expect(UITestConfig.value(for: "COTERM_UITEST_ADD_DEVICE_HOST", env: env) == nil)
    }

    // MARK: - dogfoodAttachURL (NOT mock-gated)

    /// The core P2 fix: the dogfood attach URL must be returned even when mock data
    /// is off (the real-backend dev-launch path), so iOS auto-pair actually fires.
    @Test func dogfoodAttachURLReturnedWithMockDisabled() {
        let env = [
            "COTERM_UITEST_MOCK_DATA": "0",
            "COTERM_DOGFOOD_ATTACH_URL": "coterm-ios://attach?v=1&payload=abc",
        ]
        #if DEBUG
        #expect(UITestConfig.dogfoodAttachURL(from: env) == "coterm-ios://attach?v=1&payload=abc")
        #else
        #expect(UITestConfig.dogfoodAttachURL(from: env) == nil)
        #endif
    }

    /// Regression guard: with mock off, the legacy mock-gated `attachURL`
    /// (`COTERM_UITEST_ATTACH_URL`) stays nil, which is exactly why the dedicated
    /// dogfood accessor is required for the real-backend auto-pair path.
    @Test func legacyAttachURLStaysNilWithMockDisabledButDogfoodDoesNot() {
        let env = [
            "COTERM_UITEST_MOCK_DATA": "0",
            "COTERM_UITEST_ATTACH_URL": "coterm-ios://attach?v=1&payload=legacy",
            "COTERM_DOGFOOD_ATTACH_URL": "coterm-ios://attach?v=1&payload=dogfood",
        ]
        #expect(UITestConfig.value(for: "COTERM_UITEST_ATTACH_URL", env: env) == nil)
        #if DEBUG
        #expect(UITestConfig.dogfoodAttachURL(from: env) == "coterm-ios://attach?v=1&payload=dogfood")
        #else
        #expect(UITestConfig.dogfoodAttachURL(from: env) == nil)
        #endif
    }

    @Test func dogfoodAttachURLIsTrimmed() {
        let env = ["COTERM_DOGFOOD_ATTACH_URL": "  coterm-ios://attach?v=1&payload=zzz  "]
        #if DEBUG
        #expect(UITestConfig.dogfoodAttachURL(from: env) == "coterm-ios://attach?v=1&payload=zzz")
        #else
        #expect(UITestConfig.dogfoodAttachURL(from: env) == nil)
        #endif
    }

    @Test func dogfoodAttachURLIsNilWhenAbsent() {
        #expect(UITestConfig.dogfoodAttachURL(from: [:]) == nil)
    }

    @Test func dogfoodAttachURLIsNilWhenBlank() {
        let env = ["COTERM_DOGFOOD_ATTACH_URL": "   "]
        #expect(UITestConfig.dogfoodAttachURL(from: env) == nil)
    }

    @Test func agentChatPreviewFlagIsDebugOnly() {
        let env = ["COTERM_UITEST_AGENT_CHAT_PREVIEW": "1"]
        let config = UITestEnvironmentConfig(environment: env)
        #if DEBUG
        #expect(config.agentChatPreviewEnabled == true)
        #else
        #expect(config.agentChatPreviewEnabled == false)
        #endif
    }

    @Test func agentChatPreviewFlagRequiresOne() {
        #expect(UITestEnvironmentConfig(environment: [:]).agentChatPreviewEnabled == false)
        #expect(UITestEnvironmentConfig(
            environment: ["COTERM_UITEST_AGENT_CHAT_PREVIEW": "0"]
        ).agentChatPreviewEnabled == false)
    }

    @Test func agentChatInlinePreviewFlagIsDebugOnly() {
        let env = ["COTERM_UITEST_AGENT_CHAT_INLINE_PREVIEW": "1"]
        let config = UITestEnvironmentConfig(environment: env)
        #if DEBUG
        #expect(config.agentChatInlinePreviewEnabled == true)
        #else
        #expect(config.agentChatInlinePreviewEnabled == false)
        #endif
    }

    @Test func agentChatInlinePreviewFlagRequiresOne() {
        #expect(UITestEnvironmentConfig(environment: [:]).agentChatInlinePreviewEnabled == false)
        #expect(UITestEnvironmentConfig(
            environment: ["COTERM_UITEST_AGENT_CHAT_INLINE_PREVIEW": "0"]
        ).agentChatInlinePreviewEnabled == false)
    }
}
