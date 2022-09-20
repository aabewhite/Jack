import Jack
import Foundation


// MARK: ThemePod

// theme.backgroundColor = 'purple';
// theme.defaultTabItemHighlight = 'red';

@available(macOS 11, iOS 13, tvOS 13, *)
public class ThemePod : JackPod {
    /// Should this be shared instead?
    public init() {
        setupListeners()
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()

    @Jacked public var backgroundColor: CSSColor?

    private var observers: [AnyObject] = []

    deinit {
        // clear circular references
        observers.removeAll()
    }

    // MARK: UIKit-specific properties
    #if canImport(UIKit)
    static var navBar: UINavigationBar { UINavigationBar.appearance() }

    @Coded public var navBarTintColor: CSSColor? = navBar.tintColor?.ciColor.cssColor
    static func navBarTintColorDidSet(_ newValue: CSSColor?) {
        navBar.tintColor = newValue?.nativeColor.uiColor
    }

    static var tabBar: UITabBar { UITabBar.appearance() }

    @Coded public var tabBarTintColor: CSSColor? = tabBar.tintColor?.ciColor.cssColor
    static func tabBarTintColorDidSet(_ newValue: CSSColor?) {
        tabBar.tintColor = newValue?.nativeColor.uiColor
    }

    static var label: UILabel { UILabel.appearance() }

    @Coded public var labelTintColor: CSSColor? = label.tintColor?.ciColor.cssColor
    static func labelTintColorDidSet(_ newValue: CSSColor?) {
        label.tintColor = newValue?.nativeColor.uiColor
    }


    func setupListeners() {
        observers += [
            $navBarTintColor.sink(receiveValue: Self.navBarTintColorDidSet),
            $tabBarTintColor.sink(receiveValue: Self.tabBarTintColorDidSet),
            $labelTintColor.sink(receiveValue: Self.labelTintColorDidSet),
            //$navBarTintColor.sink(receiveValue: { [weak self] _ in }),
            ]
    }

    #else

    //static var textField: NSTextField { NSTextField.appearance }

    func setupListeners() {
        // TODO: AppKit
    }

    #endif
}

// MARK: UIKit-specific properties

#if canImport(UIKit)
import UIKit

@available(macOS 11, iOS 13, tvOS 13, *)
extension ThemePod {

}

#endif

// MARK: AppKit-specific properties

#if canImport(AppKit)
import AppKit

@available(macOS 11, iOS 13, tvOS 13, *)
extension ThemePod {

}
#endif


// public struct ThemeColor = XOr<RGBColor>.Or<HSLColor>.Or<ParsedCSSColor>


/**
 ## Formal syntax

 from https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#formal_syntax

 ```
 <color> =
 <absolute-color-base>  |
 currentcolor           |
 <system-color>

 <absolute-color-base> =
 <hex-color>                |
 <absolute-color-function>  |
 <named-color>              |
 transparent

 <absolute-color-function> =
 <rgb()>    |
 <rgba()>   |
 <hsl()>    |
 <hsla()>   |
 <hwb()>    |
 <lab()>    |
 <lch()>    |
 <oklab()>  |
 <oklch()>  |
 <color()>

 <rgb()> =
 rgb( [ <percentage> | none ]{3} [ / [ <alpha-value> | none ] ]? )  |
 rgb( [ <number> | none ]{3} [ / [ <alpha-value> | none ] ]? )

 <hsl()> =
 hsl( [ <hue> | none ] [ <percentage> | none ] [ <percentage> | none ] [ / [ <alpha-value> | none ] ]? )

 <hwb()> =
 hwb( [ <hue> | none ] [ <percentage> | none ] [ <percentage> | none ] [ / [ <alpha-value> | none ] ]? )

 <lab()> =
 lab( [ <percentage> | <number> | none ] [ <percentage> | <number> | none ] [ <percentage> | <number> | none ] [ / [ <alpha-value> | none ] ]? )

 <lch()> =
 lch( [ <percentage> | <number> | none ] [ <percentage> | <number> | none ] [ <hue> | none ] [ / [ <alpha-value> | none ] ]? )

 <oklab()> =
 oklab( [ <percentage> | <number> | none ] [ <percentage> | <number> | none ] [ <percentage> | <number> | none ] [ / [ <alpha-value> | none ] ]? )

 <oklch()> =
 oklch( [ <percentage> | <number> | none ] [ <percentage> | <number> | none ] [ <hue> | none ] [ / [ <alpha-value> | none ] ]? )

 <color()> =
 color( <colorspace-params> [ / [ <alpha-value> | none ] ]? )

 <alpha-value> =
 <number>      |
 <percentage>

 <hue> =
 <number>  |
 <angle>   |
 none

 <colorspace-params> =
 <predefined-rgb-params>  |
 <xyz-params>

 <predefined-rgb-params> =
 <predefined-rgb> [ <number> | <percentage> | none ]{3}

 <xyz-params> =
 <xyz-space> [ <number> | <percentage> | none ]{3}

 <predefined-rgb> =
 srgb          |
 srgb-linear   |
 display-p3    |
 a98-rgb       |
 prophoto-rgb  |
 rec2020

 <xyz-space> =
 xyz      |
 xyz-d50  |
 xyz-d65
 ```
 */
public struct CSSColor : Codable, Hashable, CustomStringConvertible, JXConvertible {
    public var rep: ColorRepresentation

