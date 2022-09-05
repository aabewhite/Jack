import XCTest
@testable import SwiftJack

final class SwiftJackTests: XCTestCase {
    func testSwiftJackModule() {
        XCTAssertEqual(SwiftJackModule().internalSwiftJackData, "Hi SwiftJack!")
    }
}
