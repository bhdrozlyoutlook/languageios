import XCTest
@testable import LanguageIOS

final class AccountTests: XCTestCase {

    func testSignInPersistsAccountAndDisplayName() {
        let store = InMemoryKeyValueStore()
        let app = AppStore(environment: makeTestEnvironment(store: store))
        XCTAssertFalse(app.isSignedIn)

        app.signIn(appleUserId: "apple-123", displayName: "Ada")
        XCTAssertTrue(app.isSignedIn)
        XCTAssertEqual(app.displayName, "Ada")

        let restored = AppStore(environment: makeTestEnvironment(store: store))
        XCTAssertTrue(restored.isSignedIn)
        XCTAssertEqual(restored.displayName, "Ada")
    }

    func testSignOutClearsAccount() {
        let store = InMemoryKeyValueStore()
        let app = AppStore(environment: makeTestEnvironment(store: store))
        app.signIn(appleUserId: "apple-123", displayName: nil)
        XCTAssertTrue(app.isSignedIn)

        app.signOut()
        XCTAssertFalse(app.isSignedIn)
        XCTAssertNil(app.displayName)
    }

    func testSettingsRepositoryAccountRoundTrip() throws {
        let store = InMemoryKeyValueStore()
        let repo = UserDefaultsSettingsRepository(store: store, logger: NoopLogger())
        XCTAssertNil(repo.account)

        try repo.setAccount(Account(appleUserId: "u1", displayName: "Bob"))
        XCTAssertEqual(repo.account, Account(appleUserId: "u1", displayName: "Bob"))

        try repo.clearAccount()
        XCTAssertNil(repo.account)
    }
}
