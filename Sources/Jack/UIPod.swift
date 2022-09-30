import Jack

// MARK: UIPod

#if canImport(SwiftUI)
import SwiftUI

/// A JackPod that provides support for constructing SwiftUI view hierarchies from JavaScript.
open class UIPod : JackPod {
    public init() {
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    @Jumped("Divider") var _divider = divider
    func divider() -> ViewProxy {
        class DividerProxy : ViewProxy {
            override var anyView: AnyView { AnyView(body) }
            public var body: some View { Divider() }
        }
        return DividerProxy()
    }

    @Jumped("Spacer") var _spacer = spacer
    func spacer() -> ViewProxy {
        class SpacerProxy : ViewProxy {
            override var anyView: AnyView { AnyView(body) }
            public var body: some View { Spacer() }
        }
        return SpacerProxy()
    }

    @Jumped("Group") var _group = group
    func group(views: [ViewProxy]?) -> ViewProxy {
        ContainerBuilder(views) { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10 in
            Group { v1; v2; v3; v4; v5; v6; v7; v8; v9; v10 }
        }
    }

    @Jumped("List") var _list = list
    func list(views: [ViewProxy]?) -> ViewProxy {
        ContainerBuilder(views) { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10 in
            List { v1; v2; v3; v4; v5; v6; v7; v8; v9; v10 }
        }
    }

    @Jumped("Form") var _form = form
    func form(views: [ViewProxy]?) -> ViewProxy {
        ContainerBuilder(views) { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10 in
            Form { v1; v2; v3; v4; v5; v6; v7; v8; v9; v10 }
        }
    }

    @Jumped("VStack") var _vstack = vstack
    func vstack(views: [ViewProxy]?) -> ViewProxy {
        ContainerBuilder(views) { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10 in
            VStack { v1; v2; v3; v4; v5; v6; v7; v8; v9; v10 }
        }
    }

    @Jumped("HStack") var _hstack = hstack
    func hstack(views: [ViewProxy]?) -> ViewProxy {
        ContainerBuilder(views) { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10 in
            HStack { v1; v2; v3; v4; v5; v6; v7; v8; v9; v10 }
        }
    }

    @Jumped("LazyVStack") var _lazyvstack = lazyvstack
    func lazyvstack(views: [ViewProxy]?) -> ViewProxy {
        ContainerBuilder(views) { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10 in
            LazyVStack { v1; v2; v3; v4; v5; v6; v7; v8; v9; v10 }
        }
    }

    @Jumped("LazyHStack") var _lazyhstack = lazyhstack
    func lazyhstack(views: [ViewProxy]?) -> ViewProxy {
        ContainerBuilder(views) { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10 in
            LazyHStack { v1; v2; v3; v4; v5; v6; v7; v8; v9; v10 }
        }
    }

    @Jumped("Text") var _text = text
    func text(value: String) -> ViewProxy {
        let proxy = TextProxy()
        proxy.value = value
        return proxy
    }

    @Jumped("Button") var _button = button
    func button(label: ViewProxy, action: JXValue) throws -> ViewProxy {
        if !action.isFunction {
            throw JXError(env: action.env, value: action.env.string("Second argument to Button constructor must be the callback function"))
        }

        class ButtonProxy : ViewProxy {
            let label: ViewProxy
            let action: JXValue

            init(label: ViewProxy, action: JXValue) {
                self.label = label
                self.action = action
            }

            override var childViews: [JackedView]? { [label] }

            override var anyView: AnyView {
                AnyView(body)
            }

            var body: some View {
                Button(action: {
                    do {
                        try self.action.call()
                    } catch {
                        print("### WIP: error executing action: \(error)")
                    }
                }, label: {
                    label.anyView
                })
            }
        }

        return ButtonProxy(label: label, action: action)
    }

    private func fallback<T>(_ block: () throws -> T, default defaultValue: T) -> T {
        do {
            return try block()
        } catch {
            print(wip("FIXME: log fallback error: \(error)"))
            return defaultValue
        }
    }

    /// Create a binding from the given set/get functions, or else the symbol name if it is the initiual element.
    /// - Parameters:
    ///   - getFunction: A JXValue representing either a symbol or a getter function
    ///   - setFunction: A JXValue representing either undefined or a setter function
    /// - Returns: the binding to a JXValue
    private func createBinding(get getFunction: JXValue, set setFunction: JXValue) throws -> Binding<JXValue> {
        // if the first argument is a Symbol, we use that as the key for the get/set, which allows a simple and fluent binding syntax
        if getFunction.isSymbol {
            let symbol = getFunction

            return Binding(get: {
                self.fallback({ try symbol.env.global[symbol: symbol] }, default: symbol.env.undefined())
            }, set: { newValue in
                self.fallback({ try symbol.env.global.setProperty(symbol: symbol, newValue) }, default: ())
            })
        }

        // non-symbol argumnt: assume args are getter and setter functions

        if !getFunction.isFunction {
            throw JXError(env: getFunction.env, value: getFunction.env.string("Second Slider argument must be the value getter function"))
        }

        if !setFunction.isFunction {
            throw JXError(env: setFunction.env, value: setFunction.env.string("Third Slider argument must be the value setter function"))
        }

        return Binding(get: {
            self.fallback({ try getFunction.call() }, default: getFunction.env.undefined())
        }, set: { newValue in
            self.fallback({ try setFunction.call(withArguments: [newValue]) }, default: ())
        })
    }

    @Jumped("Slider") var _slider = slider
    func slider(label: ViewProxy, get getFunction: JXValue, set setFunction: JXValue) throws -> ViewProxy {
        let binding = try createBinding(get: getFunction, set: setFunction)
        let numericBinding = Binding<Double> {
            self.fallback({ try binding.wrappedValue.numberValue }, default: .nan)
        } set: { newValue in
            binding.wrappedValue = getFunction.env.number(newValue)
        }

        class SliderProxy : ViewProxy {
            let label: ViewProxy
            let binding: Binding<Double>

            init(label: ViewProxy, binding: Binding<Double>) {
                self.label = label
                self.binding = binding
            }

            override var childViews: [JackedView]? { [label] }

            override var anyView: AnyView {
                AnyView(body)
            }

            var body: some View {
                #if os(tvOS)
                Text("Slider unavailable in tvOS", bundle: .module, comment: "error message string")
                #else
                Slider(value: binding, label: {
                    label.anyView
                })
                #endif
            }
        }

        return SliderProxy(label: label, binding: numericBinding)
    }
}

struct SamplePodView : View {
    @StateObject var pod = SamplePodViewModel()

