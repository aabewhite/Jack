import Foundation
import Jack

// MARK: NetPod

// fetch('https://example.org/resource.json')

#if canImport(Foundation)

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class NetPod : JackPod {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    // TODO
    func fetch(url: String) async throws -> Bool {
        false
    }

    public lazy var pod = jack()
}
#endif

#if canImport(XCTest)
import XCTest

final class NetPodTests: XCTestCase {
    func testNetPod() async throws {
        let pod = NetPod()
        //try await pod.jxc.eval("sleep()", priority: .high)
        XCTAssertEqual(3, try pod.jxc.eval("1+2").numberValue)
    }
}
#endif
