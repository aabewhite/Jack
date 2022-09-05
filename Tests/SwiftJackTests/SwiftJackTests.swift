import XCTest
import SwiftJack

final class SwiftJackTests: XCTestCase {
    func testSwiftJackModule() {
        XCTAssertEqual(SwiftJackModule.shared.publicSwiftJackData, "Hi SwiftJack!")
    }
}
