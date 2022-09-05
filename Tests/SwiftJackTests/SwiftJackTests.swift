import XCTest
import SwiftJack
import OpenCombineShim
//import OpenCombine

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


