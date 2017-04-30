import XCTest
@testable import CredentialsStrava

class KituraCredentialsStravaTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(Kitura_CredentialsStrava().text, "Hello, World!")
    }


    static var allTests : [(String, (Kitura_CredentialsStravaTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