    /// Create this color with a CSS named color
    public init(name color: NamedColor) {
        self.rep = .name(color)
    }

    /// Create this color with an RGB description
    public init(rgb color: RGBColor) {
        self.rep = .rgb(color)
    }

    public var description: String {
        switch rep {
        case .name(let name): return name.description
        case .rgb(let color): return color.description
        }
    }

    public enum ColorError : Error {
        case hexStringMissingPercent
        case parseErrors(errors: [Error])
        case hexStringInvalid(string: String)
    }

    public init(from decoder: Decoder) throws {
        do {
            do {
                self.rep = try .name(.init(from: decoder))
            } catch let e1 {
                do {
                    self.rep = try .rgb(.init(from: decoder))
                } catch let e2 {
                    do {
                        let str = try String(from: decoder)
                        self.rep = try .rgb(.parseColor(css: str))
                    } catch let e3 {
                        throw ColorError.parseErrors(errors: [e1, e2, e3])
                    }
                }
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch rep {
        case .name(let x): try container.encode(x)
        case .rgb(let x): try container.encode(x)
            //case .hsl(let x): try container.encode(x)
        }
    }

    public enum ColorRepresentation: Hashable, CustomStringConvertible {
        case name(NamedColor)
        case rgb(RGBColor)
        //case hsl(HSLColor)
        // case hwb(HWBColor) // TODO: maybe someday

        public var description: String {
            switch self {
            case .name(let name): return name.description
            case .rgb(let color): return color.description
            }
        }
    }

    public struct RGBColor : Codable, Hashable, CustomStringConvertible, ExpressibleByIntegerLiteral {
        public var r: Double
        public var g: Double
        public var b: Double
        public var a: Double?

        public init(r: Double, g: Double, b: Double, a: Double? = nil) {
            self.r = r
            self.g = g
            self.b = b
            self.a = a
        }

        /// Create from a single integer like 0x55AA11FF
        public init(integerLiteral value: IntegerLiteralType) {
            let r = (value & 0xFF0000) >> 16
            let g = (value & 0x00FF00) >> 8
            let b = (value & 0x0000FF) >> 0

            self.init(r: CGFloat(r) / 255, g: CGFloat(g) / 255, b: CGFloat(b) / 255, a: 1.0)
        }

        public static func parseColor(css: String) throws -> RGBColor {
            return try parseHexColor(css: css)
        }

        public var description: String {
            "#" + ([r, g, b, a].compactMap({ $0 }).map { c in
                String(format: "%02X", Int(c * 255.0))
            }).joined()
        }

        public static func parseHexColor(css: String) throws -> RGBColor {
            guard css.first == "#" else {
                throw ColorError.hexStringMissingPercent
            }
            let chars = Array(css.dropFirst(1))

            func parse(_ str: ArraySlice<Character>) throws -> Double {
                guard let i = Int(String(str), radix: 16) else {
                    throw ColorError.hexStringInvalid(string: String(str))
                }
                return Double(i) / 255.0
            }

            switch chars.count {
            case 3: // #A1B
                return try RGBColor(r: parse(chars[0...0]), g: parse(chars[1...1]), b: parse(chars[2...2]))
            case 4: // #A1B0
                return try RGBColor(r: parse(chars[0...0]), g: parse(chars[1...1]), b: parse(chars[2...2]), a: parse(chars[3...3]))
            case 6: // #AB1122
                return try RGBColor(r: parse(chars[0...1]), g: parse(chars[2...3]), b: parse(chars[4...5]))
            case 8: // #AB1122FF
                return try RGBColor(r: parse(chars[0...1]), g: parse(chars[2...3]), b: parse(chars[4...5]), a: parse(chars[6...7]))

            default:
                throw ColorError.hexStringInvalid(string: css)
            }

            //
            //            func parseColor(_ r: String, _ g: String, _ b: String, _ a: String = "0xFF") -> (Double, Double, Double, Double) {
            //                (coerce(r) ?? 0.5, coerce(g) ?? 0.5, coerce(b) ?? 0.5, coerce(a) ?? 1.0)
            //            }

        }
    }

    //    public struct HSLColor : Codable, Hashable {
    //        var h: Double
    //        var s: Double
    //        var l: Double
    //        var a: Double?
    //    }

    public struct NamedColor : Codable, Hashable, RawRepresentable, CaseIterable, CustomStringConvertible {
        public var name: String
        public var color: RGBColor

        // named colors from: https://developer.mozilla.org/en-US/docs/Web/CSS/named-color

        public init(name: String, color: RGBColor) {
            self.name = name
            self.color = color
        }

        public var description: String {
            "\"" + name + "\""
        }

        public init?(rawValue: String) {
            let str = rawValue.lowercased()
            for namedColor in Self.allCases {
                if str == namedColor.name {
                    self = namedColor
                    return
                }
            }

            return nil
        }

        public var rawValue: String {
            name
        }

        public static var allCases: [NamedColor] {
            [
                transparent,
                black,
                silver,
                gray,
                white,
                maroon,
                red,
                purple,
                fuchsia,
                green,
                lime,
                olive,
                yellow,
                navy,
                blue,
                teal,
                aqua,
                orange,
                aliceblue,
                antiquewhite,
                aquamarine,
                azure,
                beige,
                bisque,
                blanchedalmond,
                blueviolet,
                brown,
                burlywood,
                cadetblue,
                chartreuse,
                chocolate,
                coral,
                cornflowerblue,
                cornsilk,
                crimson,
                cyan,
                darkblue,
                darkcyan,
                darkgoldenrod,
                darkgray,
                darkgreen,
                darkgrey,
                darkkhaki,
                darkmagenta,
                darkolivegreen,
                darkorange,
                darkorchid,
                darkred,
                darksalmon,
                darkseagreen,
                darkslateblue,
                darkslategray,
                darkslategrey,
                darkturquoise,
                darkviolet,
                deeppink,
                deepskyblue,
                dimgray,
                dimgrey,
                dodgerblue,
                firebrick,
                floralwhite,
                forestgreen,
                gainsboro,
                ghostwhite,
                gold,
                goldenrod,
                greenyellow,
                grey,
                honeydew,
                hotpink,
                indianred,
                indigo,
                ivory,
                khaki,
                lavender,
                lavenderblush,
                lawngreen,
                lemonchiffon,
                lightblue,
                lightcoral,
                lightcyan,
                lightgoldenrodyellow,
                lightgray,
                lightgreen,
                lightgrey,
                lightpink,
                lightsalmon,
                lightseagreen,
                lightskyblue,
                lightslategray,
                lightslategrey,
                lightsteelblue,
                lightyellow,
                limegreen,
                linen,
                magenta,
                mediumaquamarine,
                mediumblue,
                mediumorchid,
                mediumpurple,
                mediumseagreen,
                mediumslateblue,
                mediumspringgreen,
                mediumturquoise,
                mediumvioletred,
                midnightblue,
                mintcream,
                mistyrose,
                moccasin,
                navajowhite,
                oldlace,
                olivedrab,
                orangered,
                orchid,
                palegoldenrod,
                palegreen,
                paleturquoise,
                palevioletred,
                papayawhip,
                peachpuff,
                peru,
                pink,
                plum,
                powderblue,
                rosybrown,
                royalblue,
                saddlebrown,
                salmon,
                sandybrown,
                seagreen,
                seashell,
                sienna,
                skyblue,
                slateblue,
                slategray,
                slategrey,
                snow,
                springgreen,
                steelblue,
                tan,
                thistle,
                tomato,
                turquoise,
                violet,
                wheat,
                whitesmoke,
                yellowgreen,
            ]
        }

        private static func named(_ name: String, _ color: RGBColor) -> NamedColor {
            NamedColor(name: name, color: color)
        }

        static let transparent = named("transparent", RGBColor(r: 0, g: 0, b: 0, a: 0))

        static let black = named("black", 0x000000)
        static let silver = named("silver", 0xc0c0c0)
        static let gray = named("gray", 0x808080)
        static let white = named("white", 0xffffff)
        static let maroon = named("maroon", 0x800000)
        static let red = named("red", 0xff0000)
        static let purple = named("purple", 0x800080)
        static let fuchsia = named("fuchsia", 0xff00ff)
        static let green = named("green", 0x008000)
        static let lime = named("lime", 0x00ff00)
        static let olive = named("olive", 0x808000)
        static let yellow = named("yellow", 0xffff00)
        static let navy = named("navy", 0x000080)
        static let blue = named("blue", 0x0000ff)
        static let teal = named("teal", 0x008080)
        static let aqua = named("aqua", 0x00ffff)
        static let orange = named("orange", 0xffa500)
        static let aliceblue = named("aliceblue", 0xf0f8ff)
        static let antiquewhite = named("antiquewhite", 0xfaebd7)
        static let aquamarine = named("aquamarine", 0x7fffd4)
        static let azure = named("azure", 0xf0ffff)
        static let beige = named("beige", 0xf5f5dc)
        static let bisque = named("bisque", 0xffe4c4)
        static let blanchedalmond = named("blanchedalmond", 0xffebcd)
        static let blueviolet = named("blueviolet", 0x8a2be2)
        static let brown = named("brown", 0xa52a2a)
        static let burlywood = named("burlywood", 0xdeb887)
        static let cadetblue = named("cadetblue", 0x5f9ea0)
        static let chartreuse = named("chartreuse", 0x7fff00)
        static let chocolate = named("chocolate", 0xd2691e)
        static let coral = named("coral", 0xff7f50)
        static let cornflowerblue = named("cornflowerblue", 0x6495ed)
        static let cornsilk = named("cornsilk", 0xfff8dc)
        static let crimson = named("crimson", 0xdc143c)
        static let cyan = named("cyan", 0x00ffff)
        static let darkblue = named("darkblue", 0x00008b)
        static let darkcyan = named("darkcyan", 0x008b8b)
        static let darkgoldenrod = named("darkgoldenrod", 0xb8860b)
        static let darkgray = named("darkgray", 0xa9a9a9)
        static let darkgreen = named("darkgreen", 0x006400)
        static let darkgrey = named("darkgrey", 0xa9a9a9)
        static let darkkhaki = named("darkkhaki", 0xbdb76b)
        static let darkmagenta = named("darkmagenta", 0x8b008b)
        static let darkolivegreen = named("darkolivegreen", 0x556b2f)
        static let darkorange = named("darkorange", 0xff8c00)
        static let darkorchid = named("darkorchid", 0x9932cc)
        static let darkred = named("darkred", 0x8b0000)
        static let darksalmon = named("darksalmon", 0xe9967a)
        static let darkseagreen = named("darkseagreen", 0x8fbc8f)
        static let darkslateblue = named("darkslateblue", 0x483d8b)
        static let darkslategray = named("darkslategray", 0x2f4f4f)
        static let darkslategrey = named("darkslategrey", 0x2f4f4f)
        static let darkturquoise = named("darkturquoise", 0x00ced1)
        static let darkviolet = named("darkviolet", 0x9400d3)
        static let deeppink = named("deeppink", 0xff1493)
        static let deepskyblue = named("deepskyblue", 0x00bfff)
        static let dimgray = named("dimgray", 0x696969)
        static let dimgrey = named("dimgrey", 0x696969)
        static let dodgerblue = named("dodgerblue", 0x1e90ff)
        static let firebrick = named("firebrick", 0xb22222)
        static let floralwhite = named("floralwhite", 0xfffaf0)
        static let forestgreen = named("forestgreen", 0x228b22)
        static let gainsboro = named("gainsboro", 0xdcdcdc)
        static let ghostwhite = named("ghostwhite", 0xf8f8ff)
        static let gold = named("gold", 0xffd700)
        static let goldenrod = named("goldenrod", 0xdaa520)
        static let greenyellow = named("greenyellow", 0xadff2f)
        static let grey = named("grey", 0x808080)
        static let honeydew = named("honeydew", 0xf0fff0)
        static let hotpink = named("hotpink", 0xff69b4)
        static let indianred = named("indianred", 0xcd5c5c)
        static let indigo = named("indigo", 0x4b0082)
        static let ivory = named("ivory", 0xfffff0)
        static let khaki = named("khaki", 0xf0e68c)
        static let lavender = named("lavender", 0xe6e6fa)
        static let lavenderblush = named("lavenderblush", 0xfff0f5)
        static let lawngreen = named("lawngreen", 0x7cfc00)
        static let lemonchiffon = named("lemonchiffon", 0xfffacd)
        static let lightblue = named("lightblue", 0xadd8e6)
        static let lightcoral = named("lightcoral", 0xf08080)
        static let lightcyan = named("lightcyan", 0xe0ffff)
        static let lightgoldenrodyellow = named("lightgoldenrodyellow", 0xfafad2)
        static let lightgray = named("lightgray", 0xd3d3d3)
        static let lightgreen = named("lightgreen", 0x90ee90)
        static let lightgrey = named("lightgrey", 0xd3d3d3)
        static let lightpink = named("lightpink", 0xffb6c1)
        static let lightsalmon = named("lightsalmon", 0xffa07a)
        static let lightseagreen = named("lightseagreen", 0x20b2aa)
        static let lightskyblue = named("lightskyblue", 0x87cefa)
        static let lightslategray = named("lightslategray", 0x778899)
        static let lightslategrey = named("lightslategrey", 0x778899)
        static let lightsteelblue = named("lightsteelblue", 0xb0c4de)
        static let lightyellow = named("lightyellow", 0xffffe0)
        static let limegreen = named("limegreen", 0x32cd32)
        static let linen = named("linen", 0xfaf0e6)
        static let magenta = named("magenta", 0xff00ff)
        static let mediumaquamarine = named("mediumaquamarine", 0x66cdaa)
        static let mediumblue = named("mediumblue", 0x0000cd)
        static let mediumorchid = named("mediumorchid", 0xba55d3)
        static let mediumpurple = named("mediumpurple", 0x9370db)
        static let mediumseagreen = named("mediumseagreen", 0x3cb371)
        static let mediumslateblue = named("mediumslateblue", 0x7b68ee)
        static let mediumspringgreen = named("mediumspringgreen", 0x00fa9a)
        static let mediumturquoise = named("mediumturquoise", 0x48d1cc)
        static let mediumvioletred = named("mediumvioletred", 0xc71585)
        static let midnightblue = named("midnightblue", 0x191970)
        static let mintcream = named("mintcream", 0xf5fffa)
        static let mistyrose = named("mistyrose", 0xffe4e1)
        static let moccasin = named("moccasin", 0xffe4b5)
        static let navajowhite = named("navajowhite", 0xffdead)
        static let oldlace = named("oldlace", 0xfdf5e6)
        static let olivedrab = named("olivedrab", 0x6b8e23)
        static let orangered = named("orangered", 0xff4500)
        static let orchid = named("orchid", 0xda70d6)
        static let palegoldenrod = named("palegoldenrod", 0xeee8aa)
        static let palegreen = named("palegreen", 0x98fb98)
        static let paleturquoise = named("paleturquoise", 0xafeeee)
        static let palevioletred = named("palevioletred", 0xdb7093)
        static let papayawhip = named("papayawhip", 0xffefd5)
        static let peachpuff = named("peachpuff", 0xffdab9)
        static let peru = named("peru", 0xcd853f)
        static let pink = named("pink", 0xffc0cb)
        static let plum = named("plum", 0xdda0dd)
        static let powderblue = named("powderblue", 0xb0e0e6)
        static let rosybrown = named("rosybrown", 0xbc8f8f)
        static let royalblue = named("royalblue", 0x4169e1)
        static let saddlebrown = named("saddlebrown", 0x8b4513)
        static let salmon = named("salmon", 0xfa8072)
        static let sandybrown = named("sandybrown", 0xf4a460)
        static let seagreen = named("seagreen", 0x2e8b57)
        static let seashell = named("seashell", 0xfff5ee)
        static let sienna = named("sienna", 0xa0522d)
        static let skyblue = named("skyblue", 0x87ceeb)
        static let slateblue = named("slateblue", 0x6a5acd)
        static let slategray = named("slategray", 0x708090)
        static let slategrey = named("slategrey", 0x708090)
        static let snow = named("snow", 0xfffafa)
        static let springgreen = named("springgreen", 0x00ff7f)
        static let steelblue = named("steelblue", 0x4682b4)
        static let tan = named("tan", 0xd2b48c)
        static let thistle = named("thistle", 0xd8bfd8)
        static let tomato = named("tomato", 0xff6347)
        static let turquoise = named("turquoise", 0x40e0d0)
        static let violet = named("violet", 0xee82ee)
        static let wheat = named("wheat", 0xf5deb3)
        static let whitesmoke = named("whitesmoke", 0xf5f5f5)
        static let yellowgreen = named("yellowgreen", 0x9acd32)
    }
}

#if canImport(CoreImage)

#if canImport(UIKit)
extension CIColor {
    var uiColor: UIColor {
        UIColor(ciColor: self)
    }
}
#endif

#if canImport(AppKit)
extension CIColor {
    var uiColor: NSColor {
        NSColor(ciColor: self)
    }
}
#endif

extension CIColor {
    /// Converts this color into a CSSColor
    var cssColor: CSSColor {
        CSSColor(nativeColor: self)
    }
}

extension CSSColor {
    /// Creates this `CSSColor` from a native CoreImage ``CIColor``.`
    public init(nativeColor: CIColor) {
        self.init(rgb: RGBColor(r: nativeColor.red, g: nativeColor.green, b: nativeColor.blue, a: nativeColor.alpha))
    }
}

public extension CSSColor {
    var nativeColor: CIColor {
        switch self.rep {
        case .name(let color): return color.color.nativeColor
        case .rgb(let color): return color.nativeColor
            //case .hsl(let color): return color.nativeColor
        }

        // TODO: system colors?
        // return CIColor.pink
        // return UIColor.systemPink / NSColor.systemPink
    }
}

public extension CSSColor.RGBColor {
    var nativeColor: CIColor {
        CIColor(red: self.r, green: self.g, blue: self.b, alpha: self.a ?? 1.0)
    }
}
#endif


#if canImport(XCTest)
import XCTest

@available(macOS 11, iOS 13, tvOS 13, *)
final class ThemePodTests: XCTestCase {

    func testColor() async throws {
        XCTAssertEqual(1, CSSColor.NamedColor(rawValue: "red")?.color.r)
        XCTAssertEqual(0.5019607843137255, CSSColor.NamedColor(rawValue: "green")?.color.g)
        XCTAssertEqual(1, CSSColor.NamedColor(rawValue: "blue")?.color.b)

        XCTAssertEqual("#112233FF", CSSColor.RGBColor(integerLiteral: 0x112233).description)


        let decoder = JSONDecoder()

        @discardableResult func parse(_ color: String, quote: Bool = true) throws -> CSSColor {
            do {
                let color = try decoder.decode(CSSColor.self, from: (quote ? ("\"" + color + "\"") : color).data(using: .utf8) ?? Data())
                return color
            } catch {
                XCTFail("\(error)")
                throw error
            }
        }

        XCTAssertEqual("\"blue\"", try parse("blue").description)
        XCTAssertEqual("#7FFFB2", try parse(#"{ "r": 0.5, "g": 1.0, "b": 0.7 }"#, quote: false).description)
        XCTAssertEqual("#7FFFB2BF", try parse(#"{ "r": 0.5, "g": 1.0, "b": 0.7, "a": 0.75 }"#, quote: false).description)

        // color samples from https://developer.mozilla.org/en-US/docs/Web/CSS/color_value

        try parse("transparent")
        try parse("black")
        try parse("silver")
        try parse("gray")
        try parse("white")
        try parse("aliceblue")
        try parse("forestgreen")
        try parse("gainsboro")
        try parse("ghostwhite")
        try parse("gold")
        try parse("goldenrod")
        try parse("greenyellow")
        try parse("grey")
        try parse("honeydew")
        try parse("hotpink")
        try parse("indianred")
        try parse("indigo")
        try parse("ivory")
        try parse("khaki")
        try parse("lavender")
        try parse("oldlace")
        try parse("olivedrab")
        try parse("orangered")
        try parse("orchid")
        try parse("turquoise")
        try parse("violet")
        try parse("wheat")
        try parse("whitesmoke")
        try parse("yellowgreen")


        /* These syntax variations all specify the same color: a fully opaque hot pink. */

        /* Hexadecimal syntax */
        XCTAssertEqual("#0F0009", try parse("#f09").description)
        XCTAssertEqual("#0F0009", try parse("#F09").description)
        XCTAssertEqual("#FF0099", try parse("#ff0099").description)
        XCTAssertEqual("#FF0099", try parse("#FF0099").description)

        //        /* Functional syntax */
        //        try parse ("rgb(255,0,153)")
        //        try parse ("rgb(255, 0, 153)")
        //        try parse ("rgb(255, 0, 153.0)")
        //        try parse ("rgb(100%,0%,60%)")
        //        try parse ("rgb(100%, 0%, 60%)")
        //        try parse ("rgb(100%, 0, 60%)") /* ERROR! Don't mix numbers and percentages. */
        //        try parse ("rgb(255 0 153)")

        /* Hexadecimal syntax with alpha value */
        XCTAssertEqual("#0F00090F", try parse("#f09f").description)
        XCTAssertEqual("#0F00090F", try parse("#F09F").description)
        XCTAssertEqual("#FF0099FF", try parse("#ff0099ff").description)
        XCTAssertEqual("#FF0099FF", try parse("#FF0099FF").description)

        //        /* Functional syntax with alpha value */
        //        try parse("rgb(255, 0, 153, 1)")
        //        try parse("rgb(255, 0, 153, 100%)")
        //
        //        /* Whitespace syntax */
        //        try parse("rgb(255 0 153 / 1)")
        //        try parse("rgb(255 0 153 / 100%)")
        //
        //        /* Functional syntax with floats value */
        //        try parse("rgb(255, 0, 153.6, 1)")
        //        try parse("rgb(2.55e2, 0e0, 1.53e2, 1e2%)")

        // RGB transparency variations

        /* Hexadecimal syntax */
        try parse("#3a30")                    /*   0% opaque green */
        try parse("#3A3F")                    /* full opaque green */
        try parse("#33aa3300")                /*   0% opaque green */
        try parse("#33AA3380")                /*  50% opaque green */

        // /* Functional syntax */
        // try parse("rgba(51, 170, 51, .1)")    /*  10% opaque green */
        // try parse("rgba(51, 170, 51, .4)")    /*  40% opaque green */
        // try parse("rgba(51, 170, 51, .7)")    /*  70% opaque green */
        // try parse("rgba(51, 170, 51,  1)")    /* full opaque green */
        //
        // /* Whitespace syntax */
        // try parse("rgba(51 170 51 / 0.4)")    /*  40% opaque green */
        // try parse("rgba(51 170 51 / 40%)")    /*  40% opaque green */
        //
        // /* Functional syntax with floats value */
        // try parse("rgba(51, 170, 51.6, 1)")
        // try parse("rgba(5.1e1, 1.7e2, 5.1e1, 1e2%)")

        // HSL syntax variations

        /* These examples all specify the same color: a lavender. */
        // try parse("hsl(270,60%,70%)")
        // try parse("hsl(270, 60%, 70%)")
        // try parse("hsl(270 60% 70%)")
        // try parse("hsl(270deg, 60%, 70%)")
        // try parse("hsl(4.71239rad, 60%, 70%)")
        // try parse("hsl(.75turn, 60%, 70%)")

        /* These examples all specify the same color: a lavender that is 15% opaque. */
        // try parse("hsl(270, 60%, 50%, .15)")
        // try parse("hsl(270, 60%, 50%, 15%)")
        // try parse("hsl(270 60% 50% / .15)")
        // try parse("hsl(270 60% 50% / 15%)")

        // HWB syntax variations

        /* These examples all specify varying shades of a lime green. */
        // hwb(90 10% 10%)
        // hwb(90 50% 10%)
        // hwb(90deg 10% 10%)
        // hwb(1.5708rad 60% 0%)
        // hwb(.25turn 0% 40%)
        //
        // /* Same lime green but with an alpha value */
        // hwb(90 10% 10% / 0.5)
        // hwb(90 10% 10% / 50%)

        // HSL transparency variations
        // try parse("hsla(240, 100%, 50%, .05)")     /*   5% opaque blue */
        // try parse("hsla(240, 100%, 50%, .4)")      /*  40% opaque blue */
        // try parse("hsla(240, 100%, 50%, .7)")      /*  70% opaque blue */
        // try parse("hsla(240, 100%, 50%, 1)")       /* full opaque blue */

        /* Whitespace syntax */
        // try parse("hsla(240 100% 50% / .05)")      /*   5% opaque blue */

        /* Percentage value for alpha */
        // try parse("hsla(240 100% 50% / 5%)")       /*   5% opaque blue */
    }

    @MainActor func testThemePod() async throws {
        let pod = ThemePod()
        //try await pod.jxc.eval("sleep()", priority: .high)
        XCTAssertEqual(3, try pod.jxc.eval("1+2").numberValue)

        try pod.jxc.global.set("c", object: CSSColor(rgb: CSSColor.RGBColor(r: 0.1, g: 0.2, b: 0.3)))
        XCTAssertEqual(#"{"r":0.1,"g":0.2,"b":0.3}"#, try pod.jxc.eval("JSON.stringify(c)").stringValue)

        try pod.jxc.global.set("c", object: CSSColor(name: CSSColor.NamedColor.aqua))
        XCTAssertEqual(#""aqua""#, try pod.jxc.eval("JSON.stringify(c)").stringValue)

        pod.backgroundColor = .init(.init(name: .aqua))
        XCTAssertEqual(#""aqua""#, try pod.jxc.eval("JSON.stringify(backgroundColor)").stringValue)

        // eventually we can do this

//        try pod.jxc.eval("""
//        var blue = 0.8;
//
//        navbarTint = { r: 0.5, g: 1.0, b: blue, a: 0.75 };
//        textColor = { r: 0.5, g: 1.0, b: blue, a: 0 }
//        backgroundColor = 'red';
//        """)

        #if canImport(UIKit)
        XCTAssertEqual(false, try pod.jxc.eval("navBarTintColor").isUndefined)
        XCTAssertEqual(true, try pod.jxc.eval("navBarTintColor").isNull)

        XCTAssertThrowsError(try pod.jxc.eval("navBarTintColor = { X: 1.0, g: 0.5, b: 0.8, a: 1.0 };"))

        XCTAssertThrowsError(try pod.jxc.eval("navBarTintColor = 'not a color';"))
        XCTAssertNoThrow(try pod.jxc.eval("navBarTintColor = 'pink';"))

        try pod.jxc.eval("navBarTintColor = { r: 1.0, g: 0.5, b: 0.8, a: 1.0 };")

        XCTAssertEqual(false, try pod.jxc.eval("navBarTintColor").isUndefined)
        XCTAssertEqual(false, try pod.jxc.eval("navBarTintColor").isNull)
        XCTAssertEqual(true, try pod.jxc.eval("navBarTintColor").isObject)
        XCTAssertEqual(#"{"r":1,"g":0.5,"b":0.8,"a":1}"#, try pod.jxc.eval("JSON.stringify(navBarTintColor)").stringValue)

        #endif
    }

    func testDidSet() throws {
        class TestObject : JackedObject {
            @Coded public var XXX: String = "" {
                didSet {
                    testDidSetCount += 1
                }
            }

            lazy var jxc = jack()
        }

        XCTAssertEqual(0, testDidSetCount)
        let ob = TestObject()
        ob.XXX = "XYZ";
        XCTAssertEqual(1, testDidSetCount)

        let cancellable = ob.$XXX.sink { val in
            testDidSetCount += 1 // fired twice
        }

        try ob.jxc.env.eval("XXX = 'abc';") // doesn't invoke didSet
        XCTAssertEqual(3, testDidSetCount) // TODO: didSet is not getting called from the JS side; need to fix this

        ob.XXX = "XYZ";
        XCTAssertEqual(5, testDidSetCount) // once from didSet, once from the cancellable

        let _ = cancellable
    }

}

var testDidSetCount = 0
#endif
