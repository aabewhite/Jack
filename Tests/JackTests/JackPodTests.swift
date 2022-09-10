import XCTest
import Jack

// MARK: JackPod

/// A ``JackPod`` is a unit of native functionality that can be exported to a scripting environment via a ``JackedObject``.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
public protocol JackPod : JackedObject {
    /// The metadata for this pod
    var metadata: JackPodMetaData { get }
    var podContext: JXContext { get }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
public struct JackPodMetaData : Codable {
    public var author: String
    public var homePage: URL
}


@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
final class JackPodTests: XCTestCase {
    func testTimersPod() async throws {
        let tp = TimersPod()
        try await tp.jsc.eval("sleep()", priority: .high)
        try await tp.jsc.eval("sleep(0)", priority: .high)
        try await tp.jsc.eval("sleep(0, 1)", priority: .high)
        try await tp.jsc.eval("sleep(0, 1.2, 'x')", priority: .high)
        try await tp.jsc.eval("sleep(0.0000000001)", priority: .high)

        do {
            try await tp.jsc.eval("sleep(NaN)", priority: .high)
            XCTFail("should not have succeeded")
        } catch {
            XCTAssertEqual("Error: sleepDurationNaN", "\(error)")
        }

    }
}


// MARK: TimersPod

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
public class TimersPod : JackPod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(author: "XXX", homePage: URL(string: "https://www.example.com")!)
    }

    public var podContext: JXContext {
        jsc
    }

    @Jumped("sleep") var _sleep = sleep
    func sleep(duration: TimeInterval) async throws {
        if duration.isNaN {
            throw Errors.sleepDurationNaN
        }
        try await Task.sleep(nanoseconds: .init(duration * 1_000_000_000))
    }

    enum Errors : Error {
        case sleepDurationNaN
    }

    lazy var jsc = jack()
}

// setTimeout()
// await sleep(123)

// MARK: ConsolePod

// console.log('message…')

// MARK: FileSystemPod

// fs.mkdir('/tmp/dir')

// MARK: FetchPod

// fetch('https://example.org/resource.json')

// MARK: CoreLocationPod

// await location.current()

// MARK: CanvasPod

// MARK: CanvasPod