    @MainActor class SamplePodViewModel : JackedObject {
        @Jacked var message = "Hello"
        @Jacked var counter = 0

        lazy var jxc = jack().env
        // lazy var jxc = jack(with: [ "ui": UIPod(), "console": ConsolePod() ]).env // TODO
    }

    let script = """
        VStack({ alignment: 'leading', spacing: 5 }, [
            Text(message).fontStyle('title').fontSize(12.2),
            Group([
                Divider(),
                HStack([Spacer(), Divider()])
            ]),
            Button(Text(`Increment Counter: ${counter}`), () => { counter += 1 }),
            Slider(bind: { get: () => { counter }, set: (v) => { counter = v } }, min: 0, max: 100),
            Slider(bind: 'counter', min: 0, max: 100),
        ])
        """

    var body : some View {
        switch Result(catching: { try pod.jxc.eval(script).convey(to: ViewProxy.self) }) {
        case .success(let proxy): proxy.anyView
        case .failure(let error): Text(wip("ERROR: \(error.localizedDescription)"))
        }
    }
}


public protocol JackedView : JackedReference {
    var anyView: AnyView { get }
    var childViews: [JackedView]? { get }
}

open class ViewProxy : JackedReference, JackedView {
    @Jacked var viewConfig: ViewConfig = ViewConfig()

    open var anyView: AnyView {
        AnyView(EmptyView())
    }

    open var childViews: [JackedView]? {
        nil
    }

    @Jumped("opacity") var _opacity = opacity
    func opacity(_ value: Double?) -> Self {
        assigning(\.viewConfig.opacity, to: value)
    }

