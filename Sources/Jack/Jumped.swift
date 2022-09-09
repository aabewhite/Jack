import OpenCombineShim

/// A type that can move between Swift and JavaScipt, either through direct reference or by serialization
public protocol Jumpable {
    /// Converts this value into a JXContext
    static func makeJX(from value: JXValue, in context: JXContext) throws -> Self

    /// Converts this value into a JXContext
    func getJX(from context: JXContext) throws -> JXValue
}

extension JXValue : Jumpable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> JXValue {
        value
    }

    /// Converts this value into a JXContext
    public func getJX(from context: JXContext) -> JXValue {
        self
    }
}

/// A type that publishes a property with an exporte function to an associated ``JXKit\\JXContext``.
///
/// Example:
///
///     class JumpedObj : JackedObject {
///         @Jumped("now") private var _now = now // exported as function
///         func now() -> Date { Date(timeIntervalSince1970: 1_234) }
///
///         lazy var jsc = jack()
///     }
///
///     let obj = JumpedObjEnhancedObj()
///
///     try obj.jsc.eval("typeof now").stringValue == "function"
///     try obj.jsc.eval("typeof now()").stringValue == "object"
///     try obj.jsc.eval("now()").numberValue ==  1_234_000
///
/// ### See Also
///
/// - `Publisher.assign(to:)`
@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
@propertyWrapper
public struct Jumped<O: JackedObject, U : Jackable> : _JackableProperty {
    typealias JumpFunc = (_ context: JXContext, _ owner: AnyObject?) -> JXValue

    private let function: JumpFunc

    var exportedKey: String?

    subscript(in context: JXContext, owner: AnyObject?) -> JXValue {
        get {
            function(context, owner)
        }
        nonmutating set {
            context.currentError = JXValue(newErrorFromMessage: "cannot set a function from JS", in: context)
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
    func casting<O>(_ value: AnyObject?) throws -> O {
        if let value = value as? O {
            return value
        }
        throw JackError.jumpContextInvalid(.init(context: self))
    }

    func jarg<J: Jumpable>(_ index: Int, _ args: [JXValue]) throws -> J {
        try J.makeJX(from: args.dropFirst(index).first ?? JXValue(nullIn: self), in: self)
    }
}


@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    fileprivate static func createAsyncFunction<J: Jumpable>(priority: TaskPriority?, block: @escaping (JXContext, AnyObject?, [JXValue]) async throws -> J) -> JumpFunc {
        { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                let promise = try JXValue.createPromise(in: ctx)

                Task.detached(priority: priority) {
                    do {
                        let result = try await block(ctx, owner, args).getJX(from: ctx)
                        promise.resolveFunction.call(withArguments: [result], this: this)
                    } catch {
                        promise.rejectFunction.call(withArguments: [JXValue(newErrorFromMessage: "\(error)", in: ctx)], this: this)
                    }
                }

                return JXValue(env: ctx, value: promise.promise)
            }
        }
    }
}

/// Single-argument function wrappers
@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    public init(wrappedValue f0: @escaping (O) -> () throws -> U, _ key: String? = nil) {
        self.function = { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                try f0(ctx.casting(owner))().getJX(from: ctx)
            }
        }
        self.exportedKey = key
    }

    public init(wrappedValue af0: @escaping (O) -> () async throws -> U, _ key: String? = nil, priority: TaskPriority? = nil) {
        self.function = Self.createAsyncFunction(priority: priority) { ctx, owner, args in
            try await af0(ctx.casting(owner))()
        }
        self.exportedKey = key
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    public init<X1: Jumpable>(wrappedValue f1: @escaping (O) -> (X1) throws -> U, _ key: String? = nil) {
        self.function = { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                try f1(ctx.casting(owner))(ctx.jarg(0, args)).getJX(from: ctx)
            }
        }
        self.exportedKey = key
    }

    public init<X1: Jumpable>(wrappedValue af1: @escaping (O) -> (X1) async throws -> U, _ key: String? = nil, priority: TaskPriority? = nil) {
        self.function = Self.createAsyncFunction(priority: priority) { ctx, owner, args in
            try await af1(ctx.casting(owner))(ctx.jarg(0, args))
        }
        self.exportedKey = key
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    public init<X1: Jumpable, X2: Jumpable>(wrappedValue f2: @escaping (O) -> (X1, X2) throws -> U, _ key: String? = nil) {
        self.function = { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                try f2(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args)).getJX(from: ctx)
            }
        }
        self.exportedKey = key
    }

    public init<X1: Jumpable, X2: Jumpable>(wrappedValue af2: @escaping (O) -> (X1, X2) async throws -> U, _ key: String? = nil, priority: TaskPriority? = nil) {
        self.function = Self.createAsyncFunction(priority: priority) { ctx, owner, args in
            try await af2(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args))
        }
        self.exportedKey = key
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    public init<X1: Jumpable, X2: Jumpable, X3: Jumpable>(wrappedValue f3: @escaping (O) -> (X1, X2, X3) throws -> U, _ key: String? = nil) {
        self.function = { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                try f3(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args)).getJX(from: ctx)
            }
        }
        self.exportedKey = key
    }

    public init<X1: Jumpable, X2: Jumpable, X3: Jumpable>(wrappedValue af3: @escaping (O) -> (X1, X2, X3) async throws -> U, _ key: String? = nil, priority: TaskPriority? = nil) {
        self.function = Self.createAsyncFunction(priority: priority) { ctx, owner, args in
            try await af3(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args))
        }
        self.exportedKey = key
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jumped {
    public init<X1: Jumpable, X2: Jumpable, X3: Jumpable, X4: Jumpable>(wrappedValue f4: @escaping (O) -> (X1, X2, X3, X4) throws -> U, _ key: String? = nil) {
        self.function = { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                try f4(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args)).getJX(from: ctx)
            }
        }

        self.exportedKey = key
    }

    public init<X1: Jumpable, X2: Jumpable, X3: Jumpable, X4: Jumpable>(wrappedValue af4: @escaping (O) -> (X1, X2, X3, X4) async throws -> U, _ key: String? = nil, priority: TaskPriority? = nil) {
        self.function = Self.createAsyncFunction(priority: priority) { ctx, owner, args in
            try await af4(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args))
        }
        self.exportedKey = key
    }
}

