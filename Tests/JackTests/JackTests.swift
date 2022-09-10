import XCTest
import Jack
import protocol OpenCombineShim.ObservableObject
import struct OpenCombineShim.Published

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
final class JackTests: XCTestCase {
    func testObservation() {
        class Contact : JackedObject {
            @Jacked var name: String
            @Jacked var age: Int

            lazy var jsc = jack()

            init(name: String, age: Int) {
                self.name = name
                self.age = age
            }

            @Jumped("haveBirthday") var _haveBirthday = haveBirthday
            func haveBirthday() -> Int {
                age += 1
                return age
            }
        }

        let john = Contact(name: "John Appleseed", age: 24)

        var changes = 0
        let cancellable = john.objectWillChange
            .sink { _ in
                changes += 1
            }

        XCTAssertEqual(25, john.haveBirthday())
        XCTAssertEqual(1, changes)

        XCTAssertEqual(26, try john.jsc.eval("haveBirthday()").numberValue)
        XCTAssertEqual(2, changes)

        let _ = cancellable
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

#if !os(Linux) // no combineLatest
        let announcer = playerA.$score.combineLatest(playerB.$score).sink { scoreA, scoreB in
            //print("SCORE:", scoreA, scoreB, "Serving:", server === playerA ? "SWIFT" : "JAVASCRIPT")
        }
#endif

        while playerA.score < 21 && playerB.score < 21 {
            if server === playerA {
                while try !playerA.ping() && !playerB.pong() { continue }
            } else if server === playerB {
                while try !playerB.pong() && !playerA.ping() { continue }
            }
            if (playerA.score + playerB.score) % 5 == 0 {
                //print("Switching Servers")
                server = server === playerA ? playerB : playerA
            }
        }

        //print("Winner: ", playerA.score > playerB.score ? "Swift" : "JavaScript")
#if !os(Linux) // no combineLatest
        _ = announcer // no longer needed
#endif
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

        XCTAssertEqual("number", try jsc.eval("typeof n").stringValue)
        XCTAssertEqual("number", try jsc.eval("typeof f").stringValue)
        XCTAssertEqual("boolean", try jsc.eval("typeof b").stringValue)
        XCTAssertEqual("string", try jsc.eval("typeof s").stringValue)

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

    func testJackedSubclass() throws {
        class JackedSuper : JackedObject {
            @Jacked var sup = 1
        }

        class JackedSub : JackedSuper {
            @Jacked var sub = 0
        }

        let obj = JackedSub()

        var changes = 0
        
        let obsvr1 = obj.objectWillChange.sink {
            changes += 1
        }

        let jsc = obj.jack()

        XCTAssertEqual(0, changes)

        do {
            XCTAssertEqual(1, try jsc.eval("sup").numberValue)

            XCTAssertEqual(0, changes)
            try jsc.eval("sup += 1")
            XCTAssertEqual(1, changes)

            XCTAssertEqual(2, obj.sup)
            try jsc.eval("sup += 1")
            XCTAssertEqual(3, obj.sup)
            XCTAssertEqual(3, try jsc.eval("sup").numberValue)

            XCTAssertEqual(2, changes)
        }

        changes = 0

        do {
            XCTAssertEqual(0, try jsc.eval("sub").numberValue)

            XCTAssertEqual(0, changes)
            try jsc.eval("sub += 1")
            XCTAssertEqual(1, obj.sub)
            try jsc.eval("sub += 1")
            XCTAssertEqual(2, obj.sub)
            XCTAssertEqual(2, try jsc.eval("sub").numberValue)

            XCTAssertEqual(2, changes)
        }

        let _ = obsvr1
    }

    func testTracked() throws {

        class TrackedObj : JackedObject {
            @Tracked("n") var integer = 0
            @Tracked("f") var float = 0.0

            @Jacked("b") var bool = false
            @Jacked("s") var string = ""

            //@Published var published = 0 // this would crash: we cannot mix Jacked and Published properties
        }

        let obj = TrackedObj()

        var changes = 0
        let obsvr1 = obj.objectWillChange.sink {
            changes += 1
        }

        var integerJack = obj.integer
        let obsvr3 = obj.$integer.sink { integerJack = $0 }

        XCTAssertEqual(0, changes)
        XCTAssertEqual(0, integerJack)
        obj.integer += 1
        XCTAssertEqual(1, changes)
        XCTAssertEqual(1, integerJack)
        XCTAssertEqual(obj.integer, integerJack)
        XCTAssertEqual(integerJack, obj.integer)

        let _ = (obsvr1, obsvr3)

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

        // /home/runner/work/Jack/Jack/Tests/JackTests/JackTests.swift:132: error: JackTests.testJackedDate : XCTAssertEqual failed: ("Optional("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)")") is not equal to ("Optional("Thu Jan 01 1970 00:00:00 GMT+0000 (UTC)")") -
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

    func testJugglable() throws {
        class JackedCode : JackedObject {
            @Coded var info = SomeInfo(str: "XYZ", int: 123, extra: SomeInfo.ExtraInfo(dbl: 1.2, strs: ["A", "B", "C"]))
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

    func testJumped() throws {
        class JumpedObj : JackedObject {
            @Jumped private var f0 = hi
            func hi() -> Date { Date(timeIntervalSince1970: 1234) }

            @Jumped private var f1 = hello // expose the 1-arg function
            func hello(name: String) -> String { "Hello \(name)!" }

            @Jumped("F2") private var f2 = happyBirthday // expose the 2-arg function
            func happyBirthday(name: String, age: Int) -> String { "Happy Birthday \(name), you are \(age)!" }

            @Jumped("replicate") private var _replicate = replicate
            func replicate(_ coded: CodedCodable, count: Int) -> [CodedCodable] { Array(Array(repeating: coded, count: count)) }

            @Jumped("exceptional") private var _exceptional = exceptional
            func exceptional() throws -> Bool { throw SomeError(reason: "YOLO") }

            struct SomeError : Error {
                var reason: String
            }

            lazy var jsc = jack()
        }

        /// A sample of codable passing
        struct CodedCodable : Codable, Equatable, Conveyable {
            var id = UUID()
            var str = ""
            var num: Int?
        }

        let obj = JumpedObj()

        XCTAssertEqual("function", try obj.jsc.eval("typeof f0").stringValue)
        XCTAssertEqual("function", try obj.jsc.eval("typeof f1").stringValue)
        XCTAssertEqual("undefined", try obj.jsc.eval("typeof f2").stringValue, "f2 should be visible as F2")
        XCTAssertEqual("function", try obj.jsc.eval("typeof F2").stringValue)
        XCTAssertEqual("function", try obj.jsc.eval("typeof replicate").stringValue)
        XCTAssertEqual("function", try obj.jsc.eval("typeof exceptional").stringValue)

        XCTAssertEqual(1_234_000, try obj.jsc.eval("f0()").numberValue)
        XCTAssertEqual("Hello x!", try obj.jsc.eval("f1('x')").stringValue)
        XCTAssertEqual("Happy Birthday x, you are 9!", try obj.jsc.eval("F2('x', 9)").stringValue)

        let c = CodedCodable(id: UUID(uuidString: "4991E2A0-DE05-4BB3-B502-42F7584C9973")!, str: "abc", num: 9)
        XCTAssertEqual([c, c, c], try obj.jsc.eval("replicate({ id: '4991E2A0-DE05-4BB3-B502-42F7584C9973', str: 'abc', num: 9 }, 3)").toDecodable(ofType: Array<CodedCodable>.self))

        // make sure we are blocked from setting the function property from JS
        XCTAssertThrowsError(try obj.jsc.eval("f0 = null")) { error in
            XCTAssertEqual(#"evaluationErrorString("Error: cannot set a function from JS")"#, "\(error)")
        }

    }

    func testAllPropertyWrappers() throws {
        class EnhancedObj : JackedObject {
            @Tracked var x = 0 // unexported to jsc
            @Jacked var i = 1 // exported as number
            @Jacked("B") var b = false // exported as bool
            @Coded var id = UUID() // exported (via codability) as string
            @Jumped("now") private var _now = now // exported as function
            func now() -> Date { Date(timeIntervalSince1970: 1_234) }

            lazy var jsc = jack()
        }

        let obj = EnhancedObj()

        XCTAssertEqual("undefined", try obj.jsc.eval("typeof x").stringValue)
        XCTAssertEqual("number", try obj.jsc.eval("typeof i").stringValue)
        XCTAssertEqual("undefined", try obj.jsc.eval("typeof b").stringValue) // aliased away
        XCTAssertEqual("boolean", try obj.jsc.eval("typeof B").stringValue) // aliased
        XCTAssertEqual("string", try obj.jsc.eval("typeof id").stringValue)
        XCTAssertEqual("function", try obj.jsc.eval("typeof now").stringValue)
        XCTAssertEqual("object", try obj.jsc.eval("typeof now()").stringValue)
        XCTAssertEqual(1_234_000, try obj.jsc.eval("now()").numberValue)
    }

    func testJumpedVoidSignatures() async throws {
        class VoidReturns : JackedObject {
            @Jumped("void0") private var _void0 = void0
            func void0() -> Void { }

            @Jumped("tvoid0") private var _tvoid0 = tvoid0
            func tvoid0() throws -> Void { }

            @Jumped("atvoid0", priority: .low) private var _atvoid0 = atvoid0
            func atvoid0() async throws -> Void { }


            @Jumped("void1") private var _void1 = void1
            func void1(i0: Int) -> Void { }

            @Jumped("tvoid1") private var _tvoid1 = tvoid1
            func tvoid1(i0: Int) throws -> Void { }

            @Jumped("atvoid1", priority: .low) private var _atvoid1 = atvoid1
            func atvoid1(i0: Int) async throws -> Void { }


            @Jumped("void2") private var _void2 = void2
            func void2(i0: Int, i1: Int) -> Void { }

            @Jumped("tvoid2") private var _tvoid2 = tvoid2
            func tvoid2(i0: Int, i1: Int) throws -> Void { }

            @Jumped("atvoid2", priority: .low) private var _atvoid2 = atvoid2
            func atvoid2(i0: Int, i1: Int) async throws -> Void { }


            @Jumped("void3") private var _void3 = void3
            func void3(i0: Int, i1: Int, i2: Int) -> Void { }

            @Jumped("tvoid3") private var _tvoid3 = tvoid3
            func tvoid3(i0: Int, i1: Int, i2: Int) throws -> Void { }

            @Jumped("atvoid3", priority: .low) private var _atvoid3 = atvoid3
            func atvoid3(i0: Int, i1: Int, i2: Int) async throws -> Void { }


            @Jumped("void4") private var _void4 = void4
            func void4(i0: Int, i1: Int, i2: Int, i3: Int) -> Void { }

            @Jumped("tvoid4") private var _tvoid4 = tvoid4
            func tvoid4(i0: Int, i1: Int, i2: Int, i3: Int) throws -> Void { }

            @Jumped("atvoid4", priority: .low) private var _atvoid4 = atvoid4
            func atvoid4(i0: Int, i1: Int, i2: Int, i3: Int) async throws -> Void { }


            @Jumped("void5") private var _void5 = void5
            func void5(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int) -> Void { }

            @Jumped("tvoid5") private var _tvoid5 = tvoid5
            func tvoid5(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int) throws -> Void { }

            @Jumped("atvoid5", priority: .low) private var _atvoid5 = atvoid5
            func atvoid5(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int) async throws -> Void { }


            @Jumped("void6") private var _void6 = void6
            func void6(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int) -> Void { }

            @Jumped("tvoid6") private var _tvoid6 = tvoid6
            func tvoid6(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int) throws -> Void { }

            @Jumped("atvoid6", priority: .low) private var _atvoid6 = atvoid6
            func atvoid6(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int) async throws -> Void { }


            @Jumped("void7") private var _void7 = void7
            func void7(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int) -> Void { }

            @Jumped("tvoid7") private var _tvoid7 = tvoid7
            func tvoid7(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int) throws -> Void { }

            @Jumped("atvoid7", priority: .low) private var _atvoid7 = atvoid7
            func atvoid7(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int) async throws -> Void { }


            @Jumped("void8") private var _void8 = void8
            func void8(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int) -> Void { }

            @Jumped("tvoid8") private var _tvoid8 = tvoid8
            func tvoid8(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int) throws -> Void { }

            @Jumped("atvoid8", priority: .low) private var _atvoid8 = atvoid8
            func atvoid8(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int) async throws -> Void { }


            @Jumped("void9") private var _void9 = void9
            func void9(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int) -> Void { }

            @Jumped("tvoid9") private var _tvoid9 = tvoid9
            func tvoid9(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int) throws -> Void { }

            @Jumped("atvoid9", priority: .low) private var _atvoid9 = atvoid9
            func atvoid9(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int) async throws -> Void { }


            @Jumped("void10") private var _void10 = void10
            func void10(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int) -> Void { }

            @Jumped("tvoid10") private var _tvoid10 = tvoid10
            func tvoid10(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int) throws -> Void { }

            @Jumped("atvoid10", priority: .low) private var _atvoid10 = atvoid10
            func atvoid10(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int) async throws -> Void { }


            // we don't go to 11

            //@Jumped("void11") private var _void11 = void11
            //func void11(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int, i10: Int) -> Void { }

            //@Jumped("tvoid11") private var _tvoid11 = tvoid11
            //func tvoid11(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int, i10: Int) throws -> Void { }

            //@Jumped("atvoid11", priority: .low) private var _atvoid11 = atvoid11
            //func atvoid11(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int, i10: Int) async throws -> Void { }

            lazy var jsc = jack()
        }


        let obj = VoidReturns()

        try obj.jsc.eval("void0()")
        try obj.jsc.eval("tvoid0()")
        try await obj.jsc.eval("atvoid0()", priority: .low)

        try obj.jsc.eval("void1(1)")
        try obj.jsc.eval("tvoid1(1)")
        try await obj.jsc.eval("atvoid1(1)", priority: .low)

        try obj.jsc.eval("void2(1, 2)")
        try obj.jsc.eval("tvoid2(1, 2)")
        try await obj.jsc.eval("atvoid2(1, 2)", priority: .low)

        try obj.jsc.eval("void3(1, 2, 3)")
        try obj.jsc.eval("tvoid3(1, 2, 3)")
        try await obj.jsc.eval("atvoid3(1, 2, 3)", priority: .low)

        try obj.jsc.eval("void4(1, 2, 3, 4)")
        try obj.jsc.eval("tvoid4(1, 2, 3, 4)")
        try await obj.jsc.eval("atvoid4(1, 2, 3, 4)", priority: .low)

        try obj.jsc.eval("void5(1, 2, 3, 4, 5)")
        try obj.jsc.eval("tvoid5(1, 2, 3, 4, 5)")
        try await obj.jsc.eval("atvoid5(1, 2, 3, 4, 5)", priority: .low)

        try obj.jsc.eval("void6(1, 2, 3, 4, 5, 6)")
        try obj.jsc.eval("tvoid6(1, 2, 3, 4, 5, 6)")
        try await obj.jsc.eval("atvoid6(1, 2, 3, 4, 5, 6)", priority: .low)

        try obj.jsc.eval("void7(1, 2, 3, 4, 5, 6, 7)")
        try obj.jsc.eval("tvoid7(1, 2, 3, 4, 5, 6, 7)")
        try await obj.jsc.eval("atvoid7(1, 2, 3, 4, 5, 6, 7)", priority: .low)

        try obj.jsc.eval("void8(1, 2, 3, 4, 5, 6, 7, 8)")
        try obj.jsc.eval("tvoid8(1, 2, 3, 4, 5, 6, 7, 8)")
        try await obj.jsc.eval("atvoid8(1, 2, 3, 4, 5, 6, 7, 8)", priority: .low)

        try obj.jsc.eval("void9(1, 2, 3, 4, 5, 6, 7, 8, 9)")
        try obj.jsc.eval("tvoid9(1, 2, 3, 4, 5, 6, 7, 8, 9)")
        try await obj.jsc.eval("atvoid9(1, 2, 3, 4, 5, 6, 7, 8, 9)", priority: .low)

        try obj.jsc.eval("void10(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)")
        try obj.jsc.eval("tvoid10(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)")
        try await obj.jsc.eval("atvoid10(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)", priority: .low)

        XCTAssertThrowsError(try obj.jsc.eval("void11(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11)"))
    }

    func testJumpedSignatures() async throws {
        try await jumpedTests(arg: Int32.self, ret: Int32.self)
        try await jumpedTests(arg: String.self, ret: String.self)

        try await jumpedTests(arg: Int32.self, ret: String.self)
        try await jumpedTests(arg: String.self, ret: Int32.self)

        try await jumpedTests(arg: UUID.self, ret: UUID.self)
        try await jumpedTests(arg: String.self, ret: UUID.self)

        try await jumpedTests(arg: Int32.self, ret: UUID.self)
        try await jumpedTests(arg: UUID.self, ret: String.self)
        try await jumpedTests(arg: UUID.self, ret: Int32.self)

        struct RandoThing : Codable, Equatable, Randomizable, Conveyable, JSConvertable {
            let str: String
            let num: Double

            static func rnd() -> Self {
                Self(str: UUID().uuidString, num: Double.random(in: 0...100000))
            }

            var js: String {
                "{ num: \(num), str: '\(str)' }"
            }
        }

        try await jumpedTests(arg: RandoThing.self, ret: RandoThing.self)
        try await jumpedTests(arg: RandoThing.self, ret: Int32.self)
        try await jumpedTests(arg: Int32.self, ret: RandoThing.self)
        try await jumpedTests(arg: RandoThing.self, ret: String.self)
        try await jumpedTests(arg: String.self, ret: RandoThing.self)
        try await jumpedTests(arg: RandoThing.self, ret: UUID.self)
        try await jumpedTests(arg: UUID.self, ret: RandoThing.self)
    }

    private func jumpedTests<A: Conveyable & Randomizable & JSConvertable & Equatable, R: Conveyable & Randomizable & Equatable>(arg: A.Type, ret: R.Type) async throws {
        let obj = RandoJack<A, R>()

        XCTAssertNotEqual(R.rnd(), try obj.jsc.eval("func0()").convey(in: obj.jsc))
        XCTAssertNotEqual(R.rnd(), try obj.jsc.eval("tfunc0()").convey(in: obj.jsc))
        try withExtendedLifetime(try await obj.jsc.eval("atfunc0()", priority: .low)) { x in
            XCTAssertNotEqual(R.rnd(), try x.convey(in: obj.jsc))
        }

        let p: TaskPriority = TaskPriority.userInitiated

        let a1 = A.rnd()
        try obj.jsc.eval("func1(\(a1.js))")
        try obj.jsc.eval("tfunc1(\(a1.js))")
        try await obj.jsc.eval("atfunc1(\(a1.js))", priority: p)

        let a2 = A.rnd()
        try obj.jsc.eval("func2(\(a1.js), \(a2.js))")
        try obj.jsc.eval("tfunc2(\(a1.js), \(a2.js))")
        try await obj.jsc.eval("atfunc2(\(a1.js), \(a2.js))", priority: p)

        let a3 = A.rnd()
        try obj.jsc.eval("func3(\(a1.js), \(a2.js), \(a3.js))")
        try obj.jsc.eval("tfunc3(\(a1.js), \(a2.js), \(a3.js))")
        try await obj.jsc.eval("atfunc3(\(a1.js), \(a2.js), \(a3.js))", priority: p)

        let a4 = A.rnd()
        try obj.jsc.eval("func4(\(a1.js), \(a2.js), \(a3.js), \(a4.js))")
        try obj.jsc.eval("tfunc4(\(a1.js), \(a2.js), \(a3.js), \(a4.js))")
        try await obj.jsc.eval("atfunc4(\(a1.js), \(a2.js), \(a3.js), \(a4.js))", priority: p)

        let a5 = A.rnd()
        //XCTAssertEqual(a5, try obj.jsc.eval("func5(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js))").convey(in: obj.jsc))
        try obj.jsc.eval("func5(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js))")
        try obj.jsc.eval("tfunc5(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js))")
        try await obj.jsc.eval("atfunc5(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js))", priority: p)

        let a6 = A.rnd()
        try obj.jsc.eval("func6(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js))")
        try obj.jsc.eval("tfunc6(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js))")
        try await obj.jsc.eval("atfunc6(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js))", priority: p)

        let a7 = A.rnd()
        try obj.jsc.eval("func7(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js))")
        try obj.jsc.eval("tfunc7(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js))")
        try await obj.jsc.eval("atfunc7(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js))", priority: p)

        let a8 = A.rnd()
        try obj.jsc.eval("func8(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js), \(a8.js))")
        try obj.jsc.eval("tfunc8(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js), \(a8.js))")
        try await obj.jsc.eval("atfunc8(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js), \(a8.js))", priority: p)

        let a9 = A.rnd()
        try obj.jsc.eval("func9(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js), \(a8.js), \(a9.js))")
        try obj.jsc.eval("tfunc9(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js), \(a8.js), \(a9.js))")
        try await obj.jsc.eval("atfunc9(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js), \(a8.js), \(a9.js))", priority: p)

        let a10 = A.rnd()
        try obj.jsc.eval("func10(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js), \(a8.js), \(a9.js), \(a10.js))")
        try obj.jsc.eval("tfunc10(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js), \(a8.js), \(a9.js), \(a10.js))")
        try await obj.jsc.eval("atfunc10(\(a1.js), \(a2.js), \(a3.js), \(a4.js), \(a5.js), \(a6.js), \(a7.js), \(a8.js), \(a9.js), \(a10.js))", priority: p)
    }

    func testJumpedAsync() async throws {
        class JumpedObj : JackedObject {
            @Jumped("promise0", priority: .background) private var _promise0 = promise0
            func promise0() async throws -> Int {
                13
            }

            @Jumped("promise1", priority: .background) private var _promise1 = promise1
            func promise1(number: Int) async throws -> String {
                "\(number)"
            }

            @Jumped("sleepTask", priority: .high) private var _sleepTask = sleepTask
            func sleepTask(duration: TimeInterval) async throws -> TimeInterval {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                return duration
            }

            lazy var jsc = jack()
        }

        let obj = JumpedObj()

        XCTAssertEqual("[object Promise]", try obj.jsc.eval("new Promise((resolve, reject) => { resolve(1) })").stringValue)
        XCTAssertEqual(true, try obj.jsc.eval("new Promise((resolve, reject) => { resolve(1) }).then").isFunction)
        XCTAssertEqual("[object Promise]", try obj.jsc.eval("new Promise((resolve, reject) => { resolve(1) }).then()").stringValue)

        XCTAssertEqual("function", try obj.jsc.eval("typeof promise0").stringValue)
        XCTAssertEqual("[object CallbackObject]", try obj.jsc.eval("promise0").stringValue)
        XCTAssertEqual("[object Promise]", try obj.jsc.eval("promise0()").stringValue)

        XCTAssertEqual(true, try obj.jsc.eval("promise0()").isObject)
        XCTAssertEqual(false, try obj.jsc.eval("promise0()").isFunction)

        do {
            let lres = try await obj.jsc.eval("promise0()", priority: .userInitiated)
            XCTAssertEqual(13, lres.numberValue)
        }

        do {
            let lres = try await obj.jsc.eval("promise1(12)", priority: .userInitiated)
            XCTAssertEqual("12", lres.stringValue)
        }

        do {
            let l8r = try await obj.jsc.eval("(async () => { return 999 })()", priority: .high)
            XCTAssertEqual(999, l8r.numberValue)
        } catch {
            XCTFail("\(error)")
        }

        do {
            try await obj.jsc.eval("999", priority: .userInitiated)
            XCTFail("should not have been able to async invoke a sync function")
        } catch {
            XCTAssertEqual("asyncEvalMustReturnPromise", "\(error)")
        }

        do {
            let l8r = try await obj.jsc.eval("(async () => { throw Error('async error') })()", priority: .userInitiated)
            XCTFail("should have thrown: \(l8r)")
        } catch {
            XCTAssertEqual("Error: async error", "\(error)")
        }

        try await obj.jsc.eval("sleepTask(0.1)", priority: .medium)
    }

    func testJumpedAsyncParams() async throws {
        class JumpedObj : JackedObject {
            @Jumped private var h0 = hi
            func hi() async throws -> Date { Date(timeIntervalSince1970: 1234) }

            @Jumped private var h1 = hello // expose the 1-arg function
            func hello(name: String) async throws -> String { "Hello \(name)!" }

            @Jumped("H2") private var h2 = happyBirthday // expose the 2-arg function
            func happyBirthday(name: String, age: Int) async throws -> String { "Happy Birthday \(name), you are \(age)!" }

            @Jumped("replicate") private var _replicate = replicate
            func replicate(_ coded: Coded, count: Int) async throws -> [Coded] { Array(Array(repeating: coded, count: count)) }

            @Jumped private var _sleep = sleep
            func sleep(interval: TimeInterval) async throws -> Bool {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                return true // TODO: hanle returning void
            }

            @Jumped("bye") private var _goodbye = goodbye // expose a void function
            func goodbye() throws { print("goodbye called") }

            @Jumped("byebye") private var _goodbye1 = goodbye1 // expose a void function
            func goodbye1(x: Int) throws { print("goodbye1 called") }


            lazy var jsc = jack()
        }

        /// A sample of codable passing
        struct Coded : Codable, Equatable, Conveyable {
            var id = UUID()
            var str = ""
            var num: Int?
        }

        let obj = JumpedObj()

        XCTAssertEqual("function", try obj.jsc.eval("typeof h0").stringValue)
        XCTAssertEqual("function", try obj.jsc.eval("typeof h1").stringValue)
        XCTAssertEqual("undefined", try obj.jsc.eval("typeof h2").stringValue)
        XCTAssertEqual("function", try obj.jsc.eval("typeof H2").stringValue)

//        do {
//            let x = try await obj.jsc.eval("sleep(1)", priority: .medium).booleanValue
//            XCTAssertEqual(false, x)
//        }

        do {
            let x = try await obj.jsc.eval("h0()", priority: .medium).numberValue
            XCTAssertEqual(1_234_000, x)
        }

        do {
            let x = try await obj.jsc.eval("h1('x')", priority: .high).stringValue
            XCTAssertEqual("Hello x!", x)
        }

        do {
            let x = try await obj.jsc.eval("H2('x', 9)", priority: .userInitiated).stringValue
            XCTAssertEqual("Happy Birthday x, you are 9!", x)
        }

        do {
            let c = Coded(id: UUID(uuidString: "4991E2A0-DE05-4BB3-B502-42F7584C9973")!, str: "abc", num: 9)
            let x = try await obj.jsc.eval("replicate({ id: '4991E2A0-DE05-4BB3-B502-42F7584C9973', str: 'abc', num: 9 }, 3)", priority: .userInitiated)
            XCTAssertEqual([c, c, c], try x.toDecodable(ofType: Array<Coded>.self))
        }

        // make sure we are blocked from setting the function property from JS
        XCTAssertThrowsError(try obj.jsc.eval("h0 = null")) { error in
            XCTAssertEqual(#"evaluationErrorString("Error: cannot set a function from JS")"#, "\(error)")
        }

        try obj.jsc.eval("bye()")
        try obj.jsc.eval("byebye()")
    }

}

private protocol Randomizable { static func rnd() -> Self }
private protocol JSConvertable { var js: String { get } }

extension UUID : Randomizable, Conveyable, JSConvertable {
    static func rnd() -> Self {
        UUID()
    }

    var js: String {
        "'" + self.uuidString + "'"
    }
}

extension String : Randomizable, JSConvertable {
    static func rnd() -> Self {
        UUID().uuidString
    }

    var js: String {
        "'" + self.self.replacingOccurrences(of: "'", with: "\\'") + "'"
    }
}

extension Int32 : Randomizable, JSConvertable {
    static func rnd() -> Self {
        .random(in: (.min)...(.max))
    }

    var js: String {
        self.description
    }
}

/// A generic jumpable type that represents functions with all the possible arities.
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
private class RandoJack<ArgType: Conveyable, ReturnType: Randomizable & Conveyable> : JackedObject {
    @Jumped("func0") private var _func0 = func0
    func func0() -> ReturnType { .rnd() }

    @Jumped("tfunc0") private var _tfunc0 = tfunc0
    func tfunc0() throws -> ReturnType { .rnd() }

    @Jumped("atfunc0", priority: .low) private var _atfunc0 = atfunc0
    func atfunc0() async throws -> ReturnType { .rnd() }


    @Jumped("func1") private var _func1 = func1
    func func1(i0: ArgType) -> ReturnType { i0 as? ReturnType ?? .rnd() }

    @Jumped("tfunc1") private var _tfunc1 = tfunc1
    func tfunc1(i0: ArgType) throws -> ReturnType { i0 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc1", priority: .low) private var _atfunc1 = atfunc1
    func atfunc1(i0: ArgType) async throws -> ReturnType { i0 as? ReturnType ?? .rnd()  }


    @Jumped("func2") private var _func2 = func2
    func func2(i0: ArgType, i1: ArgType) -> ReturnType { i1 as? ReturnType ?? .rnd()  }

    @Jumped("tfunc2") private var _tfunc2 = tfunc2
    func tfunc2(i0: ArgType, i1: ArgType) throws -> ReturnType { i1 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc2", priority: .low) private var _atfunc2 = atfunc2
    func atfunc2(i0: ArgType, i1: ArgType) async throws -> ReturnType { i1 as? ReturnType ?? .rnd()  }


    @Jumped("func3") private var _func3 = func3
    func func3(i0: ArgType, i1: ArgType, i2: ArgType) -> ReturnType { i2 as? ReturnType ?? .rnd()  }

    @Jumped("tfunc3") private var _tfunc3 = tfunc3
    func tfunc3(i0: ArgType, i1: ArgType, i2: ArgType) throws -> ReturnType { i2 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc3", priority: .low) private var _atfunc3 = atfunc3
    func atfunc3(i0: ArgType, i1: ArgType, i2: ArgType) async throws -> ReturnType { i2 as? ReturnType ?? .rnd()  }


    @Jumped("func4") private var _func4 = func4
    func func4(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType) -> ReturnType { i3 as? ReturnType ?? .rnd()  }

    @Jumped("tfunc4") private var _tfunc4 = tfunc4
    func tfunc4(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType) throws -> ReturnType { i3 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc4", priority: .low) private var _atfunc4 = atfunc4
    func atfunc4(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType) async throws -> ReturnType { i3 as? ReturnType ?? .rnd()  }


    @Jumped("func5") private var _func5 = func5
    func func5(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType) -> ReturnType { i4 as? ReturnType ?? .rnd()  }

    @Jumped("tfunc5") private var _tfunc5 = tfunc5
    func tfunc5(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType) throws -> ReturnType { i4 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc5", priority: .low) private var _atfunc5 = atfunc5
    func atfunc5(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType) async throws -> ReturnType { i4 as? ReturnType ?? .rnd()  }


    @Jumped("func6") private var _func6 = func6
    func func6(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType) -> ReturnType { i5 as? ReturnType ?? .rnd()  }

    @Jumped("tfunc6") private var _tfunc6 = tfunc6
    func tfunc6(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType) throws -> ReturnType { i5 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc6", priority: .low) private var _atfunc6 = atfunc6
    func atfunc6(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType) async throws -> ReturnType { i5 as? ReturnType ?? .rnd()  }


    @Jumped("func7") private var _func7 = func7
    func func7(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType) -> ReturnType { i6 as? ReturnType ?? .rnd()  }

    @Jumped("tfunc7") private var _tfunc7 = tfunc7
    func tfunc7(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType) throws -> ReturnType { i6 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc7", priority: .low) private var _atfunc7 = atfunc7
    func atfunc7(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType) async throws -> ReturnType { i6 as? ReturnType ?? .rnd()  }


    @Jumped("func8") private var _func8 = func8
    func func8(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType, i7: ArgType) -> ReturnType { i7 as? ReturnType ?? .rnd()  }

    @Jumped("tfunc8") private var _tfunc8 = tfunc8
    func tfunc8(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType, i7: ArgType) throws -> ReturnType { i7 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc8", priority: .low) private var _atfunc8 = atfunc8
    func atfunc8(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType, i7: ArgType) async throws -> ReturnType { i7 as? ReturnType ?? .rnd()  }


    @Jumped("func9") private var _func9 = func9
    func func9(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType, i7: ArgType, i8: ArgType) -> ReturnType { i8 as? ReturnType ?? .rnd()  }

    @Jumped("tfunc9") private var _tfunc9 = tfunc9
    func tfunc9(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType, i7: ArgType, i8: ArgType) throws -> ReturnType { i8 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc9", priority: .low) private var _atfunc9 = atfunc9
    func atfunc9(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType, i7: ArgType, i8: ArgType) async throws -> ReturnType { i8 as? ReturnType ?? .rnd()  }


    @Jumped("func10") private var _func10 = func10
    func func10(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType, i7: ArgType, i8: ArgType, i9: ArgType) -> ReturnType { i9 as? ReturnType ?? .rnd()  }

    @Jumped("tfunc10") private var _tfunc10 = tfunc10
    func tfunc10(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType, i7: ArgType, i8: ArgType, i9: ArgType) throws -> ReturnType { i9 as? ReturnType ?? .rnd()  }

    @Jumped("atfunc10", priority: .low) private var _atfunc10 = atfunc10
    func atfunc10(i0: ArgType, i1: ArgType, i2: ArgType, i3: ArgType, i4: ArgType, i5: ArgType, i6: ArgType, i7: ArgType, i8: ArgType, i9: ArgType) async throws -> ReturnType { i9 as? ReturnType ?? .rnd()  }

    lazy var jsc = jack()
}
