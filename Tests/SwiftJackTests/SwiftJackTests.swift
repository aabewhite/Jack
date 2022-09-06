import XCTest
import SwiftJack
import protocol OpenCombineShim.ObservableObject
import struct OpenCombineShim.Published

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
final class SwiftJackTests: XCTestCase {
    func testSwiftJackModule() {
        XCTAssertEqual(SwiftJackModule.shared.swiftJackName, "SwiftJack")
    }

    func testObservation() {
        class ObserveObj : ObservableObject {
            @Published var number = 0
        }

        let obj = ObserveObj()
        var changes = 0
        let obsvr1 = obj.objectWillChange.sink {
            changes += 1
        }

        var number = obj.number
        let obsvr2 = obj.$number.sink { newValue in
            number = newValue
        }

        XCTAssertEqual(0, changes)
        obj.number += 1
        XCTAssertEqual(1, changes)
        XCTAssertEqual(number, obj.number)

        let _ = (obsvr1, obsvr2)
    }

    func testJacked() {
        class JackedObj : JackedObject {
            @Jacked("n") var number = 0
            @Jacked("b") var bool = false
            @Jacked("s") var string = ""
            @Jacked("a") var array = [1, 2, 3]
            @Jacked("d") var dict = ["A": 1, "B": 2.0]
            @Jacked("t") var date = Date.distantPast
            @Jacked(nil) var unexported = UUID()

            //@Published var numberPub = 0 // mixed Jacked & Published not yet supported and will crash
        }

        let obj = JackedObj()

        obj.objectMap()

        var changes = 0
        let obsvr1 = obj.objectWillChange.sink {
            changes += 1
        }

        var numberJack = obj.number
        let obsvr3 = obj.$number.sink { numberJack = $0 }

        XCTAssertEqual(0, changes)
        obj.number += 1
        XCTAssertEqual(1, changes)
        XCTAssertEqual(numberJack, obj.number)

        XCTAssertEqual(1, changes)
        obj.string = UUID().uuidString
        XCTAssertEqual(2, changes)

        XCTAssertEqual(2, changes)
        obj.bool.toggle()
        XCTAssertEqual(3, changes)

        XCTAssertEqual(3, changes)
        obj.date = .init()
        XCTAssertEqual(4, changes)


        // mixed Jacked & Published not yet supported

//        var numberPub = obj.numberPub
//        let obsvr2 = obj.$numberPub.sink { numberPub = $0 }
//
//        XCTAssertEqual(4, changes)
//        obj.numberPub += 1
//        XCTAssertEqual(5, changes)
//        XCTAssertEqual(numberPub, obj.numberPub)

        let _ = (obsvr1, obsvr3)
    }
}
