import Foundation
import Jack

// MARK: UIPod

#if canImport(SwiftUI)
import SwiftUI

open class UIPod : JackPod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()
}
#endif

#if canImport(XCTest)
import XCTest

@available(macOS 11, iOS 14, tvOS 14, *)
final class UIPodTests: XCTestCase {

    #if canImport(SwiftUI)
    func testUIPod() async throws {
        let pod = UIPod()
        //try await pod.jxc.eval("sleep()", priority: .high)
        XCTAssertEqual(3, try pod.jxc.eval("1+2").numberValue)
    }

    func testAppStorageObservableObject() throws {
        class DemoObject : ObservableObject {
            @Published var intProp = 0
            @AppStorage("appStoragePodProp") var appValue = 1
        }

        let obj = DemoObject()
        var changes = 0
        withExtendedLifetime(obj.objectWillChange.sink { changes += 1 }) {
            XCTAssertEqual(changes, 0)
            obj.intProp += 1
            XCTAssertEqual(changes, 1)
            obj.appValue += 1
            XCTAssertGreaterThan(changes, 1, "AppStorage triggers changes in ObservableObject")
        }
    }

    /// Disabled because we raise a fatalError() when any non-Jack property wrappers are found in a JackedObject.
    func XXXtestAppStorageJackPod() throws {

        class DemoObject : JackPod {
            @Jacked var intProp = 0
            @AppStorage("appStoragePodProp") var appValue = 1

            public var metadata: JackPodMetaData {
                JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
            }

            public lazy var pod = jack()
        }

        let pod = DemoObject()
        var changes = 0
        withExtendedLifetime(pod.objectWillChange.sink { changes += 1 }) {
            XCTAssertEqual(changes, 0)
            pod.intProp += 1
            XCTAssertEqual(changes, 1)
            pod.appValue += 1
            // XCTAssertGreaterThan(changes, 1) // this would be true if it was an ObservableObject
            XCTAssertEqual(changes, 1, "AppStorage does not work with JackPod")
        }
    }

    #endif
}
#endif
