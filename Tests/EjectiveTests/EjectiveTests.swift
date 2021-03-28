import XCTest
@testable import Ejective

final class EjectiveTests: XCTestCase {
    func testEjectiveModule() {
        XCTAssertEqual(EjectiveModule().internalEjectiveData, "Hi Ejective!")
    }
}
