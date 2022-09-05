import XCTest
import SwiftJack
//import OpenCombine
import protocol OpenCombineShim.ObservableObject

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
        var number = obj.number
        let obsvr1 = obj.$number.sink { newValue in
            number = newValue
        }
        obj.number += 1
        XCTAssertEqual(number, obj.number)

        let _ = (obsvr1, obsvr1)
    }


    func testJacked() {
        class JackedObj : JackedObject {
            @Jacked var bool = false
            @Jacked var number = 0
            @Jacked var string = ""
            @Jacked var array = [1, 2, 3]
            @Jacked var dict = ["A": 1, "B": 2.0]
        }

        let obj = JackedObj()
        var number = obj.number
        let obsvr1 = obj.$number.sink { newValue in
            number = newValue
        }
        obj.number += 1
        XCTAssertEqual(number, obj.number)

        let _ = (obsvr1, obsvr1)
    }
}


