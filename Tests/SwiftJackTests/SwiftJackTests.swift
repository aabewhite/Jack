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

    func testJacked() throws {
        enum Compass : String, Jackable { case north, south, east, west }

        class JackedObj : JackedObject {
            @Jacked("n") var number = 0
            @Jacked("f") var float = 0.0
            @Jacked("b") var bool = false
            @Jacked("s") var string = ""
            @Jacked("d") var data = Data([1,2,3,4,5,6,7,8])
            @Jacked("c") var cardinal = Compass.north
//            @Jacked("a") var array = [1, 2, 3]
//            @Jacked("d") var dict = ["A": 1, "B": 2.0]
//            @Jacked(nil) var unexported = UUID()

            //@Published var numberPub = 0 // mixed Jacked & Published not yet supported and will crash
        }

        let obj = JackedObj()

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

//        XCTAssertEqual(1, changes)
//        obj.string = UUID().uuidString
//        XCTAssertEqual(2, changes)
//
//        XCTAssertEqual(2, changes)
//        obj.bool.toggle()
//        XCTAssertEqual(3, changes)
//
//        XCTAssertEqual(3, changes)
//        obj.date = .init()
//        XCTAssertEqual(4, changes)

        // mixing Jacked & Published not yet supported

//        var numberPub = obj.numberPub
//        let obsvr2 = obj.$numberPub.sink { numberPub = $0 }
//
//        XCTAssertEqual(4, changes)
//        obj.numberPub += 1
//        XCTAssertEqual(5, changes)
//        XCTAssertEqual(numberPub, obj.numberPub)

        let _ = (obsvr1, obsvr3)

        let ctx = obj.jack()

        do {
            XCTAssertEqual(1, try ctx.eval("n").numberValue)
            _ = try ctx.eval("n += 1")
            XCTAssertEqual(2, obj.number)
            _ = try ctx.eval("n += 1")
            XCTAssertEqual(3, obj.number)
        }

        do {
            _ = try ctx.eval("n = 9.12323")
            XCTAssertEqual(9, obj.number)
            XCTAssertEqual(9, try ctx.eval("n").numberValue)
        }

        do {
            changes = 0
            XCTAssertEqual(0, changes)

            _ = try ctx.eval("s = 1.2")
            XCTAssertEqual("1.2", obj.string)

            XCTAssertEqual(1, changes)

            _ = try ctx.eval("s = 'abc' + 123")
            XCTAssertEqual("abc123", obj.string)

            XCTAssertEqual(2, changes)
        }

        do {
            _ = try ctx.eval("b = false")
            XCTAssertEqual(false, obj.bool)
        }

        do {
            _ = try ctx.eval("b = true")
            XCTAssertEqual(true, obj.bool)
        }

        do {
            XCTAssertEqual("[object ArrayBuffer]", try ctx.eval("d").stringValue)
            XCTAssertEqual(8, try ctx.eval("d.byteLength").numberValue)
            XCTAssertEqual(false, try ctx.eval("d.isView").booleanValue)
            XCTAssertEqual("[object DataView]", try ctx.eval("(new DataView(d))").stringValue)

            try ctx.eval("")
        }

        do {
            XCTAssertEqual(true, try ctx.eval("b").booleanValue)
            obj.bool.toggle()
            XCTAssertEqual(false, try ctx.eval("b").booleanValue)
        }

        do {
            XCTAssertThrowsError(try ctx.eval("n = 'x'")) // valueWasNotANumber
        }

        do {
            try ctx.eval("c = 'north'")
            XCTAssertEqual(.north, obj.cardinal)
            try ctx.eval("c = 'south'")
            XCTAssertEqual(.south, obj.cardinal)
            try ctx.eval("c = 'east'")
            XCTAssertEqual(.east, obj.cardinal)
            try ctx.eval("c = 'west'")
            XCTAssertEqual(.west, obj.cardinal)

            XCTAssertThrowsError(try ctx.eval("c = 'northX'")) { error in
                // the exception gets wrapped in a JXValue and then unwrapped as a string
//                if case JackError.rawInitializerFailed(let value, _) = error {
//                    XCTAssertEqual("northX", value.stringValue)
//                } else {
//                    XCTFail("wrong error: \(error)")
//                }
            }
        }
    }

    func testJackedDate() throws {
        class JackedDate : JackedObject {
            @Jacked var date = Date(timeIntervalSince1970: 0)
            lazy var ctx = jack()
        }

        let obj = JackedDate()

        XCTAssertEqual(Date(timeIntervalSince1970: 0), obj.date)
        XCTAssertEqual("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)", try obj.ctx.eval("date").stringValue)
        XCTAssertEqual(0, try obj.ctx.eval("date").numberValue)

        obj.date = .distantPast
        XCTAssertEqual(-62135596800000, try obj.ctx.eval("date").numberValue)

        obj.date = .distantFuture
        XCTAssertEqual(64092211200000, try obj.ctx.eval("date").numberValue)

        XCTAssertEqual(Date().timeIntervalSinceReferenceDate, try obj.ctx.eval("date = new Date()").dateValue?.timeIntervalSinceReferenceDate ?? 0, accuracy: 0.001, "date should agree to the millisecond")

//        XCTAssertEqual(Data([1, 2, 3]), obj.data)
    }

    func testJackedData() throws {
        class JackedData : JackedObject {
            @Jacked var data = Data()
            lazy var ctx = jack()
        }

        let obj = JackedData()

        XCTAssertEqual(Data(), obj.data)
        XCTAssertEqual("1,2,3", try obj.ctx.eval("data = [1, 2, 3]").stringValue)
        XCTAssertEqual(Data([1, 2, 3]), obj.data)

        XCTAssertEqual(99, try obj.ctx.eval("data[0] = 99").numberValue)
        XCTAssertNotEqual(99, obj.data.first, "array element assignment shouldn't work")

        // need to pad out the array before we can convert it to a buffer
        XCTAssertThrowsError(try obj.ctx.eval("(new Int32Array(data))[0] = 99"))

        XCTAssertEqual(3, obj.data.count)
        obj.data.append(contentsOf: Data(repeating: 0, count: 8 - (obj.data.count % 8))) // pad the array
        XCTAssertEqual(8, obj.data.count)

        XCTAssertEqual(99, try obj.ctx.eval("(new Int32Array(data))[0] = 99").numberValue)
        XCTAssertNotEqual(99, obj.data.first, "assignment through Int32Array should work")

        XCTAssertEqual(999, try obj.ctx.eval("(new Int32Array(data))[7] = 999").numberValue)
        XCTAssertNotEqual(255, obj.data.last, "assignment to overflow value should round to byte")

        let oldData = Data(obj.data)
        XCTAssertEqual(0, try obj.ctx.eval("(new Int32Array(data))[999] = 0").numberValue)
        XCTAssertEqual(oldData, obj.data, "assignment beyond bounds should have no effect")
    }

    func testJackedNumbers() throws {
        class JackedObj : JackedObject {
            @Jacked var dbl = 0.0
            lazy var ctx = jack()
        }

        let obj = JackedObj()

        XCTAssertEqual(.pi, try obj.ctx.eval("dbl = Math.PI").numberValue)
        XCTAssertEqual(3.141592653589793, obj.dbl)

        XCTAssertEqual(2.718281828459045, try obj.ctx.eval("dbl = Math.E").numberValue)
        XCTAssertEqual(2.718281828459045, obj.dbl)

        XCTAssertEqual(sqrt(2.0), try obj.ctx.eval("dbl = Math.sqrt(2)").numberValue)
        XCTAssertEqual(1.4142135623730951, obj.dbl)

        try obj.ctx.eval("dbl = Math.sqrt(-1)")
        XCTAssertTrue(obj.dbl.isNaN)
    }
}
