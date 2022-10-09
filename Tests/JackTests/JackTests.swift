import XCTest
import Jack

final class JackTests: XCTestCase {
    func testModuleVersion() throws {
        XCTAssertEqual("org.jectivex.Jack", JackBundleIdentifier)
        XCTAssertLessThanOrEqual(2_000_000, JackVersionNumber, "should have been version 2.0.0 or higher")
    }

    func testDemoCode() throws {
        try AppleJack.demo()
    }

    func testObservation() throws {
        let ajack = AppleJack(name: "John Appleseed", age: 24)
        let jxc = try ajack.jack().context

        var changes = 0
        let cancellable = ajack.objectWillChange
            .sink { _ in
                changes += 1
            }

        XCTAssertEqual(25, ajack.haveBirthday())
        XCTAssertEqual(1, changes)

        XCTAssertEqual(26, try jxc.eval("haveBirthday()").double)
        XCTAssertEqual(2, changes)

        let _ = cancellable
    }

    @available(macOS 13, iOS 15, tvOS 15, *)
    func XXXtestAyncLockedClassStream() async throws { // not working
        // let ajack = AppleJack(name: "John Appleseed", age: 0) // class: not concurrent
        let ajack = await SynchronizedJackedObject(name: "John Appleseed", age: 0) // concurrent actor
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
        if ({ true }()) {
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
        let ajack = JackedActor(name: "John Appleseed", age: 0) // concurrent actor
        var ages: [Int] = []

        for await age in await ajack.$age.values { // requires macOS 13/iOS 15
            if age == 0 {
                for _ in 0..<count {
                    let result: Double = try await Task.detached {
                        //try await Task.sleep(nanoseconds: (0...20_000_000_000).randomElement()!)
                        if viaJS {
                            return try await ajack.eval("age += 1").double
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
            @Pack var related = JSBridgedRelated()
        }

        struct JSBridgedRelated : Codable, JXConvertible {
            var string = "related"
        }

        let jxc = JXContext()
        let obj = JSBridgedObject()
        let ref = jxc.object()
        try jxc.global.setProperty("ref", ref)

        try obj.jack(into: ref) // bridge the wrapped properties

        XCTAssertEqual("related", try jxc.eval("ref.related.string").string)
        XCTAssertEqual("updated", try jxc.eval("ref.related.string = 'updated'").string)
    }

    func testBridgingEnhanced() throws {
        enum Relation : String, Codable, JXConvertible {
            // string cases are auto-exported to Java via coding
            case friend, relative, neighbor, coworker

            // Both Codable and RawRepresentable implement JXConvertible, so we need to manually dis-ambiguate
            static func fromJX(_ value: JXValue) throws -> Self { try makeJXRaw(from: value) }
            func toJX(in context: JXContext) throws -> JXValue { try getJXRaw(from: context) }
        }

        class BridgedProperties : JackedObject {
            @Stack var related: Relation?

            @Jack var gossip = chatter // exports this function as "gossip"
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
        let ref = jxc.object()
        try jxc.global.setProperty("connection", ref)
        try obj.jack(into: ref) // bridge the wrapped properties

        XCTAssertTrue(try jxc.eval("connection.related").isNull)
        XCTAssertTrue(try jxc.eval("connection.gossip()").isNull)

        XCTAssertThrowsError(try jxc.eval("connection.related = 'xxx'"), "assignment to invalid case should throw")

        XCTAssertEqual("relative", try jxc.eval("connection.related = 'relative'").string)
        XCTAssertEqual("relative", try jxc.eval("connection.related").string)
        XCTAssertEqual("relative", obj.related?.rawValue)

        XCTAssertEqual("It's a shame about Bruno.", try jxc.eval("connection.gossip()").string)

        XCTAssertEqual("coworker", try jxc.eval("connection.related = 'coworker'").string)
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
            @Stack var score = 0
            private lazy var jxc = try! jack().context // a JSContext bound to this instance

            /// - Returns: true if a point was scored
            func pong() throws -> Bool {
                // evaluate the javascript with "score" as a readable/writable property
                try jxc.eval("Math.random() > 0.5 ? this.score += 1 : false").bool
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

    func XXXtestPingPongPerformance() {
        measure {
            try? testPingPongExample()
        }
    }

    func testStacked() throws {
        class JackedObj : JackedObject {
            @Stack("n") var integer = 0
            @Stack("f") var float = 0.0
            @Stack("b") var bool = false
            @Stack("s") var string = ""

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

        let jxc = try obj.jack().context

        XCTAssertEqual("number", try jxc.eval("typeof n").string)
        XCTAssertEqual("number", try jxc.eval("typeof f").string)
        XCTAssertEqual("boolean", try jxc.eval("typeof b").string)
        XCTAssertEqual("string", try jxc.eval("typeof s").string)

        do {
            XCTAssertEqual(1, try jxc.eval("n").double)
            try jxc.eval("n += 1")
            XCTAssertEqual(2, obj.integer)
            try jxc.eval("n += 1")
            XCTAssertEqual(3, obj.integer)
        }

        do {
            try jxc.eval("n = 9.12323")
            XCTAssertEqual(9, obj.integer)
            XCTAssertEqual(9, try jxc.eval("n").double)
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
            XCTAssertEqual(true, try jxc.eval("b").bool)
            obj.bool.toggle()
            XCTAssertEqual(false, try jxc.eval("b").bool)
        }

        do {
            XCTAssertThrowsError(try jxc.eval("n = 'x'")) // valueWasNotANumber
        }
    }

    func testJackedSubclass() throws {
        class JackedSuper : JackedObject {
            @Stack var sup = 1

        }

        class JackedSub : JackedSuper {
            @Stack var sub = 0
        }

        let obj = JackedSub()

        var changes = 0
        
        let obsvr1 = obj.objectWillChange.sink {
            changes += 1
        }

        let jxc = try obj.jack().context

        XCTAssertEqual(0, changes)

        do {
            XCTAssertEqual(1, try jxc.eval("sup").double)

            XCTAssertEqual(0, changes)
            try jxc.eval("sup += 1")
            XCTAssertEqual(1, changes)

            XCTAssertEqual(2, obj.sup)
            try jxc.eval("sup += 1")
            XCTAssertEqual(3, obj.sup)
            XCTAssertEqual(3, try jxc.eval("sup").double)

            XCTAssertEqual(2, changes)
        }

        changes = 0

        do {
            XCTAssertEqual(0, try jxc.eval("sub").double)

            XCTAssertEqual(0, changes)
            try jxc.eval("sub += 1")
            XCTAssertEqual(1, obj.sub)
            try jxc.eval("sub += 1")
            XCTAssertEqual(2, obj.sub)
            XCTAssertEqual(2, try jxc.eval("sub").double)

            XCTAssertEqual(2, changes)
        }

        let _ = obsvr1
    }

    func testTracked() throws {

        class TrackedObj : JackedObject {
            @Track var integer = 0
            @Track var float = 0.0

            @Stack("b") var bool = false
            @Stack("s") var string = ""

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

    func testStackedArray() throws {
        class JackedObj : JackedObject {
            @Stack("sa") var stringArray = ["a", "b", "c"]
        }

        let obj = JackedObj()
        let jxc = try obj.jack().context

        do {
            XCTAssertEqual("a,b,c", try jxc.eval("sa").string)
            XCTAssertEqual(3, try jxc.eval("sa.length").double)

            XCTAssertEqual(["a", "b", "c"], obj.stringArray)
            XCTAssertEqual(4, try jxc.eval("sa.push('q')").double)

            XCTAssertEqual("a,b,c", try jxc.eval("sa").string, "Array.push doesn't work")
            XCTAssertEqual(["a", "b", "c"], obj.stringArray)

            XCTAssertEqual(["q"], try jxc.eval("sa = ['q']").array.map({ try $0.string }))
            XCTAssertEqual(["q"], obj.stringArray)

            XCTAssertEqual([], try jxc.eval("sa = []").array.map({ try $0.string }))
            XCTAssertEqual([], obj.stringArray)

            try jxc.eval("sa = [1]")
            XCTAssertEqual("1", try jxc.eval("sa").array.first?.string)
            try jxc.eval("sa = [false]")
            XCTAssertEqual(1, try jxc.eval("sa").count)
            try jxc.eval("sa = [null]")
            XCTAssertEqual("null", try jxc.eval("sa").array.first?.string)

            XCTAssertEqual(2, try jxc.eval("sa.push('x')").double) // TODO: how to handle `Array.push`?
            try jxc.eval("let x = sa; sa = x")
            XCTAssertEqual(["null"], obj.stringArray)
        }
    }

    func testStackedDate() throws {
        class JackedDate : JackedObject {
            @Stack var date = Date(timeIntervalSince1970: 0)
        }

        let obj = JackedDate()
        let jxc = try obj.jack().context

        XCTAssertEqual(Date(timeIntervalSince1970: 0), obj.date)

        // /home/runner/work/Jack/Jack/Tests/JackTests/JackTests.swift:132: error: JackTests.testJackedDate : XCTAssertEqual failed: ("Optional("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)")") is not equal to ("Optional("Thu Jan 01 1970 00:00:00 GMT+0000 (UTC)")") -
        // XCTAssertEqual("Wed Dec 31 1969 19:00:00 GMT-0500 (Eastern Standard Time)", try obj.jxc.eval("date").string)


        XCTAssertEqual(0, try jxc.eval("date").double)

        obj.date = .distantPast

#if os(Linux) // sigh
        XCTAssertEqual(-62104233600000, try jxc.eval("date").double)
#else
        XCTAssertEqual(-62135596800000, try jxc.eval("date").double)
#endif

        obj.date = .distantFuture
        XCTAssertEqual(64092211200000, try jxc.eval("date").double)

        XCTAssertEqual(Date().timeIntervalSinceReferenceDate, try jxc.eval("date = new Date()").date.timeIntervalSinceReferenceDate, accuracy: 0.01, "date should agree")

        // XCTAssertEqual(Data([1, 2, 3]), obj.data)
    }

    func testStackedData() throws {
        class JackedData : JackedObject {
            @Stack var data = Data()
        }

        let obj = JackedData()
        let jxc = try obj.jack().context

        XCTAssertEqual(Data(), obj.data)
        XCTAssertEqual("1,2,3", try jxc.eval("data = [1, 2, 3]").string)
        XCTAssertEqual(Data([1, 2, 3]), obj.data)

        XCTAssertEqual(99, try jxc.eval("data[0] = 99").double)
        XCTAssertNotEqual(99, obj.data.first, "array element assignment shouldn't work")

        // need to pad out the array before we can convert it to a buffer
        XCTAssertThrowsError(try jxc.eval("(new Int32Array(data))[0] = 99"))

        XCTAssertEqual(3, obj.data.count)
        obj.data.append(contentsOf: Data(repeating: 0, count: 8 - (obj.data.count % 8))) // pad the array
        XCTAssertEqual(8, obj.data.count)

        XCTAssertEqual(99, try jxc.eval("(new Int32Array(data))[0] = 99").double)
        XCTAssertNotEqual(99, obj.data.first, "assignment through Int32Array should work")

        XCTAssertEqual(999, try jxc.eval("(new Int32Array(data))[7] = 999").double)
        XCTAssertNotEqual(255, obj.data.last, "assignment to overflow value should round to byte")

        let oldData = Data(obj.data)
        XCTAssertEqual(0, try jxc.eval("(new Int32Array(data))[999] = 0").double)
        XCTAssertEqual(oldData, obj.data, "assignment beyond bounds should have no effect")
    }

    func testStackedEnum() throws {
        // enum Compass : String, Codable, Jackable { case north, south, east, west } // this would be a problem due to conflicting implementations
        enum Compass : String, Jackable { case north, south, east, west }
        enum Direction : Int, Jackable { case up, down, left, right }

        class JackedObj : JackedObject {
            @Stack("c") var stringEnum = Compass.north
            @Stack("d") var intEnum = Direction.left
        }

        let obj = JackedObj()
        let jxc = try obj.jack().context

        do {
            XCTAssertEqual(.north, obj.stringEnum)

            XCTAssertEqual("north", try jxc.eval("c = 'north'").string)
            XCTAssertEqual(.north, obj.stringEnum)

            XCTAssertEqual("south", try jxc.eval("c = 'south'").string)
            XCTAssertEqual(.south, obj.stringEnum)

            XCTAssertEqual("east", try jxc.eval("c = 'east'").string)
            XCTAssertEqual(.east, obj.stringEnum)

            XCTAssertEqual("west", try jxc.eval("c = 'west'").string)
            XCTAssertEqual(.west, obj.stringEnum)

            XCTAssertThrowsError(try jxc.eval("c = 'northX'")) { error in
                // the exception gets wrapped in a JXValue and then unwrapped as a string
                //                if case JackError.rawInitializerFailed(let value, _) = error {
                //                    XCTAssertEqual("northX", value.string)
                //                } else {
                //                    XCTFail("wrong error: \(error)")
                //                }
            }
        }

        do {
            XCTAssertEqual(.left, obj.intEnum)

            XCTAssertEqual(3, try jxc.eval("d = 3").double)
            XCTAssertEqual(.right, obj.intEnum)

            XCTAssertEqual(0, try jxc.eval("d = 0").double)
            XCTAssertEqual(.up, obj.intEnum)

            XCTAssertEqual(2, try jxc.eval("d = 2").double)
            XCTAssertEqual(.left, obj.intEnum)

            XCTAssertEqual(1, try jxc.eval("d = 1").double)
            XCTAssertEqual(.down, obj.intEnum)

            XCTAssertThrowsError(try jxc.eval("d = 4")) { error in
            }
            XCTAssertEqual(.down, obj.intEnum)
        }

    }

    func testStackedNumbers() throws {
        class JackedObj : JackedObject {
            @Stack var dbl = 0.0
        }

        let obj = JackedObj()
        let jxc = try obj.jack().context

        XCTAssertEqual(.pi, try jxc.eval("dbl = Math.PI").double)
        XCTAssertEqual(3.141592653589793, obj.dbl)

        XCTAssertEqual(2.718281828459045, try jxc.eval("dbl = Math.E").double)
        XCTAssertEqual(2.718281828459045, obj.dbl)

        XCTAssertEqual(sqrt(2.0), try jxc.eval("dbl = Math.sqrt(2)").double)
        XCTAssertEqual(1.4142135623730951, obj.dbl)

        try jxc.eval("dbl = Math.sqrt(-1)")
        XCTAssertTrue(obj.dbl.isNaN)
    }

    func testPacked() throws {
        class JackedCode : JackedObject {
            @Pack var info = SomeInfo(str: "XYZ", int: 123, extra: SomeInfo.ExtraInfo(dbl: 1.2, strs: ["A", "B", "C"]))

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
        let jxc = try obj.jack().context

        XCTAssertEqual("XYZ", obj.info.str)
        XCTAssertEqual("XYZ", try jxc.eval("info.str").string)

        XCTAssertEqual(123, obj.info.int)
        XCTAssertEqual(123, try jxc.eval("info.int").double)

        XCTAssertEqual("A", obj.info.extra?.strs?[0])
        XCTAssertEqual("A", try jxc.eval("info.extra.strs[0]").string)

        XCTAssertEqual("QRS", try jxc.eval("info.str = 'QRS'").string)
        XCTAssertNotEqual("QRS", obj.info.str, "known shortcoming: setting through struct properties doesn't work")

        XCTAssertEqual("[object Object]", try jxc.eval("var i = info; i.str = 'QRS'; info = i").string)
        XCTAssertEqual("QRS", obj.info.str)

        XCTAssertEqual(0, try jxc.eval("info = { }").dictionary?.keys.count)
        XCTAssertEqual(.init(), obj.info)

        XCTAssertEqual(1, try jxc.eval("info = { str: 'abc' }").dictionary?.keys.count)
        XCTAssertEqual(.init(str: "abc"), obj.info)

        XCTAssertEqual(2, try jxc.eval("info = { str: 'abc', int: 2 }").dictionary?.keys.count)
        XCTAssertEqual(.init(str: "abc", int: 2), obj.info)

        XCTAssertEqual(3, try jxc.eval("info = { str: 'abc', int: 2, extra: { strs: [ 'q', 'r', 's' ] } }").dictionary?.keys.count)
        XCTAssertEqual(.init(str: "abc", int: 2, extra: .init(strs: ["q", "r", "s"])), obj.info)
    }

    #if canImport(Darwin)
    static var MemCheckObjectCount = 0

    func testMemoryManagement() throws {
        class MemCheckObject : JackedObject {
            @Track var a = false // modest memory growth
            @Stack var b = false // massive memory growth!
            @Pack var c = false // massive memory growth!


            init() {
                JackTests.MemCheckObjectCount += 1
            }

            deinit {
                JackTests.MemCheckObjectCount -= 1
            }
        }

        let memStart = memoryUsageMB() ?? 0

        for i in 0...1_000 {
            let obj = MemCheckObject()
            let _ = try obj.jack().context

            // track down leaks
//            assert(JackTests.MemCheckObjectCount == 0)

            if i % 200 == 0 {
                let mb = (memoryUsageMB() ?? 0)
                //print("testMemoryManagement #\(i): memory usage: \(UInt(mb))MB")
                if (mb - memStart) > 100 {
                    return XCTFail("too much memory after \(i) iterations: \(UInt(mb))MB")
                }
            }
        }

        /// The `resident_size` of memory in use by the process, in megabytes.
        func memoryUsageMB() -> Float? {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
            let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }
            return kerr == KERN_SUCCESS ? Float(info.resident_size) / (1024 * 1024) : nil
        }

    }
    #endif

    func testJackProperties() throws {
        class JackProperties : JackedObject {
            @Jack private var f0 = hi
            func hi() -> Date { Date(timeIntervalSince1970: 1234) }

            @Jack private var f1 = hello // expose the 1-arg function
            func hello(name: String) -> String { "Hello \(name)!" }

            @Jack("F2") private var f2 = happyBirthday // expose the 2-arg function
            func happyBirthday(name: String, age: Int) -> String { "Happy Birthday \(name), you are \(age)!" }

            @Jack("replicate") private var _replicate = replicate
            func replicate(_ pack: PackedCodable, count: Int) -> [PackedCodable] { Array(Array(repeating: pack, count: count)) }

            @Jack("exceptional") private var _exceptional = exceptional
            func exceptional() throws -> Bool { throw SomeError(reason: "YOLO") }

            struct SomeError : Error {
                var reason: String
            }

        }

        /// A sample of codable passing
        struct PackedCodable : Codable, Equatable, JXConvertible {
            var id = UUID()
            var str = ""
            var num: Int?
        }

        let obj = JackProperties()
        let jxc = try obj.jack().context

        XCTAssertEqual("function", try jxc.eval("typeof f0").string)
        XCTAssertEqual("function", try jxc.eval("typeof f1").string)
        XCTAssertEqual("undefined", try jxc.eval("typeof f2").string, "f2 should be visible as F2")
        XCTAssertEqual("function", try jxc.eval("typeof F2").string)
        XCTAssertEqual("function", try jxc.eval("typeof replicate").string)
        XCTAssertEqual("function", try jxc.eval("typeof exceptional").string)

        XCTAssertEqual(1_234_000, try jxc.eval("f0()").double)
        XCTAssertEqual("Hello x!", try jxc.eval("f1('x')").string)
        XCTAssertEqual("Happy Birthday x, you are 9!", try jxc.eval("F2('x', 9)").string)

        let c = PackedCodable(id: UUID(uuidString: "4991E2A0-DE05-4BB3-B502-42F7584C9973")!, str: "abc", num: 9)
        XCTAssertEqual([c, c, c], try jxc.eval("replicate({ id: '4991E2A0-DE05-4BB3-B502-42F7584C9973', str: 'abc', num: 9 }, 3)").toDecodable(ofType: Array<PackedCodable>.self))

        // make sure we are blocked from setting the function property from JS
        XCTAssertThrowsError(try jxc.eval("f0 = null")) { error in
            //XCTAssertEqual(#"evaluationErrorString("Error: cannot set a function from JS")"#, "\(error)")
        }

    }

    func testAllPropertyWrappers() throws {
        class EnhancedObj : JackedObject {
            @Track var x = 0 // unexported to jxc
            @Stack var i = 1 // exported as number
            @Stack("B") var b = false // exported as bool
            @Pack var id = UUID() // exported (via codability) as string
            @Jack("now") private var _now = now // exported as function
            func now() -> Date { Date(timeIntervalSince1970: 1_234) }

        }

        let obj = EnhancedObj()
        let jxc = try obj.jack().context

        XCTAssertEqual("undefined", try jxc.eval("typeof x").string)
        XCTAssertEqual("number", try jxc.eval("typeof i").string)
        XCTAssertEqual("undefined", try jxc.eval("typeof b").string) // aliased away
        XCTAssertEqual("boolean", try jxc.eval("typeof B").string) // aliased
        XCTAssertEqual("string", try jxc.eval("typeof id").string)
        XCTAssertEqual("function", try jxc.eval("typeof now").string)
        XCTAssertEqual("object", try jxc.eval("typeof now()").string)
        XCTAssertEqual(1_234_000, try jxc.eval("now()").double)
    }
}

/// Demo class
class AppleJack : JackedObject {
    @Stack var name: String
    @Stack var age: Int

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    @Jack("haveBirthday") var _haveBirthday = haveBirthday
    func haveBirthday(count: Int? = nil) -> Int {
        age += count ?? 1
        return age
    }

    static func demo() throws {
        let jackApp = AppleJack(name: "Jack Appleseed", age: 24)
        let jxc = try jackApp.jack().context

        let namejs = try jxc.eval("name").string
        XCTAssertTrue(namejs == jackApp.name)

        let agejs = try jxc.eval("age").double
        XCTAssertTrue(agejs == Double(jackApp.age)) // JS numbers are always Double

        XCTAssertTrue(jackApp.haveBirthday(count: 1) == 25) // direct Swift call
        let newAge = try jxc.eval("haveBirthday()").double // script invocation
        XCTAssertTrue(newAge == 26.0)
        XCTAssertTrue(jackApp.age == 26)
    }
}


/// Demo concurrent class with locking
@MainActor class SynchronizedJackedObject : JackedObject {
    @Stack var name: String
    @Stack var age: Int

    /// A concurrent queue to allow multiple reads at once.
    private var queue = DispatchQueue(label: "SynchronizedJackedObject", attributes: .concurrent)

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    /// Evaluate the script; this is protected by the actor
    func eval(_ script: String) throws -> JXValue {
        let ctx = try jack().context
        return try queue.sync(flags: .barrier) {
            try ctx.eval(script)
        }
    }
}

/// Demo actor
actor JackedActor : JackedObject {
    @Stack var name: String
    @Stack var age: Int

    init(name: String, age: Int) {
        // Actor-isolated property 'name' can not be mutated from a non-isolated context; this is an error in Swift 6
        // self.name = name
        // self.age = age

        self._name = Stack(wrappedValue: name)
        self._age = Stack(wrappedValue: age)
    }

    /// Evaluate the script in an actor-synchronized block
    func eval(_ script: String) throws -> JXValue {
        try self.jack().context.eval(script)
    }

    func incrementAge() -> Int {
        age += 1
        return age
    }
}


/// Work-in-Progress marker
@available(*, deprecated, message: "work in progress")
@inlinable internal func wip<T>(_ value: T) -> T { value }

