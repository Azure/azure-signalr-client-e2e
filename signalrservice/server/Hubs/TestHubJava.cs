// Separate hub class so Java E2E tests get their own logical hub in
// Azure SignalR Service, avoiding cross-SDK message pollution when
// multiple test suites run in parallel against the same resource.

namespace IntegrationTest.Hubs;

public class TestHubJava : TestHub { }
