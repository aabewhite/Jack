import Foundation
import Jack
import JXKit
import SwiftUI
import XCTest

@available(macOS 11, iOS 14, tvOS 14, *)
final class UIPodTests: XCTestCase {

    #if canImport(SwiftUI)
    func testUIPod() throws {
        class ViewModel: JackedObject {
            @Jacked(bind: "$") var sliderValue = 0.0
        }

        let vm = ViewModel()
        let jxc = vm.jack().env

        let uipod = UIPod() // need to retain or else Error: jumpContextInvalid
        uipod.jack(into: jxc) // , as: "ui" // TODO: should be namespace?

        XCTAssertEqual(3, try jxc.eval("1+2").numberValue)

        let str = UUID().uuidString
        let obj = try jxc.eval("Text('\(str)')")
        XCTAssertEqual(str, try obj["value"].stringValue)
        XCTAssertTrue(try jxc.eval("Text('\(str)')").isObject)
        XCTAssertNotNil(try jxc.eval("Text('\(str)')").convey(to: ViewProxy.self))
        XCTAssertEqual(str, try jxc.eval("Text('\(str)')").convey(to: TextProxy.self).value)

        @discardableResult func view(_ script: String) throws -> ViewProxy {
            try jxc.eval(script).convey()
        }

        // MARK: Container Views

        XCTAssertNil(try view("Spacer()").childViews)
        XCTAssertNil(try view("Divider()").childViews)

        XCTAssertNil(try view("Group()").childViews)
        XCTAssertNil(try view("List()").childViews)
        XCTAssertNil(try view("Form()").childViews)

        XCTAssertNil(try view("Group(null)").childViews)

        XCTAssertEqual(1, try view("Group([Spacer()])").childViews?.count)
        XCTAssertEqual(2, try view("Group([Group(), Group([])])").childViews?.count)

        // XCTAssertEqual(2, try view("Group({}}, [Group(), Group()])").childViews?.count)
        // XCTAssertEqual(2, try view("Group(null, [Group(), Group()])").childViews?.count)

        XCTAssertThrowsError(try view("VStack({ alignment: 'XXX' })"), "bad alignment constant")
        XCTAssertThrowsError(try view("VStack(Group())"), "param must be array")
        XCTAssertThrowsError(try view("VStack([null])"))

        XCTAssertEqual(nil, try view("VStack()").childViews?.count)
        XCTAssertEqual(nil, try view("VStack(null)").childViews?.count)
        XCTAssertEqual(2, try view("VStack([Group(), Group()])").childViews?.count, "should have 2 children")
        XCTAssertEqual(6, try view("VStack([Group(), Form(), Spacer(), HStack(), LazyHStack(), LazyVStack()])").childViews?.count)

        @discardableResult func txt(_ script: String) throws -> TextProxy {
            try jxc.eval(script).convey()
        }

        // MARK: Text Views

        XCTAssertEqual("TITLE", try txt("Text('TITLE')").value)
        XCTAssertEqual("TITLE", try txt("Text('TITLE').fontStyle('title').fontSize(12.2)").value)

        // check enum validation
        XCTAssertThrowsError(try txt("Text('TITLE').fontStyle('titleXXX')")) { error in
            guard let err = error as? JXError else {
                return XCTFail("Bad error type: \(error)")
            }
            XCTAssertEqual("Error: rawInitializerFailed(titleXXX, Jack.JackError.Context(context: JXKit.JXContext))", err.description)
        }

        // MARK: Button Actions

        XCTAssertThrowsError(try view("Button(Text(`Press Me`))")) { error in
            XCTAssertEqual("Error: Second argument to Button constructor must be the callback function", "\(error)")
        }
        XCTAssertEqual(1, try view("Button(Text(`Press Me`), () => { })").childViews?.count)


        // MARK: Slider Bindings

        XCTAssertThrowsError(try view("Slider(Text(`Slide Me`))")) { error in
            XCTAssertEqual("Error: Second Slider argument must be the value getter function", "\(error)")
        }
        XCTAssertThrowsError(try view("Slider(Text(`Slide Me`), () => { })")) { error in
            XCTAssertEqual("Error: Third Slider argument must be the value setter function", "\(error)")
        }
        XCTAssertEqual(1, try view("Slider(Text(`Slide Me`), () => { }, (newValue) => { })").childViews?.count)

        // Symbolic form of binding

        XCTAssertEqual(1, try view("Slider(Text(`Slide Me`), $sliderValue)").childViews?.count)


//        XCTAssertEqual(0, try view("VStack({alignment: 'leading'})").childViews?.count)
//        XCTAssertEqual(0, try view("VStack({alignment: 'center'})").childViews?.count)
//        XCTAssertEqual(1, try view("VStack({}, [Group()])").childViews?.count)
//
//        XCTAssertEqual(1, try view("VStack(null, [Group()])").childViews?.count)
//
//
//        XCTAssertEqual(1, try view("VStack({ alignment: 'leading' }, [Group()])").childViews?.count)
//        XCTAssertEqual(10, try view("VStack({ alignment: 'leading' }, [Group(), Group(), Group(), Group(), Group(), Group(), Group(), Group(), Group(), Group()])").childViews?.count)


//        do {
//            try view("Group()")
//            try view("HStack({})")
//            try view("Form()")
//            try view("VStack({}, [Group()])")
//
//            try view("LazyVStack({})")
//            try view("LazyVStack({}, [])")
//            try view("LazyVStack([])")
//            try view("LazyVStack([Spacer(), Group([])])")
//        }
//
//        do {
//            let tree1 = try view("""
//            VStack({ alignment: 'leading', spacing: 5 }, [
//                Text({}, "TITLE").fontStyle('title').fontSize(12.2),
//                Group([
//                    Divider(),
//                    HStack({}, [Spacer(), Divider()])
//                ])
//            ])
//            """)
//
//            //XCTAssertEqual("vstack(builder: JackTests.ContainerProxy.VStackProps(alignment: Optional(JackTests.ContainerProxy.VStackProps.Alignment.leading), spacing: Optional(5.0)))", "\(tree1.type)")
//        }
//
//        //XCTAssertEqual("", "\(vproxy.body)")

//        let _ = uipod
    }

    func testAppStorageObservableObject() throws {
        class DemoObject : ObservableObject {
            @Published var intProp = 0
            @AppStorage("appStoragePodProp") var appValue = 1
        }

        let obj = DemoObject()
        var changes = 0
        withExtendedLifetime(obj.objectWillChange.sink { changes += 1 }) {
            XCTAssertEqual(changes, 0)
            obj.intProp += 1
            XCTAssertEqual(changes, 1)
            obj.appValue += 1
            XCTAssertGreaterThan(changes, 1, "AppStorage triggers changes in ObservableObject")
        }
    }

    /// Disabled because we raise a fatalError() when any non-Jack property wrappers are found in a JackedObject.
    func XXXtestAppStorageJackPod() throws {

        class DemoObject : JackPod {
            @Jacked var intProp = 0
            @AppStorage("appStoragePodProp") var appValue = 1

            public var metadata: JackPodMetaData {
                JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
            }

            public lazy var pod = jack()
        }

        let pod = DemoObject()
        var changes = 0
        withExtendedLifetime(pod.objectWillChange.sink { changes += 1 }) {
            XCTAssertEqual(changes, 0)
            pod.intProp += 1
            XCTAssertEqual(changes, 1)
            pod.appValue += 1
            // XCTAssertGreaterThan(changes, 1) // this would be true if it was an ObservableObject
            XCTAssertEqual(changes, 1, "AppStorage does not work with JackPod")
        }
    }

    #endif
}
