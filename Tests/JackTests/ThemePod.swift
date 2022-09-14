import Jack
import Foundation

// MARK: ThemePod

// theme.backgroundColor = 'purple';
// theme.defaultTabItemHighlight = 'red';

#if canImport(UIKit)
import UIKit

@available(macOS 11, iOS 13, tvOS 13, *)
public class ThemePod : JackPod {
    init() {
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()

    @Jumped("setNavigationBarTintColor") var _setNavigationBarTintColor = setNavigationBarTintColor
    func setNavigationBarTintColor(color: String) throws {
        print("setNavigationBarTintColor:", wip(color))
        // UINavigationBar.appearance().tintColor = parseCSSColor
    }

//    @Jumped("setNavigationBarTintColor") var _setNavigationBarTintColor = setNavigationBarTintColor
//    func setNavigationBarTintColor(color: ThemeColor) throws {
//        print("setNavigationBarTintColor:", wip(color))
//        // UINavigationBar.appearance().tintColor = parseCSSColor
//    }
}

// public struct ThemeColor = XOr<RGBColor>.Or<HSLColor>.Or<ParsedCSSColor>

#endif

#if canImport(XCTest)
import XCTest

@available(macOS 11, iOS 13, tvOS 13, *)
final class ThemePodTests: XCTestCase {
    #if canImport(UIKit)
    func testThemePod() async throws {
        let pod = ThemePod()
        //try await pod.jxc.eval("sleep()", priority: .high)
        XCTAssertEqual(3, try pod.jxc.eval("1+2").numberValue)

        try pod.jxc.eval("setNavigationBarTintColor('blue')")
        try pod.jxc.eval("setNavigationBarTintColor('#FFAA0055')")
//        try pod.jxc.eval("setNavigationBarTintColor('rgba(50%, 1.324, 948, 0.7)')")
//
//        try pod.jxc.eval("setNavigationBarTintColor({ r: 0.5, g: 1.0, b: 0.7, a: 0.75 })")
//        try pod.jxc.eval("setNavigationBarTintColor({ h: 245, s: 0.7, l: 0.9 })")

    }
    #endif
}
#endif
