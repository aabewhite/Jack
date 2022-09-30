import Foundation
import Jack

// MARK: SQLPod

public protocol SQLPod : JackPod {
}

// MARK: SQLitePod

#if canImport(SQLite3)
import SQLite3

public class SQLitePod : JackPod, SQLPod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()
}
#endif

#if canImport(XCTest)
import XCTest

final class SQLPodTests: XCTestCase {

    #if canImport(SQLite3)
    func testSQLitePod() async throws {
        let pod = SQLitePod()
        let jxc = pod.jack().env
        //try await pod.jxc.eval("sleep()", priority: .high)
        XCTAssertEqual(3, try jxc.eval("1+2").numberValue)
    }
    #endif
}
#endif
