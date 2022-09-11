import XCTest
import Jack
import protocol OpenCombineShim.ObservableObject
import struct OpenCombineShim.Published

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
final class JackedObjectTests: XCTestCase {
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
        try await jumpedTests(arg: UUID.self, ret: Date.self)
        try await jumpedTests(arg: Date.self, ret: UUID.self)
        try await jumpedTests(arg: Date.self, ret: Date.self)
    }

    private func jumpedTests<A: Conveyable & Randomizable & JSConvertable & Equatable, R: Conveyable & Randomizable & Equatable>(arg: A.Type, ret: R.Type) async throws {
        let obj = RandoJack<A, R>()

        XCTAssertNotEqual(R.rnd(), try obj.jsc.eval("func0()").convey(in: obj.jsc))
        XCTAssertNotEqual(R.rnd(), try obj.jsc.eval("tfunc0()").convey(in: obj.jsc))
        try withExtendedLifetime(try await obj.jsc.eval("atfunc0()", priority: .low)) { x in
            XCTAssertNotEqual(R.rnd(), try x.convey(in: obj.jsc))
        }

        let p: TaskPriority = TaskPriority.high

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
            let lres = try await obj.jsc.eval("promise0()", priority: .high)
            XCTAssertEqual(13, try lres.numberValue)
        }

        do {
            let lres = try await obj.jsc.eval("promise1(12)", priority: .high)
            XCTAssertEqual("12", try lres.stringValue)
        }

        do {
            let l8r = try await obj.jsc.eval("(async () => { return 999 })()", priority: .high)
            XCTAssertEqual(999, try l8r.numberValue)
        } catch {
            XCTFail("\(error)")
        }

        do {
            try await obj.jsc.eval("999", priority: .high)
            XCTFail("should not have been able to async invoke a sync function")
        } catch {
            XCTAssertEqual("asyncEvalMustReturnPromise", "\(error)")
        }

        do {
            let l8r = try await obj.jsc.eval("(async () => { throw Error('async error') })()", priority: .high)
            XCTFail("should have thrown: \(l8r)")
        } catch {
            XCTAssertEqual("jxerror([JXValue])", "\(error)")
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
            let x = try await obj.jsc.eval("H2('x', 9)", priority: .high).stringValue
            XCTAssertEqual("Happy Birthday x, you are 9!", x)
        }

        do {
            let c = Coded(id: UUID(uuidString: "4991E2A0-DE05-4BB3-B502-42F7584C9973")!, str: "abc", num: 9)
            let x = try await obj.jsc.eval("replicate({ id: '4991E2A0-DE05-4BB3-B502-42F7584C9973', str: 'abc', num: 9 }, 3)", priority: .high)
            XCTAssertEqual([c, c, c], try x.toDecodable(ofType: Array<Coded>.self))
        }

        // make sure we are blocked from setting the function property from JS
        XCTAssertThrowsError(try obj.jsc.eval("h0 = null")) { error in
            //XCTAssertEqual(#"evaluationErrorString("Error: cannot set a function from JS")"#, "\(error)")
        }

        try obj.jsc.eval("bye()")
        try obj.jsc.eval("byebye()")
    }
}

// MARK: Testing protocols

fileprivate protocol Randomizable { static func rnd() -> Self }
fileprivate protocol JSConvertable { var js: String { get } }

// MARK: UUID

extension UUID : Conveyable {
}

extension UUID : Randomizable {
    static func rnd() -> Self {
        UUID()
    }
}

extension UUID : JSConvertable {
    var js: String {
        "'" + self.uuidString + "'"
    }
}

// MARK: Date

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
private let iso8601fmt: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter
}()


extension Date : Randomizable {
    static func rnd() -> Self {
        Date(timeIntervalSinceNow: TimeInterval.random(in: -1_000_000_000...(+1_000_000_000)))
    }
}

extension Date : JSConvertable {
    var js: String {
        "new Date('" + iso8601fmt.string(from: self) + "')"
    }
}

// MARK: String

extension String : Randomizable {
    static func rnd() -> Self {
        UUID().uuidString
    }
}

extension String : JSConvertable {
    var js: String {
        "'" + self.self.replacingOccurrences(of: "'", with: "\\'") + "'"
    }
}

// MARK: Int32

extension Int32 : Randomizable {
    static func rnd() -> Self {
        .random(in: (.min)...(.max))
    }
}

extension Int32 : JSConvertable {
    var js: String {
        self.description
    }
}

actor ActorDemo : JackedObject {
    @Jacked var xxx = ""
    //@Jumped("func0") private var _func0 = func0
    func func0() -> UUID { .rnd() }

    lazy var jsc = jack()
}

/// A generic jumpable type that represents functions with all the possible arities.
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
private class RandoJack<A: Conveyable, ReturnType: Randomizable & Conveyable> : JackedObject {
    private func cast(_ value: Any) -> ReturnType {
        value as? ReturnType ?? .rnd()
    }

    @Jumped("func0") private var _func0 = func0
    func func0() -> ReturnType { .rnd() }

    @Jumped("tfunc0") private var _tfunc0 = tfunc0
    func tfunc0() throws -> ReturnType { .rnd() }

