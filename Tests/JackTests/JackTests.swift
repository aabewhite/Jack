import XCTest
import Jack
import protocol OpenCombineShim.ObservableObject
import struct OpenCombineShim.Published

@available(macOS 11, iOS 13, tvOS 13, *)
final class JackTests: XCTestCase {
    func testDemoCode() throws {
        try AppleJack.demo()
    }

    func testObservation() {
        let ajack = AppleJack(name: "John Appleseed", age: 24)

        var changes = 0
        let cancellable = ajack.objectWillChange
            .sink { _ in
                changes += 1
            }

        XCTAssertEqual(25, ajack.haveBirthday())
        XCTAssertEqual(1, changes)

        XCTAssertEqual(26, try ajack.jxc.eval("haveBirthday()").numberValue)
        XCTAssertEqual(2, changes)

        let _ = cancellable
    }

    @available(macOS 13, iOS 15, tvOS 15, *)
    func XXXtestAyncLockedClassStream() async throws { // not working
        // let ajack = AppleJack(name: "John Appleseed", age: 0) // class: not concurrent
        let ajack = await SynchronizedAppleJack(name: "John Appleseed", age: 0) // concurrent actor
        var ages: [Int] = []

        for await age in await ajack.$age.values {
            //print("age:", age)
            ages += [age]
            if age == 0 {
                for _ in 0..<100 {
                    Task.detached {
                        //try await ajack.jxc.eval("age += 1") // unprotected by the actor
                        try await ajack.eval("age += 1")
                    }
                }
            } else if age >= 100 {
                break // we received all our birthdays
            }
        }

        XCTAssertEqual(101, ages.count)
        //XCTAssertNotEqual(Array(0...100), ages, "")
        XCTAssertEqual(Array(0...100), ages.sorted())
    }

    @available(macOS 13, iOS 15, tvOS 15, *)
    func testAsyncActorStream() async throws {
        if true {
            throw XCTSkip("disabled due to crashing on CI")
        } else {
            try await asyncActorStreamTest(count: 1, viaJS: true)
            try await asyncActorStreamTest(count: 1, viaJS: false)
            
            // not yet working, so don't verify
            try await asyncActorStreamTest(count: 5, viaJS: true, verify: false)
            try await asyncActorStreamTest(count: 5, viaJS: false, verify: false)
        }
    }

    @available(macOS 13, iOS 15, tvOS 15, *)
    func asyncActorStreamTest(count: Int, viaJS: Bool, verify: Bool = true) async throws {
        let ajack = AppleJacktor(name: "John Appleseed", age: 0) // concurrent actor
        var ages: [Int] = []

        for await age in await ajack.$age.values { // requires macOS 13/iOS 15
            if age == 0 {
                for _ in 0..<count {
                    let result: Double = try await Task.detached {
                        //try await Task.sleep(nanoseconds: (0...20_000_000_000).randomElement()!)
                        if viaJS {
                            return try await ajack.eval("age += 1").numberValue
                        } else {
                            return await Double(ajack.incrementAge())
                        }
                        //try await Task.sleep(nanoseconds: (0...20_000_000_000).randomElement()!)
                    }.value
                    print("set age:", result)
                }
            } else {
                print("received age:", age)
                ages += [age] // keep track of birthdays
            }
            if age >= count {
                break // we received all our birthdays
            }
        }

        if verify {
            XCTAssertEqual(count, ages.count)
            if count >= 100 {
                XCTAssertNotEqual(Array(1...count), ages, "unexpected serialization") // not impossible, I suppose
            }
            XCTAssertEqual(Array(1...count), ages.sorted())
        }
    }

    func testBridging() throws {
        class JSBridgedObject : JackedObject {
            @Coded var related = JSBridgedRelated()
        }

        struct JSBridgedRelated : Codable, Conveyable {
            var string = "related"
        }

        let jxc = JXContext()
        let obj = JSBridgedObject()
        obj.jack(into: jxc, as: "ref") // bridge the wrapped properties
        XCTAssertEqual("related", try jxc.eval("ref.related.string").stringValue)
        XCTAssertEqual("updated", try jxc.eval("ref.related.string = 'updated'").stringValue)
    }

