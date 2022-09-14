import Foundation
import Jack


// MARK: ConsolePod

@available(macOS 11, iOS 13, tvOS 13, *)
public protocol ConsolePod : JackPod {
}

// console.log('message…')

/// A ``ConsolePod`` that stores messages in a buffer
@available(macOS 11, iOS 13, tvOS 13, *)
public class CapturingConsolePod : JackPod, ConsolePod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()
}

#if canImport(OSLog)
import OSLog

/// A ``ConsolePod`` that forwards logged messages to the system consle
@available(macOS 11, iOS 13, tvOS 13, *)
public class OSLogConsolePod : JackPod, ConsolePod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()
}
#endif


#if canImport(XCTest)
import XCTest

@available(macOS 11, iOS 13, tvOS 13, *)
final class ConsolePodTests: XCTestCase {
    #if canImport(OSLog)
    func testConsolePod() async throws {
        let pod = OSLogConsolePod()

        XCTAssertEqual(3, try pod.jxc.eval("1+2").numberValue)
    }
    #endif
}
#endif