    @Jumped("atfunc0", priority: .low) private var _atfunc0 = atfunc0
    func atfunc0() async throws -> ReturnType { .rnd() }


    @Jumped("func1") private var _func1 = func1
    func func1(i0: A) -> ReturnType { cast(i0) }

    @Jumped("tfunc1") private var _tfunc1 = tfunc1
    func tfunc1(i0: A) throws -> ReturnType { cast(i0)  }

    @Jumped("atfunc1", priority: .low) private var _atfunc1 = atfunc1
    func atfunc1(i0: A) async throws -> ReturnType { cast(i0)  }


    @Jumped("func2") private var _func2 = func2
    func func2(i0: A, i1: A) -> ReturnType { cast(i1)  }

    @Jumped("tfunc2") private var _tfunc2 = tfunc2
    func tfunc2(i0: A, i1: A) throws -> ReturnType { cast(i1)  }

    @Jumped("atfunc2", priority: .low) private var _atfunc2 = atfunc2
    func atfunc2(i0: A, i1: A) async throws -> ReturnType { cast(i1)  }


    @Jumped("func3") private var _func3 = func3
    func func3(i0: A, i1: A, i2: A) -> ReturnType { cast(i2)  }

    @Jumped("tfunc3") private var _tfunc3 = tfunc3
    func tfunc3(i0: A, i1: A, i2: A) throws -> ReturnType { cast(i2)  }

    @Jumped("atfunc3", priority: .low) private var _atfunc3 = atfunc3
    func atfunc3(i0: A, i1: A, i2: A) async throws -> ReturnType { cast(i2)  }


    @Jumped("func4") private var _func4 = func4
    func func4(i0: A, i1: A, i2: A, i3: A) -> ReturnType { cast(i3)  }

    @Jumped("tfunc4") private var _tfunc4 = tfunc4
    func tfunc4(i0: A, i1: A, i2: A, i3: A) throws -> ReturnType { cast(i3)  }

    @Jumped("atfunc4", priority: .low) private var _atfunc4 = atfunc4
    func atfunc4(i0: A, i1: A, i2: A, i3: A) async throws -> ReturnType { cast(i3)  }


    @Jumped("func5") private var _func5 = func5
    func func5(i0: A, i1: A, i2: A, i3: A, i4: A) -> ReturnType { cast(i4)  }

    @Jumped("tfunc5") private var _tfunc5 = tfunc5
    func tfunc5(i0: A, i1: A, i2: A, i3: A, i4: A) throws -> ReturnType { cast(i4)  }

    @Jumped("atfunc5", priority: .low) private var _atfunc5 = atfunc5
    func atfunc5(i0: A, i1: A, i2: A, i3: A, i4: A) async throws -> ReturnType { cast(i4)  }


    @Jumped("func6") private var _func6 = func6
    func func6(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A) -> ReturnType { cast(i5)  }

    @Jumped("tfunc6") private var _tfunc6 = tfunc6
    func tfunc6(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A) throws -> ReturnType { cast(i5)  }

    @Jumped("atfunc6", priority: .low) private var _atfunc6 = atfunc6
    func atfunc6(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A) async throws -> ReturnType { cast(i5)  }


    @Jumped("func7") private var _func7 = func7
    func func7(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A) -> ReturnType { cast(i6)  }

    @Jumped("tfunc7") private var _tfunc7 = tfunc7
    func tfunc7(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A) throws -> ReturnType { cast(i6)  }

    @Jumped("atfunc7", priority: .low) private var _atfunc7 = atfunc7
    func atfunc7(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A) async throws -> ReturnType { cast(i6)  }


    @Jumped("func8") private var _func8 = func8
    func func8(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A, i7: A) -> ReturnType { cast(i7)  }

    @Jumped("tfunc8") private var _tfunc8 = tfunc8
    func tfunc8(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A, i7: A) throws -> ReturnType { cast(i7)  }

    @Jumped("atfunc8", priority: .low) private var _atfunc8 = atfunc8
    func atfunc8(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A, i7: A) async throws -> ReturnType { cast(i7)  }


    @Jumped("func9") private var _func9 = func9
    func func9(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A, i7: A, i8: A) -> ReturnType { cast(i8)  }

    @Jumped("tfunc9") private var _tfunc9 = tfunc9
    func tfunc9(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A, i7: A, i8: A) throws -> ReturnType { cast(i8)  }

    @Jumped("atfunc9", priority: .low) private var _atfunc9 = atfunc9
    func atfunc9(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A, i7: A, i8: A) async throws -> ReturnType { cast(i8)  }


    @Jumped("func10") private var _func10 = func10
    func func10(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A, i7: A, i8: A, i9: A) -> ReturnType { cast(i9)  }

    @Jumped("tfunc10") private var _tfunc10 = tfunc10
    func tfunc10(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A, i7: A, i8: A, i9: A) throws -> ReturnType { cast(i9)  }

    @Jumped("atfunc10", priority: .low) private var _atfunc10 = atfunc10
    func atfunc10(i0: A, i1: A, i2: A, i3: A, i4: A, i5: A, i6: A, i7: A, i8: A, i9: A) async throws -> ReturnType { cast(i9)  }

    lazy var jsc = jack()
}
