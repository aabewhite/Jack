import OpenCombineShim
import class Foundation.JSONEncoder

/// A type that can move between Swift and JavaScipt, either through direct reference or by serialization
public protocol Jumpable {
    /// Create a new instance from the given value
    init(value: JXValue, in context: JXContext) throws

    /// Converts this value into a JXContext
    mutating func getJX(from context: JXContext) -> JXValue
}


@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
@propertyWrapper
public struct Jumped<O: JackedObject, U : Jackable> : _JackableProperty {
    private let function: (_ context: JXContext, _ owner: AnyObject?) -> JXValue

    var exportedKey: String?

    subscript(in context: JXContext, owner: AnyObject?) -> JXValue {
        get {
            function(context, owner)
        }
        nonmutating set {
            context.currentError = JXValue(string: "cannot set a function from JS", in: context)
        }
    }

    // swiftlint:disable let_var_whitespace
    //@available(*, unavailable, message: "@Jumped is only available on properties of classes")
    public var wrappedValue: (O) -> (Any) -> U {
        get { fatalError("@Jumped is only available on properties of classes") }
        set { fatalError("@Jumped is only available on properties of classes") } // swiftlint:disable:this unused_setter_value
    }
    // swiftlint:enable let_var_whitespace
}


private extension JXContext {
    func arg(_ n: Int, in args: [JXValue]) -> JXValue {
        args.dropFirst(n).first ?? JXValue(nullIn: self)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    // 'init(wrappedValue:_:)' parameter type ('(O) -> (()) -> U') must be the same as its 'wrappedValue' property type ('<<error type>>') or an @autoclosure thereof
    public init(wrappedValue f0: @escaping (O) -> () -> U, _ key: String? = nil) {
        self.function = { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                var result = f0(owner as! O)()
                return result.getJX(from: ctx)
            }
        }
        self.exportedKey = key
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    public init<X1: Jumpable>(wrappedValue f1: @escaping (O) -> (X1) -> U, _ key: String? = nil) {
        self.function = { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                let x1 = try X1(value: ctx.arg(0, in: args), in: ctx)
                var result = f1(owner as! O)(x1)
                return result.getJX(from: ctx)
            }
        }
        self.exportedKey = key
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    public init<X1: Jumpable, X2: Jumpable>(wrappedValue f2: @escaping (O) -> (X1, X2) -> U, _ key: String? = nil) {
        self.function = { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                let x1 = try X1(value: ctx.arg(0, in: args), in: ctx)
                let x2 = try X2(value: ctx.arg(1, in: args), in: ctx)
                var result = f2(owner as! O)(x1, x2)
                return result.getJX(from: ctx)
            }
        }
        self.exportedKey = key
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    public init<X1: Jumpable, X2: Jumpable, X3: Jumpable>(wrappedValue f3: @escaping (O) -> (X1, X2, X3) -> U, _ key: String? = nil) {
        self.function = { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                JXValue(newFunctionIn: context) { ctx, this, args in
                    let x1 = try X1(value: ctx.arg(0, in: args), in: ctx)
                    let x2 = try X2(value: ctx.arg(1, in: args), in: ctx)
                    let x3 = try X3(value: ctx.arg(2, in: args), in: ctx)
                    var result = f3(owner as! O)(x1, x2, x3)
                    return result.getJX(from: ctx)
                }
            }
        }
        self.exportedKey = key
    }
}

