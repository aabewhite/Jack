import Jack
import Foundation
import OpenCombineShim

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

    private var observers: [AnyCancellable] = []

    deinit {
        // clear circular references
        observers.removeAll()
    }

    // MARK: UI-Kit-specific properties
    #if canImport(UIKit)
    static var navbar: UINavigationBar { UINavigationBar.appearance() }

    @Coded public var navigationBarTintColor: CSSColor? = (navbar.tintColor?.ciColor).flatMap(CSSColor.init(nativeColor:))

    func setupListeners() {
        self.$navigationBarTintColor.receive(on: RunLoop.main)
            .sink(receiveValue: { newValue in
                Self.navbar.tintColor = newValue?.nativeColor.uiColor
            })
            .store(in: &observers)
    }

    #else
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

    public struct RGBColor : Codable, Hashable, CustomStringConvertible {
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


        static let transparent = NamedColor(name: "transparent", color: RGBColor(r: 0, g: 0, b: 0, a: 0))
        static let black = NamedColor(name: "black", color: RGBColor(r: 0x00/255, g: 0x00/255, b: 0x00/255))
        static let silver = NamedColor(name: "silver", color: RGBColor(r: 0xc0/255, g: 0xc0/255, b: 0xc0/255))
        static let gray = NamedColor(name: "gray", color: RGBColor(r: 0x80/255, g: 0x80/255, b: 0x80/255))
        static let white = NamedColor(name: "white", color: RGBColor(r: 0xff/255, g: 0xff/255, b: 0xff/255))
        static let maroon = NamedColor(name: "maroon", color: RGBColor(r: 0x80/255, g: 0x00/255, b: 0x00/255))
        static let red = NamedColor(name: "red", color: RGBColor(r: 0xff/255, g: 0x00/255, b: 0x00/255))
        static let purple = NamedColor(name: "purple", color: RGBColor(r: 0x80/255, g: 0x00/255, b: 0x80/255))
        static let fuchsia = NamedColor(name: "fuchsia", color: RGBColor(r: 0xff/255, g: 0x00/255, b: 0xff/255))
        static let green = NamedColor(name: "green", color: RGBColor(r: 0x00/255, g: 0x80/255, b: 0x00/255))
        static let lime = NamedColor(name: "lime", color: RGBColor(r: 0x00/255, g: 0xff/255, b: 0x00/255))
        static let olive = NamedColor(name: "olive", color: RGBColor(r: 0x80/255, g: 0x80/255, b: 0x00/255))
        static let yellow = NamedColor(name: "yellow", color: RGBColor(r: 0xff/255, g: 0xff/255, b: 0x00/255))
        static let navy = NamedColor(name: "navy", color: RGBColor(r: 0x00/255, g: 0x00/255, b: 0x80/255))
        static let blue = NamedColor(name: "blue", color: RGBColor(r: 0x00/255, g: 0x00/255, b: 0xff/255))
        static let teal = NamedColor(name: "teal", color: RGBColor(r: 0x00/255, g: 0x80/255, b: 0x80/255))
        static let aqua = NamedColor(name: "aqua", color: RGBColor(r: 0x00/255, g: 0xff/255, b: 0xff/255))
        static let orange = NamedColor(name: "orange", color: RGBColor(r: 0xff/255, g: 0xa5/255, b: 0x00/255))
        static let aliceblue = NamedColor(name: "aliceblue", color: RGBColor(r: 0xf0/255, g: 0xf8/255, b: 0xff/255))
        static let antiquewhite = NamedColor(name: "antiquewhite", color: RGBColor(r: 0xfa/255, g: 0xeb/255, b: 0xd7/255))
        static let aquamarine = NamedColor(name: "aquamarine", color: RGBColor(r: 0x7f/255, g: 0xff/255, b: 0xd4/255))
        static let azure = NamedColor(name: "azure", color: RGBColor(r: 0xf0/255, g: 0xff/255, b: 0xff/255))
        static let beige = NamedColor(name: "beige", color: RGBColor(r: 0xf5/255, g: 0xf5/255, b: 0xdc/255))
        static let bisque = NamedColor(name: "bisque", color: RGBColor(r: 0xff/255, g: 0xe4/255, b: 0xc4/255))
        static let blanchedalmond = NamedColor(name: "blanchedalmond", color: RGBColor(r: 0xff/255, g: 0xeb/255, b: 0xcd/255))
        static let blueviolet = NamedColor(name: "blueviolet", color: RGBColor(r: 0x8a/255, g: 0x2b/255, b: 0xe2/255))
        static let brown = NamedColor(name: "brown", color: RGBColor(r: 0xa5/255, g: 0x2a/255, b: 0x2a/255))
        static let burlywood = NamedColor(name: "burlywood", color: RGBColor(r: 0xde/255, g: 0xb8/255, b: 0x87/255))
        static let cadetblue = NamedColor(name: "cadetblue", color: RGBColor(r: 0x5f/255, g: 0x9e/255, b: 0xa0/255))
        static let chartreuse = NamedColor(name: "chartreuse", color: RGBColor(r: 0x7f/255, g: 0xff/255, b: 0x00/255))
        static let chocolate = NamedColor(name: "chocolate", color: RGBColor(r: 0xd2/255, g: 0x69/255, b: 0x1e/255))
        static let coral = NamedColor(name: "coral", color: RGBColor(r: 0xff/255, g: 0x7f/255, b: 0x50/255))
        static let cornflowerblue = NamedColor(name: "cornflowerblue", color: RGBColor(r: 0x64/255, g: 0x95/255, b: 0xed/255))
        static let cornsilk = NamedColor(name: "cornsilk", color: RGBColor(r: 0xff/255, g: 0xf8/255, b: 0xdc/255))
        static let crimson = NamedColor(name: "crimson", color: RGBColor(r: 0xdc/255, g: 0x14/255, b: 0x3c/255))
        static let cyan = NamedColor(name: "cyan", color: RGBColor(r: 0x00/255, g: 0xff/255, b: 0xff/255))
        static let darkblue = NamedColor(name: "darkblue", color: RGBColor(r: 0x00/255, g: 0x00/255, b: 0x8b/255))
        static let darkcyan = NamedColor(name: "darkcyan", color: RGBColor(r: 0x00/255, g: 0x8b/255, b: 0x8b/255))
        static let darkgoldenrod = NamedColor(name: "darkgoldenrod", color: RGBColor(r: 0xb8/255, g: 0x86/255, b: 0x0b/255))
        static let darkgray = NamedColor(name: "darkgray", color: RGBColor(r: 0xa9/255, g: 0xa9/255, b: 0xa9/255))
        static let darkgreen = NamedColor(name: "darkgreen", color: RGBColor(r: 0x00/255, g: 0x64/255, b: 0x00/255))
        static let darkgrey = NamedColor(name: "darkgrey", color: RGBColor(r: 0xa9/255, g: 0xa9/255, b: 0xa9/255))
        static let darkkhaki = NamedColor(name: "darkkhaki", color: RGBColor(r: 0xbd/255, g: 0xb7/255, b: 0x6b/255))
        static let darkmagenta = NamedColor(name: "darkmagenta", color: RGBColor(r: 0x8b/255, g: 0x00/255, b: 0x8b/255))
        static let darkolivegreen = NamedColor(name: "darkolivegreen", color: RGBColor(r: 0x55/255, g: 0x6b/255, b: 0x2f/255))
        static let darkorange = NamedColor(name: "darkorange", color: RGBColor(r: 0xff/255, g: 0x8c/255, b: 0x00/255))
        static let darkorchid = NamedColor(name: "darkorchid", color: RGBColor(r: 0x99/255, g: 0x32/255, b: 0xcc/255))
        static let darkred = NamedColor(name: "darkred", color: RGBColor(r: 0x8b/255, g: 0x00/255, b: 0x00/255))
        static let darksalmon = NamedColor(name: "darksalmon", color: RGBColor(r: 0xe9/255, g: 0x96/255, b: 0x7a/255))
        static let darkseagreen = NamedColor(name: "darkseagreen", color: RGBColor(r: 0x8f/255, g: 0xbc/255, b: 0x8f/255))
        static let darkslateblue = NamedColor(name: "darkslateblue", color: RGBColor(r: 0x48/255, g: 0x3d/255, b: 0x8b/255))
        static let darkslategray = NamedColor(name: "darkslategray", color: RGBColor(r: 0x2f/255, g: 0x4f/255, b: 0x4f/255))
        static let darkslategrey = NamedColor(name: "darkslategrey", color: RGBColor(r: 0x2f/255, g: 0x4f/255, b: 0x4f/255))
        static let darkturquoise = NamedColor(name: "darkturquoise", color: RGBColor(r: 0x00/255, g: 0xce/255, b: 0xd1/255))
        static let darkviolet = NamedColor(name: "darkviolet", color: RGBColor(r: 0x94/255, g: 0x00/255, b: 0xd3/255))
        static let deeppink = NamedColor(name: "deeppink", color: RGBColor(r: 0xff/255, g: 0x14/255, b: 0x93/255))
        static let deepskyblue = NamedColor(name: "deepskyblue", color: RGBColor(r: 0x00/255, g: 0xbf/255, b: 0xff/255))
        static let dimgray = NamedColor(name: "dimgray", color: RGBColor(r: 0x69/255, g: 0x69/255, b: 0x69/255))
        static let dimgrey = NamedColor(name: "dimgrey", color: RGBColor(r: 0x69/255, g: 0x69/255, b: 0x69/255))
        static let dodgerblue = NamedColor(name: "dodgerblue", color: RGBColor(r: 0x1e/255, g: 0x90/255, b: 0xff/255))
        static let firebrick = NamedColor(name: "firebrick", color: RGBColor(r: 0xb2/255, g: 0x22/255, b: 0x22/255))
        static let floralwhite = NamedColor(name: "floralwhite", color: RGBColor(r: 0xff/255, g: 0xfa/255, b: 0xf0/255))
        static let forestgreen = NamedColor(name: "forestgreen", color: RGBColor(r: 0x22/255, g: 0x8b/255, b: 0x22/255))
        static let gainsboro = NamedColor(name: "gainsboro", color: RGBColor(r: 0xdc/255, g: 0xdc/255, b: 0xdc/255))
        static let ghostwhite = NamedColor(name: "ghostwhite", color: RGBColor(r: 0xf8/255, g: 0xf8/255, b: 0xff/255))
        static let gold = NamedColor(name: "gold", color: RGBColor(r: 0xff/255, g: 0xd7/255, b: 0x00/255))
        static let goldenrod = NamedColor(name: "goldenrod", color: RGBColor(r: 0xda/255, g: 0xa5/255, b: 0x20/255))
        static let greenyellow = NamedColor(name: "greenyellow", color: RGBColor(r: 0xad/255, g: 0xff/255, b: 0x2f/255))
        static let grey = NamedColor(name: "grey", color: RGBColor(r: 0x80/255, g: 0x80/255, b: 0x80/255))
        static let honeydew = NamedColor(name: "honeydew", color: RGBColor(r: 0xf0/255, g: 0xff/255, b: 0xf0/255))
        static let hotpink = NamedColor(name: "hotpink", color: RGBColor(r: 0xff/255, g: 0x69/255, b: 0xb4/255))
        static let indianred = NamedColor(name: "indianred", color: RGBColor(r: 0xcd/255, g: 0x5c/255, b: 0x5c/255))
        static let indigo = NamedColor(name: "indigo", color: RGBColor(r: 0x4b/255, g: 0x00/255, b: 0x82/255))
        static let ivory = NamedColor(name: "ivory", color: RGBColor(r: 0xff/255, g: 0xff/255, b: 0xf0/255))
        static let khaki = NamedColor(name: "khaki", color: RGBColor(r: 0xf0/255, g: 0xe6/255, b: 0x8c/255))
        static let lavender = NamedColor(name: "lavender", color: RGBColor(r: 0xe6/255, g: 0xe6/255, b: 0xfa/255))
        static let lavenderblush = NamedColor(name: "lavenderblush", color: RGBColor(r: 0xff/255, g: 0xf0/255, b: 0xf5/255))
        static let lawngreen = NamedColor(name: "lawngreen", color: RGBColor(r: 0x7c/255, g: 0xfc/255, b: 0x00/255))
        static let lemonchiffon = NamedColor(name: "lemonchiffon", color: RGBColor(r: 0xff/255, g: 0xfa/255, b: 0xcd/255))
        static let lightblue = NamedColor(name: "lightblue", color: RGBColor(r: 0xad/255, g: 0xd8/255, b: 0xe6/255))
        static let lightcoral = NamedColor(name: "lightcoral", color: RGBColor(r: 0xf0/255, g: 0x80/255, b: 0x80/255))
        static let lightcyan = NamedColor(name: "lightcyan", color: RGBColor(r: 0xe0/255, g: 0xff/255, b: 0xff/255))
        static let lightgoldenrodyellow = NamedColor(name: "lightgoldenrodyellow", color: RGBColor(r: 0xfa/255, g: 0xfa/255, b: 0xd2/255))
        static let lightgray = NamedColor(name: "lightgray", color: RGBColor(r: 0xd3/255, g: 0xd3/255, b: 0xd3/255))
        static let lightgreen = NamedColor(name: "lightgreen", color: RGBColor(r: 0x90/255, g: 0xee/255, b: 0x90/255))
        static let lightgrey = NamedColor(name: "lightgrey", color: RGBColor(r: 0xd3/255, g: 0xd3/255, b: 0xd3/255))
        static let lightpink = NamedColor(name: "lightpink", color: RGBColor(r: 0xff/255, g: 0xb6/255, b: 0xc1/255))
        static let lightsalmon = NamedColor(name: "lightsalmon", color: RGBColor(r: 0xff/255, g: 0xa0/255, b: 0x7a/255))
        static let lightseagreen = NamedColor(name: "lightseagreen", color: RGBColor(r: 0x20/255, g: 0xb2/255, b: 0xaa/255))
        static let lightskyblue = NamedColor(name: "lightskyblue", color: RGBColor(r: 0x87/255, g: 0xce/255, b: 0xfa/255))
        static let lightslategray = NamedColor(name: "lightslategray", color: RGBColor(r: 0x77/255, g: 0x88/255, b: 0x99/255))
        static let lightslategrey = NamedColor(name: "lightslategrey", color: RGBColor(r: 0x77/255, g: 0x88/255, b: 0x99/255))
        static let lightsteelblue = NamedColor(name: "lightsteelblue", color: RGBColor(r: 0xb0/255, g: 0xc4/255, b: 0xde/255))
        static let lightyellow = NamedColor(name: "lightyellow", color: RGBColor(r: 0xff/255, g: 0xff/255, b: 0xe0/255))
        static let limegreen = NamedColor(name: "limegreen", color: RGBColor(r: 0x32/255, g: 0xcd/255, b: 0x32/255))
        static let linen = NamedColor(name: "linen", color: RGBColor(r: 0xfa/255, g: 0xf0/255, b: 0xe6/255))
        static let magenta = NamedColor(name: "magenta", color: RGBColor(r: 0xff/255, g: 0x00/255, b: 0xff/255))
        static let mediumaquamarine = NamedColor(name: "mediumaquamarine", color: RGBColor(r: 0x66/255, g: 0xcd/255, b: 0xaa/255))
        static let mediumblue = NamedColor(name: "mediumblue", color: RGBColor(r: 0x00/255, g: 0x00/255, b: 0xcd/255))
        static let mediumorchid = NamedColor(name: "mediumorchid", color: RGBColor(r: 0xba/255, g: 0x55/255, b: 0xd3/255))
        static let mediumpurple = NamedColor(name: "mediumpurple", color: RGBColor(r: 0x93/255, g: 0x70/255, b: 0xdb/255))
        static let mediumseagreen = NamedColor(name: "mediumseagreen", color: RGBColor(r: 0x3c/255, g: 0xb3/255, b: 0x71/255))
        static let mediumslateblue = NamedColor(name: "mediumslateblue", color: RGBColor(r: 0x7b/255, g: 0x68/255, b: 0xee/255))
        static let mediumspringgreen = NamedColor(name: "mediumspringgreen", color: RGBColor(r: 0x00/255, g: 0xfa/255, b: 0x9a/255))
        static let mediumturquoise = NamedColor(name: "mediumturquoise", color: RGBColor(r: 0x48/255, g: 0xd1/255, b: 0xcc/255))
        static let mediumvioletred = NamedColor(name: "mediumvioletred", color: RGBColor(r: 0xc7/255, g: 0x15/255, b: 0x85/255))
        static let midnightblue = NamedColor(name: "midnightblue", color: RGBColor(r: 0x19/255, g: 0x19/255, b: 0x70/255))
        static let mintcream = NamedColor(name: "mintcream", color: RGBColor(r: 0xf5/255, g: 0xff/255, b: 0xfa/255))
        static let mistyrose = NamedColor(name: "mistyrose", color: RGBColor(r: 0xff/255, g: 0xe4/255, b: 0xe1/255))
        static let moccasin = NamedColor(name: "moccasin", color: RGBColor(r: 0xff/255, g: 0xe4/255, b: 0xb5/255))
        static let navajowhite = NamedColor(name: "navajowhite", color: RGBColor(r: 0xff/255, g: 0xde/255, b: 0xad/255))
        static let oldlace = NamedColor(name: "oldlace", color: RGBColor(r: 0xfd/255, g: 0xf5/255, b: 0xe6/255))
        static let olivedrab = NamedColor(name: "olivedrab", color: RGBColor(r: 0x6b/255, g: 0x8e/255, b: 0x23/255))
        static let orangered = NamedColor(name: "orangered", color: RGBColor(r: 0xff/255, g: 0x45/255, b: 0x00/255))
        static let orchid = NamedColor(name: "orchid", color: RGBColor(r: 0xda/255, g: 0x70/255, b: 0xd6/255))
        static let palegoldenrod = NamedColor(name: "palegoldenrod", color: RGBColor(r: 0xee/255, g: 0xe8/255, b: 0xaa/255))
        static let palegreen = NamedColor(name: "palegreen", color: RGBColor(r: 0x98/255, g: 0xfb/255, b: 0x98/255))
        static let paleturquoise = NamedColor(name: "paleturquoise", color: RGBColor(r: 0xaf/255, g: 0xee/255, b: 0xee/255))
        static let palevioletred = NamedColor(name: "palevioletred", color: RGBColor(r: 0xdb/255, g: 0x70/255, b: 0x93/255))
        static let papayawhip = NamedColor(name: "papayawhip", color: RGBColor(r: 0xff/255, g: 0xef/255, b: 0xd5/255))
        static let peachpuff = NamedColor(name: "peachpuff", color: RGBColor(r: 0xff/255, g: 0xda/255, b: 0xb9/255))
        static let peru = NamedColor(name: "peru", color: RGBColor(r: 0xcd/255, g: 0x85/255, b: 0x3f/255))
        static let pink = NamedColor(name: "pink", color: RGBColor(r: 0xff/255, g: 0xc0/255, b: 0xcb/255))
        static let plum = NamedColor(name: "plum", color: RGBColor(r: 0xdd/255, g: 0xa0/255, b: 0xdd/255))
        static let powderblue = NamedColor(name: "powderblue", color: RGBColor(r: 0xb0/255, g: 0xe0/255, b: 0xe6/255))
        static let rosybrown = NamedColor(name: "rosybrown", color: RGBColor(r: 0xbc/255, g: 0x8f/255, b: 0x8f/255))
        static let royalblue = NamedColor(name: "royalblue", color: RGBColor(r: 0x41/255, g: 0x69/255, b: 0xe1/255))
        static let saddlebrown = NamedColor(name: "saddlebrown", color: RGBColor(r: 0x8b/255, g: 0x45/255, b: 0x13/255))
        static let salmon = NamedColor(name: "salmon", color: RGBColor(r: 0xfa/255, g: 0x80/255, b: 0x72/255))
        static let sandybrown = NamedColor(name: "sandybrown", color: RGBColor(r: 0xf4/255, g: 0xa4/255, b: 0x60/255))
        static let seagreen = NamedColor(name: "seagreen", color: RGBColor(r: 0x2e/255, g: 0x8b/255, b: 0x57/255))
        static let seashell = NamedColor(name: "seashell", color: RGBColor(r: 0xff/255, g: 0xf5/255, b: 0xee/255))
        static let sienna = NamedColor(name: "sienna", color: RGBColor(r: 0xa0/255, g: 0x52/255, b: 0x2d/255))
        static let skyblue = NamedColor(name: "skyblue", color: RGBColor(r: 0x87/255, g: 0xce/255, b: 0xeb/255))
        static let slateblue = NamedColor(name: "slateblue", color: RGBColor(r: 0x6a/255, g: 0x5a/255, b: 0xcd/255))
        static let slategray = NamedColor(name: "slategray", color: RGBColor(r: 0x70/255, g: 0x80/255, b: 0x90/255))
        static let slategrey = NamedColor(name: "slategrey", color: RGBColor(r: 0x70/255, g: 0x80/255, b: 0x90/255))
        static let snow = NamedColor(name: "snow", color: RGBColor(r: 0xff/255, g: 0xfa/255, b: 0xfa/255))
        static let springgreen = NamedColor(name: "springgreen", color: RGBColor(r: 0x00/255, g: 0xff/255, b: 0x7f/255))
        static let steelblue = NamedColor(name: "steelblue", color: RGBColor(r: 0x46/255, g: 0x82/255, b: 0xb4/255))
        static let tan = NamedColor(name: "tan", color: RGBColor(r: 0xd2/255, g: 0xb4/255, b: 0x8c/255))
        static let thistle = NamedColor(name: "thistle", color: RGBColor(r: 0xd8/255, g: 0xbf/255, b: 0xd8/255))
        static let tomato = NamedColor(name: "tomato", color: RGBColor(r: 0xff/255, g: 0x63/255, b: 0x47/255))
        static let turquoise = NamedColor(name: "turquoise", color: RGBColor(r: 0x40/255, g: 0xe0/255, b: 0xd0/255))
        static let violet = NamedColor(name: "violet", color: RGBColor(r: 0xee/255, g: 0x82/255, b: 0xee/255))
        static let wheat = NamedColor(name: "wheat", color: RGBColor(r: 0xf5/255, g: 0xde/255, b: 0xb3/255))
        static let whitesmoke = NamedColor(name: "whitesmoke", color: RGBColor(r: 0xf5/255, g: 0xf5/255, b: 0xf5/255))
        static let yellowgreen = NamedColor(name: "yellowgreen", color: RGBColor(r: 0x9a/255, g: 0xcd/255, b: 0x32/255))
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
        //        //        try parse ("rgb(100%, 0, 60%)") /* ERROR! Don't mix numbers and percentages. */
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
        XCTAssertEqual(false, try pod.jxc.eval("navigationBarTintColor").isUndefined)
        XCTAssertEqual(true, try pod.jxc.eval("navigationBarTintColor").isNull)

        // FIXME: not invoking didSet for some reason
        try pod.jxc.eval("navigationBarTintColor = { r: 1.0, g: 0.5, b: 0.8, a: 1.0 };")

        XCTAssertEqual(false, try pod.jxc.eval("navigationBarTintColor").isUndefined)
        XCTAssertEqual(false, try pod.jxc.eval("navigationBarTintColor").isNull)
        XCTAssertEqual(true, try pod.jxc.eval("navigationBarTintColor").isObject)
        XCTAssertEqual(#"{"r":1,"g":0.5,"b":0.8,"a":1}"#, try pod.jxc.eval("JSON.stringify(navigationBarTintColor)").stringValue)

        //try pod.jxc.eval("setNavigationBarTintColor('#FFAA0055')")
//        XCTAssertEqual("", UINavigationBar.appearance().tintColor?.ciColor.description)
        // XCTAssertThrowsError(try pod.jxc.eval("setNavigationBarTintColor({ BADPROP: 0.5, g: 1.0, b: 0.7, a: 0.75 })"), "color struct with bad property should not parse")

        // try pod.jxc.eval("setNavigationBarTintColor({ r: 0.5, g: 1.0, b: 0.7, a: 0.75 })")
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
        try ob.jxc.env.eval("XXX = 'abc';") // doesn't invoke didSet
        //XCTAssertEqual(2, testDidSetCount) // TODO: didSet is not getting called from the JS side; need to fix this
        ob.XXX = "XYZ";
        //XCTAssertEqual(3, testDidSetCount)

    }

}

var testDidSetCount = 0
#endif
