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

    func testPingPongExample() throws {

        class PingPongNative : ObservableObject {
            @Published var score = 0

            /// - Returns: true if a point was scored
            func ping() -> Bool {
                if Bool.random() == true {
                    self.score += 1
                    return true // score
                } else {
                    return false // returned
                }
            }
        }

        class PingPongScripted : JackedObject {
            @Jacked var score = 0
            private lazy var jsc = jack() // a JSContext bound to this instance

            /// - Returns: true if a point was scored
            func pong() throws -> Bool {
                // evaluate the javascript with "score" as a readable/writable property
                try jsc.eval("Math.random() > 0.5 ? this.score += 1 : false").booleanValue
            }
        }

        let playerA = PingPongNative()
        let playerB = PingPongScripted()

        var server: AnyObject = Bool.random() ? playerA : playerB

        let announcer = playerA.$score.combineLatest(playerB.$score).sink { scoreA, scoreB in
            print("SCORE:", scoreA, scoreB, "Serving:", server === playerA ? "SWIFT" : "JAVASCRIPT")
        }

        while playerA.score < 21 && playerB.score < 21 {
            if server === playerA {
                while try !playerA.ping() && !playerB.pong() { continue }
            } else if server === playerB {
                while try !playerB.pong() && !playerA.ping() { continue }
            }
            if (playerA.score + playerB.score) % 5 == 0 {
                print("Switching Servers")
                server = server === playerA ? playerB : playerA
            }
        }

        print("Winner: ", playerA.score > playerB.score ? "Swift" : "JavaScript")
        _ = announcer // no longer needed
    }

    func testPingPongPerformance() {
        measure {
            try? testPingPongExample()
        }
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

        let jsc = obj.jack()

        do {
            XCTAssertEqual(1, try jsc.eval("n").numberValue)
            try jsc.eval("n += 1")
            XCTAssertEqual(2, obj.integer)
            try jsc.eval("n += 1")
            XCTAssertEqual(3, obj.integer)
        }

        do {
            try jsc.eval("n = 9.12323")
            XCTAssertEqual(9, obj.integer)
            XCTAssertEqual(9, try jsc.eval("n").numberValue)
        }

        do {
            changes = 0
            XCTAssertEqual(0, changes)

            XCTAssertThrowsError(try jsc.eval("s = 1.2"), "expected .valueWasNotAString error")
            XCTAssertEqual("", obj.string)
            XCTAssertEqual(1, changes) // even though it threw an error, it will still trigger the `objectWillChange`, since that is invoked before the attempt

            try jsc.eval("s = 'x'")
            XCTAssertEqual("x", obj.string)
            XCTAssertEqual(2, changes)

            try jsc.eval("s = 'abc' + 123")
            XCTAssertEqual("abc123", obj.string)
            XCTAssertEqual(3, changes)
        }

        do {
            try jsc.eval("b = false")
            XCTAssertEqual(false, obj.bool)
        }

        do {
            try jsc.eval("b = true")
            XCTAssertEqual(true, obj.bool)
        }

        do {
            XCTAssertEqual(true, try jsc.eval("b").booleanValue)
            obj.bool.toggle()
            XCTAssertEqual(false, try jsc.eval("b").booleanValue)
        }

        do {
            XCTAssertThrowsError(try jsc.eval("n = 'x'")) // valueWasNotANumber
        }
    }

    func testJackedArray() throws {
        class JackedObj : JackedObject {
            @Jacked("sa") var stringArray = ["a", "b", "c"]
            lazy var jsc = jack()
        }

        let obj = JackedObj()

        do {
            XCTAssertEqual("a,b,c", try obj.jsc.eval("sa").stringValue)
            XCTAssertEqual(3, try obj.jsc.eval("sa.length").numberValue)

            XCTAssertEqual(["a", "b", "c"], obj.stringArray)
            XCTAssertEqual(4, try obj.jsc.eval("sa.push('q')").numberValue)

            XCTAssertEqual("a,b,c", try obj.jsc.eval("sa").stringValue, "Array.push doesn't work")
            XCTAssertEqual(["a", "b", "c"], obj.stringArray)

            XCTAssertEqual(["q"], try obj.jsc.eval("sa = ['q']").array?.compactMap(\.stringValue))
            XCTAssertEqual(["q"], obj.stringArray)

            XCTAssertEqual([], try obj.jsc.eval("sa = []").array?.compactMap(\.stringValue))
            XCTAssertEqual([], obj.stringArray)

            XCTAssertThrowsError(try obj.jsc.eval("sa = [1]"), "expected .valueWasNotAString error")
            XCTAssertThrowsError(try obj.jsc.eval("sa = [false]"), "expected .valueWasNotAString error")
            XCTAssertThrowsError(try obj.jsc.eval("sa = [null]"), "expected .valueWasNotAString error")

            XCTAssertEqual(1, try obj.jsc.eval("sa.push('x')").numberValue) // TODO: how to handle `Array.push`?
            XCTAssertEqual(0, try obj.jsc.eval("let x = sa; sa = x").numberValue)
            XCTAssertEqual([], obj.stringArray)
        }
    }

    func testJackedDate() throws {
        class JackedDate : JackedObject {
            @Jacked var date = Date(timeIntervalSince1970: 0)
            lazy var jsc = jack()
        }

        let obj = JackedDate()

        XCTAssertEqual(Date(timeIntervalSince1970: 0), obj.date)

        // /home/runner/work/SwiftJack/SwiftJack/Tests/SwiftJackTests/SwiftJackTests.swift:132: error: SwiftJackTests.testJackedDate : XCTAssertEqual failed: ("Optional("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)")") is not equal to ("Optional("Thu Jan 01 1970 00:00:00 GMT+0000 (UTC)")") -
        // XCTAssertEqual("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)", try obj.jsc.eval("date").stringValue)


        XCTAssertEqual(0, try obj.jsc.eval("date").numberValue)

        obj.date = .distantPast

        #if os(Linux) // sigh
        XCTAssertEqual(-62104233600000, try obj.jsc.eval("date").numberValue)
        #else
        XCTAssertEqual(-62135596800000, try obj.jsc.eval("date").numberValue)
        #endif

        obj.date = .distantFuture
        XCTAssertEqual(64092211200000, try obj.jsc.eval("date").numberValue)

        XCTAssertEqual(Date().timeIntervalSinceReferenceDate, try obj.jsc.eval("date = new Date()").dateValue?.timeIntervalSinceReferenceDate ?? 0, accuracy: 0.01, "date should agree")

        // XCTAssertEqual(Data([1, 2, 3]), obj.data)
    }

    func testJackedData() throws {
        class JackedData : JackedObject {
            @Jacked var data = Data()
            lazy var jsc = jack()
        }

        let obj = JackedData()

        XCTAssertEqual(Data(), obj.data)
        XCTAssertEqual("1,2,3", try obj.jsc.eval("data = [1, 2, 3]").stringValue)
        XCTAssertEqual(Data([1, 2, 3]), obj.data)

        XCTAssertEqual(99, try obj.jsc.eval("data[0] = 99").numberValue)
        XCTAssertNotEqual(99, obj.data.first, "array element assignment shouldn't work")

        // need to pad out the array before we can convert it to a buffer
        XCTAssertThrowsError(try obj.jsc.eval("(new Int32Array(data))[0] = 99"))

        XCTAssertEqual(3, obj.data.count)
        obj.data.append(contentsOf: Data(repeating: 0, count: 8 - (obj.data.count % 8))) // pad the array
        XCTAssertEqual(8, obj.data.count)

        XCTAssertEqual(99, try obj.jsc.eval("(new Int32Array(data))[0] = 99").numberValue)
        XCTAssertNotEqual(99, obj.data.first, "assignment through Int32Array should work")

        XCTAssertEqual(999, try obj.jsc.eval("(new Int32Array(data))[7] = 999").numberValue)
        XCTAssertNotEqual(255, obj.data.last, "assignment to overflow value should round to byte")

        let oldData = Data(obj.data)
        XCTAssertEqual(0, try obj.jsc.eval("(new Int32Array(data))[999] = 0").numberValue)
        XCTAssertEqual(oldData, obj.data, "assignment beyond bounds should have no effect")
    }

    func testJackedEnum() throws {
        enum Compass : String, Jackable { case north, south, east, west }
        enum Direction : Int, Jackable { case up, down, left, right }

        class JackedObj : JackedObject {
            @Jacked("c") var stringEnum = Compass.north
            @Jacked("d") var intEnum = Direction.left
            lazy var jsc = jack()
        }

        let obj = JackedObj()

        do {
            XCTAssertEqual(.north, obj.stringEnum)

            XCTAssertEqual("north", try obj.jsc.eval("c = 'north'").stringValue)
            XCTAssertEqual(.north, obj.stringEnum)

            XCTAssertEqual("south", try obj.jsc.eval("c = 'south'").stringValue)
            XCTAssertEqual(.south, obj.stringEnum)

            XCTAssertEqual("east", try obj.jsc.eval("c = 'east'").stringValue)
            XCTAssertEqual(.east, obj.stringEnum)

            XCTAssertEqual("west", try obj.jsc.eval("c = 'west'").stringValue)
            XCTAssertEqual(.west, obj.stringEnum)

            XCTAssertThrowsError(try obj.jsc.eval("c = 'northX'")) { error in
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

            XCTAssertEqual(3, try obj.jsc.eval("d = 3").numberValue)
            XCTAssertEqual(.right, obj.intEnum)

            XCTAssertEqual(0, try obj.jsc.eval("d = 0").numberValue)
            XCTAssertEqual(.up, obj.intEnum)

            XCTAssertEqual(2, try obj.jsc.eval("d = 2").numberValue)
            XCTAssertEqual(.left, obj.intEnum)

            XCTAssertEqual(1, try obj.jsc.eval("d = 1").numberValue)
            XCTAssertEqual(.down, obj.intEnum)

            XCTAssertThrowsError(try obj.jsc.eval("d = 4")) { error in
            }
            XCTAssertEqual(.down, obj.intEnum)
        }

    }

    func testJackedNumbers() throws {
        class JackedObj : JackedObject {
            @Jacked var dbl = 0.0
            lazy var jsc = jack()
        }

        let obj = JackedObj()

        XCTAssertEqual(.pi, try obj.jsc.eval("dbl = Math.PI").numberValue)
        XCTAssertEqual(3.141592653589793, obj.dbl)

        XCTAssertEqual(2.718281828459045, try obj.jsc.eval("dbl = Math.E").numberValue)
        XCTAssertEqual(2.718281828459045, obj.dbl)

        XCTAssertEqual(sqrt(2.0), try obj.jsc.eval("dbl = Math.sqrt(2)").numberValue)
        XCTAssertEqual(1.4142135623730951, obj.dbl)

        try obj.jsc.eval("dbl = Math.sqrt(-1)")
        XCTAssertTrue(obj.dbl.isNaN)
    }

    func testJackedCodable() throws {
        class JackedCode : JackedObject {
            @JackedCodable var info = SomeInfo(str: "XYZ", int: 123, extra: SomeInfo.ExtraInfo(dbl: 1.2, strs: ["A", "B", "C"]))
            lazy var jsc = jack()

            struct SomeInfo : Codable, Equatable {
                var str: String?
                var int: Int?
                var extra: ExtraInfo?

                struct ExtraInfo : Codable, Equatable {
                    var dbl: Double?
                    var strs: [String]?
                }
            }
        }

        let obj = JackedCode()

        XCTAssertEqual("XYZ", obj.info.str)
        XCTAssertEqual("XYZ", try obj.jsc.eval("info.str").stringValue)

        XCTAssertEqual(123, obj.info.int)
        XCTAssertEqual(123, try obj.jsc.eval("info.int").numberValue)

        XCTAssertEqual("A", obj.info.extra?.strs?[0])
        XCTAssertEqual("A", try obj.jsc.eval("info.extra.strs[0]").stringValue)

        XCTAssertEqual("QRS", try obj.jsc.eval("info.str = 'QRS'").stringValue)
        XCTAssertNotEqual("QRS", obj.info.str, "known shortcoming: setting through struct properties doesn't work")

        XCTAssertEqual("[object Object]", try obj.jsc.eval("var i = info; i.str = 'QRS'; info = i").stringValue)
        XCTAssertEqual("QRS", obj.info.str)

        XCTAssertEqual(0, try obj.jsc.eval("info = { }").dictionary?.keys.count)
        XCTAssertEqual(.init(), obj.info)

        XCTAssertEqual(1, try obj.jsc.eval("info = { str: 'abc' }").dictionary?.keys.count)
        XCTAssertEqual(.init(str: "abc"), obj.info)

        XCTAssertEqual(2, try obj.jsc.eval("info = { str: 'abc', int: 2 }").dictionary?.keys.count)
        XCTAssertEqual(.init(str: "abc", int: 2), obj.info)

        XCTAssertEqual(3, try obj.jsc.eval("info = { str: 'abc', int: 2, extra: { strs: [ 'q', 'r', 's' ] } }").dictionary?.keys.count)
        XCTAssertEqual(.init(str: "abc", int: 2, extra: .init(strs: ["q", "r", "s"])), obj.info)

    }
}
