import XCTest
import Jack

// MARK: JackPod

/// A ``JackPod`` is a unit of native functionality that can be exported to a scripting environment via a ``JackedObject``.
@available(macOS 11, iOS 13, tvOS 13, *)
public protocol JackPod : JackedObject {
    /// The metadata for this pod
    var metadata: JackPodMetaData { get async }
    var podContext: Result<JXContext, Error> { get async }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JackPod {
    /// The primary context for the pod
    public var jsc: JXContext {
        get async throws {
            try await podContext.get()
        }
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
public struct JackPodMetaData : Codable {
    public var homePage: URL
}


@available(macOS 11, iOS 13, tvOS 13, *)
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
            //XCTAssertEqual("Error: sleepDurationNaN", "\(error)")
            XCTAssertEqual("Error: sleepDurationNaN", try (error as? JXError)?.stringValue)
        }

    }
}


// MARK: TimersPod

// setTimeout()
// await sleep(123)

@available(macOS 11, iOS 13, tvOS 13, *)
public class TimersPod : JackPod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    @Jumped("sleep") var _sleep = sleep
    func sleep(duration: TimeInterval) async throws {
        if duration.isNaN {
            throw Errors.sleepDurationNaN
        }
        if duration < 0 {
            throw Errors.sleepDurationNegative
        }
        try await Task.sleep(nanoseconds: .init(duration * 1_000_000_000))
    }

    enum Errors : Error {
        case sleepDurationNaN
        case sleepDurationNegative
    }

    public lazy var podContext = Result { jack() }
}


// MARK: FileSystemPod

// fs.mkdir('/tmp/dir')

@available(macOS 11, iOS 13, tvOS 13, *)
public class FileSystemPod : JackPod {
    let fm: FileManager

    public init(fm: FileManager = .default) {
        self.fm = fm
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var podContext = Result { jack() }

    @Jumped("fileExists") var _fileExists = fileExists
    func fileExists(atPath path: String) -> Bool {
        fm.fileExists(atPath: path)
    }

    @Jumped("createDirectory") var _createDirectory = createDirectory
    func createDirectory(atPath path: String, withIntermediateDirectories dirs: Bool) throws {
        try fm.createDirectory(atPath: path, withIntermediateDirectories: dirs)
    }
}


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

    public lazy var podContext = Result { jack() }
}

#if canImport(OSLog)
import OSLog

/// A ``ConsolePod`` that forwards logged messages to the system consle
@available(macOS 11, iOS 13, tvOS 13, *)
public class LoggingConsolePod : JackPod, ConsolePod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var podContext = Result { jack() }
}
#endif


// MARK: FetchPod

// fetch('https://example.org/resource.json')

#if canImport(FoundationNetworking)
import FoundationNetworking

@available(macOS 11, iOS 13, tvOS 13, *)
public class FetchPod : JackPod {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var podContext = Result { jack() }
}
#endif


// MARK: CoreLocationPod

// await location.current()

#if canImport(CoreLocation)
import CoreLocation

@available(macOS 11, iOS 13, tvOS 13, *)
public class CoreLocationPod : NSObject, CLLocationManagerDelegate, JackPod {
    private let manager: CLLocationManager

    @Jacked var locations: [Location] = []

    public struct Location : Codable, Equatable, Conveyable {
        public var latitude: Double
        public var longitude: Double
        public var altitude: Double
    }

    public init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        manager.delegate = self
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    func currentLocation() async throws {
        manager.requestLocation()
        // TODO: handle responses in delegate
        return try await withCheckedThrowingContinuation { c in
            c.resume(throwing: CocoaError(.featureUnsupported))
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

    }

    public lazy var podContext = Result { jack() }
}
#endif


// MARK: CanvasPod

@available(macOS 11, iOS 13, tvOS 13, *)
public protocol CanvasPod : JackPod {
}

#if canImport(CoreGraphics)
import CoreGraphics

@available(macOS 11, iOS 13, tvOS 13, *)
public class CoreGraphicsCanvasPod : JackPod, CanvasPod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var podContext = Result { jack() }
}
#endif

#if canImport(SwiftUI)
import SwiftUI

//@available(macOS 12, iOS 15, tvOS 15, *)
//public class SwiftUICanvasPod<Symbols : SwiftUI.View> : JackPod, CanvasPod {
//    private let canvas: Canvas<Symbols>
//
//    public init(canvas: Canvas<Symbols>) {
//        self.canvas = canvas
//    }
//
//    public var metadata: JackPodMetaData {
//        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
//    }
//
//    public lazy var podContext = Result { jack() }
//}
#endif


// MARK: DatabasePod

@available(macOS 11, iOS 13, tvOS 13, *)
public protocol DatabasePod : JackPod {
}

// MARK: SQLLitePod

#if canImport(SQLite3)
import SQLite3

@available(macOS 11, iOS 13, tvOS 13, *)
public class SQLLitePod : JackPod, DatabasePod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var podContext = Result { jack() }
}
#endif
