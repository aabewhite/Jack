import Foundation
import Jack


// MARK: LocationPod

public protocol LocationPod : JackPod {
    func currentLocation() async throws -> Location
}

/// A location on earth.
public struct Location : Codable, Equatable, JXConvertible {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
}


// MARK: CoreLocationPod

// await location.current()

#if canImport(CoreLocation)
import CoreLocation

public class CoreLocationPod : NSObject, CLLocationManagerDelegate, LocationPod {
    private let manager: CLLocationManager

    @Jacked var locations: [Location] = []

    public init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        manager.delegate = self
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public func currentLocation() async throws -> Location {
        manager.requestLocation()
        // TODO: handle responses in delegate
        return try await withCheckedThrowingContinuation { c in
            c.resume(throwing: CocoaError(.featureUnsupported))
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

    }

    public lazy var pod = jack()
}
#endif


#if canImport(XCTest)
import XCTest

#if canImport(CoreLocation)
import CoreLocation

final class LocationPodTests: XCTestCase {
    func testLocationPod() async throws {
        let pod = CoreLocationPod()
        let jxc = pod.jack().env
        //try await jxc.eval("sleep()", priority: .high)
        XCTAssertEqual(3, try jxc.eval("1+2").numberValue)
    }
}
#endif

#endif
