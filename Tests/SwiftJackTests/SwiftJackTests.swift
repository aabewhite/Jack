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
        class JackedObj : JackedObject {
            @Jacked("n") var integer = 0
            @Jacked("f") var float = 0.0
            @Jacked("b") var bool = false
            @Jacked("s") var string = ""
        }

        let obj = JackedObj()

        var changes = 0
        let obsvr1 = obj.objectWillChange.sink {
            changes += 1
        }

        var integerJack = obj.integer
        let obsvr3 = obj.$integer.sink { integerJack = $0 }

        XCTAssertEqual(0, changes)
        obj.integer += 1
        XCTAssertEqual(1, changes)
        XCTAssertEqual(integerJack, obj.integer)

        let _ = (obsvr1, obsvr3)

        let ctx = obj.jack()

        do {
            XCTAssertEqual(1, try ctx.eval("n").numberValue)
            try ctx.eval("n += 1")
            XCTAssertEqual(2, obj.integer)
            try ctx.eval("n += 1")
            XCTAssertEqual(3, obj.integer)
        }

        do {
            try ctx.eval("n = 9.12323")
            XCTAssertEqual(9, obj.integer)
            XCTAssertEqual(9, try ctx.eval("n").numberValue)
        }

        do {
            changes = 0
            XCTAssertEqual(0, changes)

            XCTAssertThrowsError(try ctx.eval("s = 1.2"), "expected .valueWasNotAString error")
            XCTAssertEqual("", obj.string)
            XCTAssertEqual(1, changes) // even though it threw an error, it will still trigger the `objectWillChange`, since that is invoked before the attempt

            try ctx.eval("s = 'x'")
            XCTAssertEqual("x", obj.string)
            XCTAssertEqual(2, changes)

            try ctx.eval("s = 'abc' + 123")
            XCTAssertEqual("abc123", obj.string)
            XCTAssertEqual(3, changes)
        }

        do {
            try ctx.eval("b = false")
            XCTAssertEqual(false, obj.bool)
        }

        do {
            try ctx.eval("b = true")
            XCTAssertEqual(true, obj.bool)
        }

        do {
            XCTAssertEqual(true, try ctx.eval("b").booleanValue)
            obj.bool.toggle()
            XCTAssertEqual(false, try ctx.eval("b").booleanValue)
        }

        do {
            XCTAssertThrowsError(try ctx.eval("n = 'x'")) // valueWasNotANumber
        }
    }

    func testJackedArray() throws {
        class JackedObj : JackedObject {
            @Jacked("sa") var stringArray = ["a", "b", "c"]
            lazy var ctx = jack()
        }

        let obj = JackedObj()

        do {
            XCTAssertEqual("a,b,c", try obj.ctx.eval("sa").stringValue)
            XCTAssertEqual(3, try obj.ctx.eval("sa.length").numberValue)

            XCTAssertEqual(["a", "b", "c"], obj.stringArray)
            XCTAssertEqual(4, try obj.ctx.eval("sa.push('q')").numberValue)

            XCTAssertEqual("a,b,c", try obj.ctx.eval("sa").stringValue, "Array.push doesn't work")
            XCTAssertEqual(["a", "b", "c"], obj.stringArray)

            XCTAssertEqual(["q"], try obj.ctx.eval("sa = ['q']").array?.compactMap(\.stringValue))
            XCTAssertEqual(["q"], obj.stringArray)

            XCTAssertEqual([], try obj.ctx.eval("sa = []").array?.compactMap(\.stringValue))
            XCTAssertEqual([], obj.stringArray)

            XCTAssertThrowsError(try obj.ctx.eval("sa = [1]"), "expected .valueWasNotAString error")
            XCTAssertThrowsError(try obj.ctx.eval("sa = [false]"), "expected .valueWasNotAString error")
            XCTAssertThrowsError(try obj.ctx.eval("sa = [null]"), "expected .valueWasNotAString error")

            XCTAssertEqual(1, try obj.ctx.eval("sa.push('x')").numberValue) // TODO: how to handle `Array.push`?
            XCTAssertEqual(0, try obj.ctx.eval("let x = sa; sa = x").numberValue)
            XCTAssertEqual([], obj.stringArray)
        }
    }

    func testJackedDate() throws {
        class JackedDate : JackedObject {
            @Jacked var date = Date(timeIntervalSince1970: 0)
            lazy var ctx = jack()
        }

        let obj = JackedDate()

        XCTAssertEqual(Date(timeIntervalSince1970: 0), obj.date)

        // /home/runner/work/SwiftJack/SwiftJack/Tests/SwiftJackTests/SwiftJackTests.swift:132: error: SwiftJackTests.testJackedDate : XCTAssertEqual failed: ("Optional("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)")") is not equal to ("Optional("Thu Jan 01 1970 00:00:00 GMT+0000 (UTC)")") -
        // XCTAssertEqual("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)", try obj.ctx.eval("date").stringValue)


        XCTAssertEqual(0, try obj.ctx.eval("date").numberValue)

        obj.date = .distantPast

        #if os(Linux) // sigh
        XCTAssertEqual(-62104233600000, try obj.ctx.eval("date").numberValue)
        #else
        XCTAssertEqual(-62135596800000, try obj.ctx.eval("date").numberValue)
        #endif

        obj.date = .distantFuture
        XCTAssertEqual(64092211200000, try obj.ctx.eval("date").numberValue)

        XCTAssertEqual(Date().timeIntervalSinceReferenceDate, try obj.ctx.eval("date = new Date()").dateValue?.timeIntervalSinceReferenceDate ?? 0, accuracy: 0.01, "date should agree")

        // XCTAssertEqual(Data([1, 2, 3]), obj.data)
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

    func testJackedEnum() throws {
        enum Compass : String, Jackable { case north, south, east, west }
        enum Direction : Int, Jackable { case up, down, left, right }

        class JackedObj : JackedObject {
            @Jacked("c") var stringEnum = Compass.north
            @Jacked("d") var intEnum = Direction.left
            lazy var ctx = jack()
        }

        let obj = JackedObj()

        do {
            XCTAssertEqual(.north, obj.stringEnum)

            XCTAssertEqual("north", try obj.ctx.eval("c = 'north'").stringValue)
            XCTAssertEqual(.north, obj.stringEnum)

            XCTAssertEqual("south", try obj.ctx.eval("c = 'south'").stringValue)
            XCTAssertEqual(.south, obj.stringEnum)

            XCTAssertEqual("east", try obj.ctx.eval("c = 'east'").stringValue)
            XCTAssertEqual(.east, obj.stringEnum)

            XCTAssertEqual("west", try obj.ctx.eval("c = 'west'").stringValue)
            XCTAssertEqual(.west, obj.stringEnum)

            XCTAssertThrowsError(try obj.ctx.eval("c = 'northX'")) { error in
                // the exception gets wrapped in a JXValue and then unwrapped as a string
                //                if case JackError.rawInitializerFailed(let value, _) = error {
                //                    XCTAssertEqual("northX", value.stringValue)
                //                } else {
                //                    XCTFail("wrong error: \(error)")
                //                }
            }
        }

        do {
            XCTAssertEqual(.left, obj.intEnum)

            XCTAssertEqual(3, try obj.ctx.eval("d = 3").numberValue)
            XCTAssertEqual(.right, obj.intEnum)

            XCTAssertEqual(0, try obj.ctx.eval("d = 0").numberValue)
            XCTAssertEqual(.up, obj.intEnum)

            XCTAssertEqual(2, try obj.ctx.eval("d = 2").numberValue)
            XCTAssertEqual(.left, obj.intEnum)

            XCTAssertEqual(1, try obj.ctx.eval("d = 1").numberValue)
            XCTAssertEqual(.down, obj.intEnum)

            XCTAssertThrowsError(try obj.ctx.eval("d = 4")) { error in
            }
            XCTAssertEqual(.down, obj.intEnum)
        }

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
