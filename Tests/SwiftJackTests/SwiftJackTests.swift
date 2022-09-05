import XCTest
import SwiftJack

import OpenCombine
//import OpenCombineShim

final class SwiftJackTests: XCTestCase {
    func testSwiftJackModule() {
        XCTAssertEqual(SwiftJackModule.shared.swiftJackName, "SwiftJack")
    }

    func testObservation() {
        class Obj : OpenCombine.ObservableObject {
            @OpenCombine.Published var number = 0
        }

        let obj = Obj()
        var number = obj.number
        let obsvr1 = obj.$number.sink { newValue in
            number = newValue
        }
        obj.number += 1
        XCTAssertEqual(number, obj.number)

        let _ = (obsvr1, obsvr1)
    }
}