    func testBridgingEnhanced() throws {
        enum Relation : String, Conveyable {
            // string cases are auto-exported to Java via coding
            case friend, relative, neighbor, coworker
        }

        class BridgedProperties : JackedObject {
            @Jacked var related: Relation?

            @Jumped var gossip = chatter // exports this function as "gossip"
            func chatter() throws -> String? {
                switch related {
                case .none: return nil
                case .friend: return "Did you see what Becky was wearing?"
                case .relative: return "It's a shame about Bruno."
                case .neighbor: return "How do they get their lawn so green?"
                case .coworker: throw Errors.looseLipsSinkShips
                }
            }

            enum Errors : Error { case looseLipsSinkShips }
        }

        let jxc = JXContext()
        let obj = BridgedProperties()
        obj.jack(into: jxc, as: "connection") // bridge the wrapped properties

        XCTAssertTrue(try jxc.eval("connection.related").isNull)
        XCTAssertTrue(try jxc.eval("connection.gossip()").isNull)

        XCTAssertThrowsError(try jxc.eval("connection.related = 'xxx'"), "assignment to invalid case should throw")

        XCTAssertEqual("relative", try jxc.eval("connection.related = 'relative'").stringValue)
        XCTAssertEqual("relative", try jxc.eval("connection.related").stringValue)
        XCTAssertEqual("relative", obj.related?.rawValue)

        XCTAssertEqual("It's a shame about Bruno.", try jxc.eval("connection.gossip()").stringValue)

        XCTAssertEqual("coworker", try jxc.eval("connection.related = 'coworker'").stringValue)
        XCTAssertEqual("coworker", obj.related?.rawValue)

        XCTAssertThrowsError(try jxc.eval("connection.gossip()")) { error in
            // swift error is re-throws from JS
            XCTAssertEqual("Error: looseLipsSinkShips", "\(error)")
        }

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
            private lazy var jxc = jack().env // a JSContext bound to this instance

            /// - Returns: true if a point was scored
            func pong() throws -> Bool {
                // evaluate the javascript with "score" as a readable/writable property
                try jxc.eval("Math.random() > 0.5 ? this.score += 1 : false").booleanValue
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

        let jxc = obj.jack().env

        XCTAssertEqual("number", try jxc.eval("typeof n").stringValue)
        XCTAssertEqual("number", try jxc.eval("typeof f").stringValue)
        XCTAssertEqual("boolean", try jxc.eval("typeof b").stringValue)
        XCTAssertEqual("string", try jxc.eval("typeof s").stringValue)

        do {
            XCTAssertEqual(1, try jxc.eval("n").numberValue)
            try jxc.eval("n += 1")
            XCTAssertEqual(2, obj.integer)
            try jxc.eval("n += 1")
            XCTAssertEqual(3, obj.integer)
        }

        do {
            try jxc.eval("n = 9.12323")
            XCTAssertEqual(9, obj.integer)
            XCTAssertEqual(9, try jxc.eval("n").numberValue)
        }

        do {
            changes = 0
            XCTAssertEqual(0, changes)

            try jxc.eval("s = 1.2") // should be able to set string from number, as per JS coercion
            XCTAssertEqual("1.2", obj.string)
            XCTAssertEqual(1, changes) // even though it threw an error, it will still trigger the `objectWillChange`, since that is invoked before the attempt

            try jxc.eval("s = 'x'")
            XCTAssertEqual("x", obj.string)
            XCTAssertEqual(2, changes)

            try jxc.eval("s = 'abc' + 123")
            XCTAssertEqual("abc123", obj.string)
            XCTAssertEqual(3, changes)
        }

        do {
            try jxc.eval("b = false")
            XCTAssertEqual(false, obj.bool)
        }

        do {
            try jxc.eval("b = true")
            XCTAssertEqual(true, obj.bool)
        }

        do {
            XCTAssertEqual(true, try jxc.eval("b").booleanValue)
            obj.bool.toggle()
            XCTAssertEqual(false, try jxc.eval("b").booleanValue)
        }

        do {
            XCTAssertThrowsError(try jxc.eval("n = 'x'")) // valueWasNotANumber
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

        let jxc = obj.jack().env

        XCTAssertEqual(0, changes)

        do {
            XCTAssertEqual(1, try jxc.eval("sup").numberValue)

            XCTAssertEqual(0, changes)
            try jxc.eval("sup += 1")
            XCTAssertEqual(1, changes)

            XCTAssertEqual(2, obj.sup)
            try jxc.eval("sup += 1")
            XCTAssertEqual(3, obj.sup)
            XCTAssertEqual(3, try jxc.eval("sup").numberValue)

            XCTAssertEqual(2, changes)
        }

        changes = 0

        do {
            XCTAssertEqual(0, try jxc.eval("sub").numberValue)

            XCTAssertEqual(0, changes)
            try jxc.eval("sub += 1")
            XCTAssertEqual(1, obj.sub)
            try jxc.eval("sub += 1")
            XCTAssertEqual(2, obj.sub)
            XCTAssertEqual(2, try jxc.eval("sub").numberValue)

            XCTAssertEqual(2, changes)
        }

        let _ = obsvr1
    }

    func testTracked() throws {

        class TrackedObj : JackedObject {
            @Tracked var integer = 0
            @Tracked var float = 0.0

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
            lazy var jxc = jack().env
        }

        let obj = JackedObj()

        do {
            XCTAssertEqual("a,b,c", try obj.jxc.eval("sa").stringValue)
            XCTAssertEqual(3, try obj.jxc.eval("sa.length").numberValue)

            XCTAssertEqual(["a", "b", "c"], obj.stringArray)
            XCTAssertEqual(4, try obj.jxc.eval("sa.push('q')").numberValue)

            XCTAssertEqual("a,b,c", try obj.jxc.eval("sa").stringValue, "Array.push doesn't work")
            XCTAssertEqual(["a", "b", "c"], obj.stringArray)

            XCTAssertEqual(["q"], try obj.jxc.eval("sa = ['q']").array.map({ try $0.stringValue }))
            XCTAssertEqual(["q"], obj.stringArray)

            XCTAssertEqual([], try obj.jxc.eval("sa = []").array.map({ try $0.stringValue }))
            XCTAssertEqual([], obj.stringArray)

            try obj.jxc.eval("sa = [1]")
            XCTAssertEqual("1", try obj.jxc.eval("sa").array.first?.stringValue)
            try obj.jxc.eval("sa = [false]")
            XCTAssertEqual(1, try obj.jxc.eval("sa").count)
            try obj.jxc.eval("sa = [null]")
            XCTAssertEqual("null", try obj.jxc.eval("sa").array.first?.stringValue)

            XCTAssertEqual(2, try obj.jxc.eval("sa.push('x')").numberValue) // TODO: how to handle `Array.push`?
            try obj.jxc.eval("let x = sa; sa = x")
            XCTAssertEqual(["null"], obj.stringArray)
        }
    }

    func testJackedDate() throws {
        class JackedDate : JackedObject {
            @Jacked var date = Date(timeIntervalSince1970: 0)
            lazy var jxc = jack().env
        }

        let obj = JackedDate()

        XCTAssertEqual(Date(timeIntervalSince1970: 0), obj.date)

        // /home/runner/work/Jack/Jack/Tests/JackTests/JackTests.swift:132: error: JackTests.testJackedDate : XCTAssertEqual failed: ("Optional("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)")") is not equal to ("Optional("Thu Jan 01 1970 00:00:00 GMT+0000 (UTC)")") -
        // XCTAssertEqual("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)", try obj.jxc.eval("date").stringValue)


        XCTAssertEqual(0, try obj.jxc.eval("date").numberValue)

        obj.date = .distantPast

#if os(Linux) // sigh
        XCTAssertEqual(-62104233600000, try obj.jxc.eval("date").numberValue)
#else
        XCTAssertEqual(-62135596800000, try obj.jxc.eval("date").numberValue)
#endif

        obj.date = .distantFuture
        XCTAssertEqual(64092211200000, try obj.jxc.eval("date").numberValue)

        XCTAssertEqual(Date().timeIntervalSinceReferenceDate, try obj.jxc.eval("date = new Date()").dateValue?.timeIntervalSinceReferenceDate ?? 0, accuracy: 0.01, "date should agree")

        // XCTAssertEqual(Data([1, 2, 3]), obj.data)
    }

    func testJackedData() throws {
        class JackedData : JackedObject {
            @Jacked var data = Data()
            lazy var jxc = jack().env
        }

        let obj = JackedData()

        XCTAssertEqual(Data(), obj.data)
        XCTAssertEqual("1,2,3", try obj.jxc.eval("data = [1, 2, 3]").stringValue)
        XCTAssertEqual(Data([1, 2, 3]), obj.data)

        XCTAssertEqual(99, try obj.jxc.eval("data[0] = 99").numberValue)
        XCTAssertNotEqual(99, obj.data.first, "array element assignment shouldn't work")

        // need to pad out the array before we can convert it to a buffer
        XCTAssertThrowsError(try obj.jxc.eval("(new Int32Array(data))[0] = 99"))

        XCTAssertEqual(3, obj.data.count)
        obj.data.append(contentsOf: Data(repeating: 0, count: 8 - (obj.data.count % 8))) // pad the array
        XCTAssertEqual(8, obj.data.count)

        XCTAssertEqual(99, try obj.jxc.eval("(new Int32Array(data))[0] = 99").numberValue)
        XCTAssertNotEqual(99, obj.data.first, "assignment through Int32Array should work")

        XCTAssertEqual(999, try obj.jxc.eval("(new Int32Array(data))[7] = 999").numberValue)
        XCTAssertNotEqual(255, obj.data.last, "assignment to overflow value should round to byte")

        let oldData = Data(obj.data)
        XCTAssertEqual(0, try obj.jxc.eval("(new Int32Array(data))[999] = 0").numberValue)
        XCTAssertEqual(oldData, obj.data, "assignment beyond bounds should have no effect")
    }

    func testJackedEnum() throws {
        enum Compass : String, Jackable { case north, south, east, west }
        enum Direction : Int, Jackable { case up, down, left, right }

        class JackedObj : JackedObject {
            @Jacked("c") var stringEnum = Compass.north
            @Jacked("d") var intEnum = Direction.left
            lazy var jxc = jack().env
        }

        let obj = JackedObj()

        do {
            XCTAssertEqual(.north, obj.stringEnum)

            XCTAssertEqual("north", try obj.jxc.eval("c = 'north'").stringValue)
            XCTAssertEqual(.north, obj.stringEnum)

            XCTAssertEqual("south", try obj.jxc.eval("c = 'south'").stringValue)
            XCTAssertEqual(.south, obj.stringEnum)

            XCTAssertEqual("east", try obj.jxc.eval("c = 'east'").stringValue)
            XCTAssertEqual(.east, obj.stringEnum)

            XCTAssertEqual("west", try obj.jxc.eval("c = 'west'").stringValue)
            XCTAssertEqual(.west, obj.stringEnum)

            XCTAssertThrowsError(try obj.jxc.eval("c = 'northX'")) { error in
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

            XCTAssertEqual(3, try obj.jxc.eval("d = 3").numberValue)
            XCTAssertEqual(.right, obj.intEnum)

            XCTAssertEqual(0, try obj.jxc.eval("d = 0").numberValue)
            XCTAssertEqual(.up, obj.intEnum)

            XCTAssertEqual(2, try obj.jxc.eval("d = 2").numberValue)
            XCTAssertEqual(.left, obj.intEnum)

            XCTAssertEqual(1, try obj.jxc.eval("d = 1").numberValue)
            XCTAssertEqual(.down, obj.intEnum)

            XCTAssertThrowsError(try obj.jxc.eval("d = 4")) { error in
            }
            XCTAssertEqual(.down, obj.intEnum)
        }

    }

    func testJackedNumbers() throws {
        class JackedObj : JackedObject {
            @Jacked var dbl = 0.0
            lazy var jxc = jack().env
        }

        let obj = JackedObj()

        XCTAssertEqual(.pi, try obj.jxc.eval("dbl = Math.PI").numberValue)
        XCTAssertEqual(3.141592653589793, obj.dbl)

        XCTAssertEqual(2.718281828459045, try obj.jxc.eval("dbl = Math.E").numberValue)
        XCTAssertEqual(2.718281828459045, obj.dbl)

        XCTAssertEqual(sqrt(2.0), try obj.jxc.eval("dbl = Math.sqrt(2)").numberValue)
        XCTAssertEqual(1.4142135623730951, obj.dbl)

        try obj.jxc.eval("dbl = Math.sqrt(-1)")
        XCTAssertTrue(obj.dbl.isNaN)
    }

    func testJugglable() throws {
        class JackedCode : JackedObject {
            @Coded var info = SomeInfo(str: "XYZ", int: 123, extra: SomeInfo.ExtraInfo(dbl: 1.2, strs: ["A", "B", "C"]))
            lazy var jxc = jack().env

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
        XCTAssertEqual("XYZ", try obj.jxc.eval("info.str").stringValue)

        XCTAssertEqual(123, obj.info.int)
        XCTAssertEqual(123, try obj.jxc.eval("info.int").numberValue)

        XCTAssertEqual("A", obj.info.extra?.strs?[0])
        XCTAssertEqual("A", try obj.jxc.eval("info.extra.strs[0]").stringValue)

        XCTAssertEqual("QRS", try obj.jxc.eval("info.str = 'QRS'").stringValue)
        XCTAssertNotEqual("QRS", obj.info.str, "known shortcoming: setting through struct properties doesn't work")

        XCTAssertEqual("[object Object]", try obj.jxc.eval("var i = info; i.str = 'QRS'; info = i").stringValue)
        XCTAssertEqual("QRS", obj.info.str)

        XCTAssertEqual(0, try obj.jxc.eval("info = { }").dictionary?.keys.count)
        XCTAssertEqual(.init(), obj.info)

        XCTAssertEqual(1, try obj.jxc.eval("info = { str: 'abc' }").dictionary?.keys.count)
        XCTAssertEqual(.init(str: "abc"), obj.info)

        XCTAssertEqual(2, try obj.jxc.eval("info = { str: 'abc', int: 2 }").dictionary?.keys.count)
        XCTAssertEqual(.init(str: "abc", int: 2), obj.info)

        XCTAssertEqual(3, try obj.jxc.eval("info = { str: 'abc', int: 2, extra: { strs: [ 'q', 'r', 's' ] } }").dictionary?.keys.count)
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

            lazy var jxc = jack().env
        }

        /// A sample of codable passing
        struct CodedCodable : Codable, Equatable, Conveyable {
            var id = UUID()
            var str = ""
            var num: Int?
        }

        let obj = JumpedObj()

        XCTAssertEqual("function", try obj.jxc.eval("typeof f0").stringValue)
        XCTAssertEqual("function", try obj.jxc.eval("typeof f1").stringValue)
        XCTAssertEqual("undefined", try obj.jxc.eval("typeof f2").stringValue, "f2 should be visible as F2")
        XCTAssertEqual("function", try obj.jxc.eval("typeof F2").stringValue)
        XCTAssertEqual("function", try obj.jxc.eval("typeof replicate").stringValue)
        XCTAssertEqual("function", try obj.jxc.eval("typeof exceptional").stringValue)

        XCTAssertEqual(1_234_000, try obj.jxc.eval("f0()").numberValue)
        XCTAssertEqual("Hello x!", try obj.jxc.eval("f1('x')").stringValue)
        XCTAssertEqual("Happy Birthday x, you are 9!", try obj.jxc.eval("F2('x', 9)").stringValue)

        let c = CodedCodable(id: UUID(uuidString: "4991E2A0-DE05-4BB3-B502-42F7584C9973")!, str: "abc", num: 9)
        XCTAssertEqual([c, c, c], try obj.jxc.eval("replicate({ id: '4991E2A0-DE05-4BB3-B502-42F7584C9973', str: 'abc', num: 9 }, 3)").toDecodable(ofType: Array<CodedCodable>.self))

        // make sure we are blocked from setting the function property from JS
        XCTAssertThrowsError(try obj.jxc.eval("f0 = null")) { error in
            //XCTAssertEqual(#"evaluationErrorString("Error: cannot set a function from JS")"#, "\(error)")
        }

    }

    func testAllPropertyWrappers() throws {
        class EnhancedObj : JackedObject {
            @Tracked var x = 0 // unexported to jxc
            @Jacked var i = 1 // exported as number
            @Jacked("B") var b = false // exported as bool
            @Coded var id = UUID() // exported (via codability) as string
            @Jumped("now") private var _now = now // exported as function
            func now() -> Date { Date(timeIntervalSince1970: 1_234) }

            lazy var jxc = jack().env
        }

        let obj = EnhancedObj()

        XCTAssertEqual("undefined", try obj.jxc.eval("typeof x").stringValue)
        XCTAssertEqual("number", try obj.jxc.eval("typeof i").stringValue)
        XCTAssertEqual("undefined", try obj.jxc.eval("typeof b").stringValue) // aliased away
        XCTAssertEqual("boolean", try obj.jxc.eval("typeof B").stringValue) // aliased
        XCTAssertEqual("string", try obj.jxc.eval("typeof id").stringValue)
        XCTAssertEqual("function", try obj.jxc.eval("typeof now").stringValue)
        XCTAssertEqual("object", try obj.jxc.eval("typeof now()").stringValue)
        XCTAssertEqual(1_234_000, try obj.jxc.eval("now()").numberValue)
    }
}

/// Demo class
@available(macOS 11, iOS 13, tvOS 13, *)
class AppleJack : JackedObject {
    @Jacked var name: String
    @Jacked var age: Int

    /// An embedded `JXKit` script context that has access to the jacked properties and jumped functions
    lazy var jxc = jack().env

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    @Jumped("haveBirthday") var _haveBirthday = haveBirthday
    func haveBirthday(count: Int? = nil) -> Int {
        age += count ?? 1
        return age
    }

    static func demo() throws {
        let jackApp = AppleJack(name: "Jack Appleseed", age: 24)

        let namejs = try jackApp.jxc.eval("name").stringValue
        XCTAssertTrue(namejs == jackApp.name)

        let agejs = try jackApp.jxc.eval("age").numberValue
        XCTAssertTrue(agejs == Double(jackApp.age)) // JS numbers are always Double

        XCTAssertTrue(jackApp.haveBirthday(count: 1) == 25) // direct Swift call
        let newAge = try jackApp.jxc.eval("haveBirthday()").numberValue // script invocation
        XCTAssertTrue(newAge == 26.0)
        XCTAssertTrue(jackApp.age == 26)
    }
}


/// Demo concurrent class with locking
@available(macOS 11, iOS 13, tvOS 13, *)
@MainActor class SynchronizedAppleJack : JackedObject {
    @Jacked var name: String
    @Jacked var age: Int

    /// A concurrent queue to allow multiple reads at once.
    private var queue = DispatchQueue(label: "SynchronizedAppleJack", attributes: .concurrent)

    /// A private script context for concurrent access
    private lazy var jxc = jack().env

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    /// Evaluate the script; this is protected by the actor
    func eval(_ script: String) throws -> JXValue {
        let ctx = jxc
        return try queue.sync(flags: .barrier) {
            try ctx.eval(script)
        }
    }
}

/// Demo actor
@available(macOS 11, iOS 13, tvOS 13, *)
actor AppleJacktor : JackedObject {
    @Jacked var name: String
    @Jacked var age: Int

    /// A private script context for concurrent access
    private lazy var jxc = jack().env

    init(name: String, age: Int) {
        // Actor-isolated property 'name' can not be mutated from a non-isolated context; this is an error in Swift 6
        // self.name = name
        // self.age = age

        self._name = Jacked(wrappedValue: name)
        self._age = Jacked(wrappedValue: age)
    }

    /// Evaluate the script in an actor-synchronized block
    func eval(_ script: String) throws -> JXValue {
        try jxc.eval(script)
    }

    func incrementAge() -> Int {
        age += 1
        return age
    }
}


/// Work-in-Progress marker
@available(*, deprecated, message: "work in progress")
@inlinable internal func wip<T>(_ value: T) -> T { value }