    public struct ViewConfig : Codable, Jackable {
        /// The opacity of the view, from 0.0–1.0
        public var opacity: Double?
    }
}

/// A container type that can hold a list of up to 10 children
class ContainerBuilder<Body : View> : ViewProxy {
    let children: [JackedView]?
    let builder: (AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?) -> Body

    init(_ children: [ViewProxy]?, builder: @escaping (AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?, AnyView?) -> Body) {
        self.children = children
        self.builder = builder
    }

    override var childViews: [JackedView]? {
        children
    }

    /// Returns the Nth view in the child list, or else nil
    func sub(_ n: Int) -> AnyView? {
        self.children?.dropFirst(n).first?.anyView
    }

    var body: some View {
        return builder(sub(0), sub(1), sub(2), sub(3), sub(4), sub(5), sub(6), sub(7), sub(8), sub(9))
    }

    override var anyView: AnyView {
        AnyView(body)
    }
}

extension JackedView {
    /// Builder utility for assigning a value to the given path and returning `Self` back.
    func assigning<T>(_ path: ReferenceWritableKeyPath<Self, T>, to newValue: T) -> Self {
        self[keyPath: path] = newValue
        return self
    }
}

open class TextProxy : ViewProxy {
    @Jacked public var value: String?
    @Jacked public var config: FontConfig = FontConfig()

    override open var anyView: AnyView {
        AnyView(body)
    }

    public var body: some View {
        Text((try? AttributedString(markdown: value ?? "")) ?? .init())
            .font(config.style.flatMap({ .system($0.uiTextStyle) }))
            .fontWeight(config.weight?.uiFontWeight)
    }

//    deinit {
//        print(wip("TextProxy deinit"))
//    }

    @Jumped("fontSize") var _fontSize = fontSize
    func fontSize(size: Double) -> TextProxy {
        assigning(\.config.size, to: size)
    }

    @Jumped("fontStyle") var _fontStyle = fontStyle
    func fontStyle(style: FontProxy.TextStyle) -> TextProxy {
        assigning(\.config.style, to: style)
    }

    @Jumped("fontWeight") var _fontWeight = fontWeight
    func fontWeight(weight: FontProxy.Weight) -> TextProxy {
        assigning(\.config.weight, to: weight)
    }

    public struct FontConfig : Codable, Jackable {
        public var size: Double?
        public var weight: FontProxy.Weight?
        public var style: FontProxy.TextStyle?
    }
}

public enum FontProxy {

    /// Analogue to `SwiftUI.Font.Weight` as a string enum so automatic Jack bridging magic can happen
    public enum Weight : String, Codable, JXConvertible {
        case ultraLight
        case thin
        case light
        case regular
        case medium
        case semibold
        case bold
        case heavy
        case black

        var uiFontWeight: SwiftUI.Font.Weight {
            switch self {
            case .ultraLight: return .ultraLight
            case .thin: return .thin
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            case .black: return .black
            }
        }

        // Both Codable and RawRepresentable implement JXConvertible, so we need to manually dis-ambiguate
        public static func makeJX(from value: JXValue) throws -> Self { try makeJXRaw(from: value) }
        public func getJX(from context: JXContext) throws -> JXValue { try getJXRaw(from: context) }
    }

    /// Analogue to `SwiftUI.Font.TextStyle` as a string enum so automatic Jack bridging magic can happen
    public enum TextStyle : String, Codable, JXConvertible {
        case largeTitle
        case title
        case title2
        case title3
        case headline
        case subheadline
        case body
        case callout
        case footnote
        case caption
        case caption2

        var uiTextStyle: SwiftUI.Font.TextStyle {
            switch self {
            case .largeTitle: return .largeTitle
            case .title: return .title
            case .title2: return .title2
            case .title3: return .title3
            case .headline: return .headline
            case .subheadline: return .subheadline
            case .body: return .body
            case .callout: return .callout
            case .footnote: return .footnote
            case .caption: return .caption
            case .caption2: return .caption2
            }
        }

        // Both Codable and RawRepresentable implement JXConvertible, so we need to manually dis-ambiguate
        public static func makeJX(from value: JXValue) throws -> Self { try makeJXRaw(from: value) }
        public func getJX(from context: JXContext) throws -> JXValue { try getJXRaw(from: context) }
    }
}

#endif

