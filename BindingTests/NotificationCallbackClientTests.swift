import Testing
@testable import Binding

struct NotificationCallbackClientTests {
    @Test
    func baseURLDefaultsToStagingDeviceCallbackAPI() {
        #expect(
            NotificationCallbackClient.baseURLString(environment: [:])
                == "https://staging.haven.digipomps.org/conference-mvp/api/device"
        )
    }

    @Test
    func baseURLPrefersEnvironmentOverride() {
        #expect(
            NotificationCallbackClient.baseURLString(
                environment: ["BINDING_NOTIFICATION_API_BASE": "http://localhost:9089/conference-mvp/api/device"]
            ) == "http://localhost:9089/conference-mvp/api/device"
        )
    }
}
