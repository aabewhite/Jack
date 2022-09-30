
/// A type that publishes a property with an exported function to an associated ``JXContext``.
///
/// Example:
///
///     class JackObj : JackedObject {
///         @Jack("now") private var _now = now // exported as function
///         func now() -> Date { Date(timeIntervalSince1970: 1_234) }
///
///         lazy var jsc = jack()
///     }
///
///     let obj = JackObjEnhancedObj()
///
///     try obj.jsc.eval("typeof now").stringValue == "function"
///     try obj.jsc.eval("typeof now()").stringValue == "object"
///     try obj.jsc.eval("now()").numberValue ==  1_234_000
///
/// ### See Also
///
/// - `Publisher.assign(to:)`
@propertyWrapper
public struct Jack<O: JackedObject, U> : _JackableProperty {
    typealias JumpFunc = (_ context: JXContext, _ owner: AnyObject?) -> JXValue

    private let function: JumpFunc

    var exportedKey: String?

    subscript(in context: JXContext, owner: AnyObject?) -> JXValue {
        get {
            function(context, owner)
        }
    }

    func setValue(_ newValue: JXValue, in context: JXContext, owner: AnyObject?) throws {
        throw JackError.functionPropertyReadOnly(newValue, .init(context: context))
    }

    // swiftlint:disable let_var_whitespace
    //@available(*, unavailable, message: "@Jack is only available on properties of classes")
    public var wrappedValue: (O) -> (Any) -> U {
        get { fatalError("@Jack is only available on properties of classes") }
        set { fatalError("@Jack is only available on properties of classes") } // swiftlint:disable:this unused_setter_value
    }
    // swiftlint:enable let_var_whitespace
}


private extension JXContext {
    func casting<O>(_ value: AnyObject?) throws -> O {
        if let value = value as? O {
            return value
        }
        throw JXErrors.jumpContextInvalid
    }

    func jarg<J: JXConvertible>(_ index: Int, _ args: [JXValue]) throws -> J {
        try J.makeJX(from: args.dropFirst(index).first ?? self.null())
    }
}

// The possible Jack function signatures are:
//
// 1. synchronous void return
// 2. asynchronous void return
// 3. synchronous JXConvertible return
// 4. asynchronous JXConvertible return

extension Jack {

    fileprivate static func createFunction<J: JXConvertible>(block: @escaping (JXContext, AnyObject?, [JXValue]) throws -> J) -> JumpFunc {
        { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                try block(ctx, owner, args).getJX(from: ctx)
            }
        }
    }

    fileprivate static func createFunctionVoid(block: @escaping (JXContext, AnyObject?, [JXValue]) throws -> Void) -> JumpFunc {
        { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                try block(ctx, owner, args)
                return ctx.undefined()
            }
        }
    }

    fileprivate static func createFunctionAsyncVoid(priority: TaskPriority?, block: @escaping (JXContext, AnyObject?, [JXValue]) async throws -> Void) -> JumpFunc {
        { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                let promise = try JXValue.createPromise(in: ctx)

                Task.detached(priority: priority) {
                    do {
                        try await block(ctx, owner, args)
                        try promise.resolveFunction.call(withArguments: [ctx.undefined()], this: this)
                    } catch {
                        // TODO: store the error so it can be retrieved from the stack
                        try promise.rejectFunction.call(withArguments: [ctx.error(error)], this: this)
                    }
                }

                return JXValue(env: ctx, value: promise.promise)
            }
        }
    }

    fileprivate static func createFunctionAsync<J: JXConvertible>(priority: TaskPriority?, block: @escaping (JXContext, AnyObject?, [JXValue]) async throws -> J) -> JumpFunc {
        { context, owner in
            JXValue(newFunctionIn: context) { ctx, this, args in
                let promise = try JXValue.createPromise(in: ctx)

                Task.detached(priority: priority) {
                    do {
                        let result = try await block(ctx, owner, args).getJX(from: ctx)
                        try promise.resolveFunction.call(withArguments: [result], this: this)
                    } catch {
                        try promise.rejectFunction.call(withArguments: [ctx.error(error)], this: this)
                    }
                }

                return JXValue(env: ctx, value: promise.promise)
            }
        }
    }
}


// MARK: Jack Arity 0

extension Jack {
    /// The default priority for async function execution.
    public static var defaultAsyncTaskPriority: TaskPriority? {
        nil
    }

    public init(wrappedValue f: @escaping (O) -> () throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))()
        }
        self.exportedKey = key
    }

    public init(wrappedValue f: @escaping (O) -> () throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))()
        }
        self.exportedKey = key
    }

    public init(wrappedValue f: @escaping (O) -> () async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))()
        }
        self.exportedKey = key
    }

    public init(wrappedValue f: @escaping (O) -> () async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))()
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 1

extension Jack {
    public init<X1: JXConvertible>(wrappedValue f: @escaping (O) -> (X1) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible>(wrappedValue f: @escaping (O) -> (X1) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible>(wrappedValue f: @escaping (O) -> (X1) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible>(wrappedValue f: @escaping (O) -> (X1) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 2

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 3

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 4

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 5

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 6

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 7

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 8

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 9

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 10

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible, X10: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9, X10) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args), ctx.jarg(9, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible, X10: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9, X10) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args), ctx.jarg(9, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible, X10: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9, X10) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args), ctx.jarg(9, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible, X10: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9, X10) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args), ctx.jarg(9, args))
        }
        self.exportedKey = key
    }
}

// MARK: Jack Arity 11

extension Jack {
    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible, X10: JXConvertible, X11: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9, X10, X11) throws -> U, _ key: String? = nil) where U : JXConvertible {
        self.function = Self.createFunction() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args), ctx.jarg(9, args), ctx.jarg(10, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible, X10: JXConvertible, X11: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9, X10, X11) throws -> U, _ key: String? = nil) where U == Void {
        self.function = Self.createFunctionVoid() { ctx, owner, args in
            try f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args), ctx.jarg(9, args), ctx.jarg(10, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible, X10: JXConvertible, X11: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9, X10, X11) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U == Void {
        self.function = Self.createFunctionAsyncVoid(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args), ctx.jarg(9, args), ctx.jarg(10, args))
        }
        self.exportedKey = key
    }

    public init<X1: JXConvertible, X2: JXConvertible, X3: JXConvertible, X4: JXConvertible, X5: JXConvertible, X6: JXConvertible, X7: JXConvertible, X8: JXConvertible, X9: JXConvertible, X10: JXConvertible, X11: JXConvertible>(wrappedValue f: @escaping (O) -> (X1, X2, X3, X4, X5, X6, X7, X8, X9, X10, X11) async throws -> U, _ key: String? = nil, priority: TaskPriority? = defaultAsyncTaskPriority) where U : JXConvertible {
        self.function = Self.createFunctionAsync(priority: priority) { ctx, owner, args in
            try await f(ctx.casting(owner))(ctx.jarg(0, args), ctx.jarg(1, args), ctx.jarg(2, args), ctx.jarg(3, args), ctx.jarg(4, args), ctx.jarg(5, args), ctx.jarg(6, args), ctx.jarg(7, args), ctx.jarg(8, args), ctx.jarg(9, args), ctx.jarg(10, args))
        }
        self.exportedKey = key
    }
}
