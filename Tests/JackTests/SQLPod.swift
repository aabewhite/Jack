import Foundation
import Jack

// MARK: SQLPod

@available(macOS 11, iOS 13, tvOS 13, *)
public protocol SQLPod : JackPod {
}

// MARK: SQLitePod

#if canImport(SQLite3)
import SQLite3

@available(macOS 11, iOS 13, tvOS 13, *)
public class SQLitePod : JackPod, SQLPod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()
}
#endif

#if canImport(XCTest)
import XCTest

@available(macOS 11, iOS 13, tvOS 13, *)
final class SQLPodTests: XCTestCase {
    func testSQLitePod() async throws {
        let pod = SQLitePod()
        //try await pod.jxc.eval("sleep()", priority: .high)
        XCTAssertEqual(3, try pod.jxc.eval("1+2").numberValue)
    }
}
#endif
