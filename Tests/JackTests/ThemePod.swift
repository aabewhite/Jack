import Jack
import Foundation

// MARK: ThemePod

// theme.backgroundColor = 'purple';
// theme.defaultTabItemHighlight = 'red';

@available(macOS 11, iOS 13, tvOS 13, *)
public class ThemePod : JackPod {

    init() {
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()
}

#if canImport(XCTest)
import XCTest

@available(macOS 11, iOS 13, tvOS 13, *)
final class ThemePodTests: XCTestCase {
    func testThemePod() async throws {
        let pod = ThemePod()
        //try await pod.jxc.eval("sleep()", priority: .high)
        XCTAssertEqual(3, try pod.jxc.eval("1+2").numberValue)
    }
}
#endif
