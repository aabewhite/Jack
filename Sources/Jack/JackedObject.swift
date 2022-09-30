#if canImport(Combine)
import Combine
#else
import OpenCombine
#if canImport(OpenCombineDispatch)
import OpenCombineDispatch
#endif
#if canImport(OpenCombineFoundation)
import OpenCombineFoundation
#endif
#endif

/// A ``JackedObject`` is an ``ObservableObject`` with the ability to share their properties automatically with a ``JXContext``.
/// This allows an embedded JavaScript context to access the properties and invoke the functions of the containing object.
///
/// This type extends from ``JackedObject``, which is a type of object with a publisher that emits before the object has changed.
///
///     class EnhancedObj : JackedObject {
///         @Tracked var x = 0 // unexported to jxc
///         @Jacked var i = 1 // exported as number
///         @Jacked("B") var b = false // exported as bool
///         @Coded var id = UUID() // exported (via codability) as string
///         @Jumped("now") private var _now = now // exported as function
///         func now() -> Date { Date(timeIntervalSince1970: 1_234) }
///
///         lazy var jxc = jack()
///     }
///
///     let obj = EnhancedObj()
///
///     try obj.jxc.env.eval("typeof x").stringValue == "undefined"
///     try obj.jxc.env.eval("typeof i").stringValue == "number"
///
///     try obj.jxc.env.eval("typeof b").stringValue == "undefined"
///     try obj.jxc.env.eval("typeof B").stringValue == "boolean"
///
///     try obj.jxc.env.eval("typeof id").stringValue == "string"
///
///     try obj.jxc.env.eval("typeof now").stringValue == "function"
///     try obj.jxc.env.eval("typeof now()").stringValue == "object"
///     try obj.jxc.env.eval("now()").numberValue ==  1_234_000
///
/// In addition, a `JackedObject` synthesizes an `objectWillChange` publisher that
/// emits the changed value before any of its wrapped properties changes.
///
///      class Contact : JackedObject {
///          @Jacked var name: String
///          @Jacked var age: Int
///
///          lazy var jxc = jack()
///
///          init(name: String, age: Int) {
///             self.name = name
///             self.age = age
///          }
///
///          @Jumped("haveBirthday") var _haveBirthday = haveBirthday
///          func haveBirthday() -> Int {
///             age += 1
///             return age
///          }
///      }
///
///     let john = Contact(name: "John Appleseed", age: 24)
///
///     var changes = 0
///     let cancellable = john.objectWillChange
///     .sink { _ in
///         changes += 1
///     }
///
///     XCTAssertEqual(25, john.haveBirthday())
///     XCTAssertEqual(1, changes)
///
///     XCTAssertEqual(26, try john.jxc.env.eval("haveBirthday()").numberValue)
///     XCTAssertEqual(2, changes)
///
///     let _ = cancellable
///
/// Note: even though ``JackedObject`` extends ``ObservableObject``, and can be used
/// in its place in SwiftUI hierarchies with ``@EnvironmentObject``, it is *not* possible to
/// mix ``@Published`` and ``@Jacked`` properties in the same object. Doing so will
/// result in a crash at initialization time. In order to support ``@Published``behavior
/// without needing to export the property to the JSC, use the equivalent ``@Tracked`` wrapper,
/// which will behave the same way.
public protocol JackedObject : ObservableObject {
}

public extension JackedObject {
    /// The lazy list of all props in the hierarchy
    fileprivate func props() -> LazySequence<FlattenSequence<LazyMapSequence<UnfoldSequence<Mirror, (Mirror?, Bool)>, Mirror.Children>.Elements>> {
        sequence(first: Mirror(reflecting: self), next: \.superclassMirror).lazy.map(\.children).joined()
    }

    /// Jack into the given context, exposing all this instance's `@Jacked` properties into the given `JXContext`.
    ///
    /// - Parameters:
    ///   - context: the context to jack into; will create a new context if needed
    ///   - key: a key to use to create an object for the key
    ///
    /// - Returns: the instance that was jacked into the context
    @discardableResult func jack(into context: JXContext = JXContext(), as key: String? = nil) -> JXValue {
        var object = context.global

        if let key = key {
            do {
                // TODO: should be permit multi-jacking objects if they already exist in the key?
                object = try context.global[key]
                if !object.isObject {
                    object = context.object()
                }
                try context.global.setProperty(key, object)
            } catch {
                fatalError("ERROR: unable to set propery for object '\(key)': \(error)")
            }
        }

        do {
            try inject(into: object)
        } catch {
            fatalError("ERROR: unable to inject into object for '\(key)': \(error)")
        }

        //try! object.seal()
        return object
    }

    /// Inject all this instance's `@Jacked` and `@Jumped` properties into the JXValue object.
    /// The resuling object will have properties created for each of the corresponding property
    /// wrappers in the `JackedObject`.
    ///
    /// - Parameters:
    ///   - into context: the context to jack into; will create a new context if needed
    ///   - for object: the JXObject to inject into
    @discardableResult func inject(into object: JXValue) throws -> [JXProperty] {
        var addedProps: Set<String> = []

        let ctx = object.env
        var added: [JXProperty] = []

        for (label, prop) in props() {
            guard let prop = prop as? _JackableProperty else {
                continue
            }

            // use the key or else the label (which is preceeded with an underscore, and so is dropped)
            guard let key = prop.exportedKey ?? label?.dropFirst().description else {
                continue
            }

            // if the property has already been added, don't try to add it again;
            // since we iterate from child to parent, this allows subclasses to override functions
            if addedProps.insert(key).inserted == false {
                //print("skipping already added property: \(key)")
                continue
            }

            let jprop = JXProperty(
                getter: { [weak self, ctx] this in try prop[in: ctx, self] },
                setter: { [weak self, ctx] this, newValue in try prop.setValue(newValue, in: ctx, owner: self) }
            )

            if let symbolPrefix = prop.bindingPrefix {
                let symbol = object.env.symbol(key)
                try object.defineProperty(symbol, jprop)
                let symbolKey = symbolPrefix + key
                try object.setProperty(symbolKey, symbol)
            } else {
                try object.defineProperty(object.env.string(key), jprop)
            }
            added.append(jprop)
        }

        return added
    }
}

public protocol JXReferenceable : JXConvertible {
//    init()

    /// The corresponding peer object for this instance on the JavaScript side.
    var peer: JXValue? { get nonmutating set }
}

extension JXReferenceable where Self : JackedObject {
    /// `JXConvertible` implementation for `JackedObject`,
    public static func makeJX(from value: JXValue) throws -> Self {
        guard let obj = value.env.peer(for: value) else {
            throw JackError.invalidReferenceContext(value, .init(context: value.env))
        }

        guard let jobj = obj as? Self else { // TODO: what if some already conveyed this to a different wrapper type?
            print("### bad type obj:", wip(obj), type(of: Self.self))
            throw JackError.invalidReferenceType(value, .init(context: value.env))
        }

        return jobj
    }

    public func getJX(from context: JXContext) throws -> JXValue {
        if let obj = self.peer { // do we already have a counterpart on the JX side?
            return obj
        }

        let obj = context.object(peer: self) // create a new object in the context // TODO: should we set a class name on the type?
        try inject(into: obj)
        self.peer = obj
        return obj
    }
}

/// A `JackedReference` is a concrete base class implementation of `JackedObject`
/// that tracks the instance's native peer.
///
/// A `JackedReference` can only ever be associated with a single `JXContext`.
open class JackedReference : JackedObject, JXReferenceable {
    // TODO: store peer as private data in the object and access with `JSObjectGetPrivate` instead

    /// The counterpart JXValue for a given context
    public weak var peer: JXValue? = nil

    public init() {
        
    }
//
//    public required init() {
//    }

//    deinit {
//        //print("deini", wip(self), "peer:", self.peer)
//
//        for (label, prop) in props() {
//            guard let prop = prop as? _JackableProperty else {
//                continue
//            }
//            print("### clearing prop:", label, prop)
//            prop.clear() // TODO: clear all properties?
//        }
//
//        self.peer = nil
//    }
}


#if canImport(SwiftUI)
import protocol SwiftUI.DynamicProperty
typealias _DynamicProperty = SwiftUI.DynamicProperty
#else
protocol _DynamicProperty {
}
#endif

internal protocol _ObservableObjectProperty : _DynamicProperty {
    //var objectWillChange: ObservableObjectPublisher? { get nonmutating set }
}

/// A marker for a property that can trigger a state change
internal protocol _TrackableProperty : _ObservableObjectProperty {
    var objectWillChange: ObservableObjectPublisher? { get nonmutating set }
}

internal protocol _JackableProperty : _ObservableObjectProperty {
    /// The key name for the instance
    var exportedKey: String? { get }

    /// A string to prefix the symbol name for bound properties
    var bindingPrefix: String? { get }

    subscript(in context: JXContext, owner: AnyObject?) -> JXValue { get throws }

    func setValue(_ newValue: JXValue, in context: JXContext, owner: AnyObject?) throws
}

extension _JackableProperty {
    var bindingPrefix: String? {
        wip(nil) // TODO: fill this into types other than Jacked
    }
}

extension Published: _ObservableObjectProperty {
}

// this is what we need to be able to suport both @Jacked and @Published, but it relies on internal Published details

////extension Published: _JackableProperty {
//    internal var objectWillChange: ObservableObjectPublisher? {
//        get {
//            switch storage {
//            case .value:
//                return nil
//            case .publisher(let publisher):
//                return publisher.subject.objectWillChange
//            }
//        }
//        nonmutating set {
//            getPublisher().subject.objectWillChange = newValue
//        }
//    }
//
//}

extension JackedObject where ObjectWillChangePublisher == ObservableObjectPublisher {

    /// A publisher that emits before the object has changed.
    public var objectWillChange: ObservableObjectPublisher {
        var installedPublisher: ObservableObjectPublisher?
        var reflection: Mirror? = Mirror(reflecting: self)
        while let aClass = reflection {
            for (_, property) in aClass.children {
                guard let property = property as? _DynamicProperty else {
                    // Visit other fields until we meet a @Published field
                    continue
                }

                if property is Published<ObjectWillChangePublisher.Output> {
                    // TODO: how can we implement support for @Published and @Jacked at the same time?
                    fatalError("instances may not currently have both @Published and @Jacked properties (use @Tracked instead)")
                }

                // we cannot integrate with other properties that have some built-in Combine support.
                // notably, SwiftUI's `AppStorage`, `Environment`, and `StateObject` will not trigger
                // objectWillChange, and thus should not be stores in the same instances as Jacked properties
                guard let property = property as? _ObservableObjectProperty else {
                    fatalError("unhandled property type cannot be used in a JackedObject: \(property) (use @Tracked or @Jacked instead)")
                }

                guard let property = property as? _TrackableProperty else {
                    // skip over other read-only types (e.g., Jumped, Tracked) are left un-tracked
                    continue
                }

                // Now we know that the field is @Jacked.
                if let alreadyInstalledPublisher = property.objectWillChange {
                    installedPublisher = alreadyInstalledPublisher
                    // Don't visit other fields, as all @Jacked and @Published fields
                    // already have a publisher installed.
                    break
                }

                // Okay, this field doesn't have a publisher installed.
                // This means that other fields don't have it either
                // (because we install it only once and fields can't be added at runtime).
                var lazilyCreatedPublisher: ObjectWillChangePublisher {
                    if let publisher = installedPublisher {
                        return publisher
                    }
                    let publisher = ObservableObjectPublisher()
                    installedPublisher = publisher
                    return publisher
                }

                property.objectWillChange = lazilyCreatedPublisher
            }
            reflection = aClass.superclassMirror
        }
        return installedPublisher ?? ObservableObjectPublisher()
    }
}

import Dispatch

internal final class JackedSubject<Output>: Subject {
    typealias Failure = Never
    private let queue: DispatchQueue?
    private let lock = UnfairLock.allocate()
    private var downstreams = ConduitList<Output, Failure>.empty
    private var currentValue: Output
    private var upstreamSubscriptions: [Subscription] = []
    private var hasAnyDownstreamDemand = false
    private var changePublisher: ObservableObjectPublisher?

    var value: Output {
        get {
            lock.lock()
            defer { lock.unlock() }
            return currentValue
        }
        set {
            send(newValue)
        }
    }

    var objectWillChange: ObservableObjectPublisher? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return changePublisher
        }
        set {
            if let queue = queue {
                queue.async { [weak self] in
                    self?.lock.lock()
                    defer { self?.lock.unlock() }
                    self?.changePublisher = newValue
                }
            } else {
                lock.lock()
                defer { lock.unlock() }
                changePublisher = newValue
            }
        }
    }

    init(_ value: Output, queue: DispatchQueue?) {
        self.currentValue = value
        self.queue = queue
    }

    deinit {
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }

    func send(subscription: Subscription) {
        lock.lock()
        upstreamSubscriptions.append(subscription)
        lock.unlock()
        subscription.request(.unlimited)
    }

    func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Output, Downstream.Failure == Never
    {
        lock.lock()
        let conduit = Conduit(parent: self, downstream: subscriber)
        downstreams.insert(conduit)
        lock.unlock()
        subscriber.receive(subscription: conduit)
    }

    func send(_ input: Output) {
        lock.lock()
        let downstreams = self.downstreams
        let changePublisher = self.changePublisher
        lock.unlock()
        changePublisher?.send()
        downstreams.forEach { conduit in
            conduit.offer(input)
        }
        lock.lock()
        currentValue = input
        lock.unlock()
    }

    func send(completion: Subscribers.Completion<Never>) {
        fatalError("unreachable")
    }

    private func disassociate(_ conduit: ConduitBase<Output, Failure>) {
        lock.lock()
        downstreams.remove(conduit)
        lock.unlock()
    }
}

extension JackedSubject {

    private final class Conduit<Downstream: Subscriber>
        : ConduitBase<Output, Failure>,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Never
    {
        fileprivate var parent: JackedSubject?
        fileprivate var downstream: Downstream?
        fileprivate var demand = Subscribers.Demand.none
        private var lock = UnfairLock.allocate()
        private var downstreamLock = UnfairRecursiveLock.allocate()
        private var deliveredCurrentValue = false

        fileprivate init(parent: JackedSubject,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        override func offer(_ output: Output) {
            lock.lock()
            guard demand > 0, let downstream = self.downstream else {
                deliveredCurrentValue = false
                lock.unlock()
                return
            }
            demand -= 1
            deliveredCurrentValue = true
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(output)
            downstreamLock.unlock()
            guard newDemand > 0 else { return }
            lock.lock()
            demand += newDemand
            lock.unlock()
        }

        override func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let downstream = self.downstream else {
                lock.unlock()
                return
            }
            if deliveredCurrentValue {
                self.demand += demand
                lock.unlock()
                return
            }

            // Hasn't yet delivered the current value

            self.demand += demand
            deliveredCurrentValue = true
            if let currentValue = self.parent?.value {
                self.demand -= 1
                lock.unlock()
                downstreamLock.lock()
                let newDemand = downstream.receive(currentValue)
                downstreamLock.unlock()
                guard newDemand > 0 else { return }
                lock.lock()
                self.demand += newDemand
            }
            lock.unlock()
        }

        override func cancel() {
            lock.lock()
            if self.downstream == nil {
                lock.unlock()
                return
            }
            self.downstream = nil
            let parent = self.parent.take()
            lock.unlock()
            parent?.disassociate(self)
        }

        var description: String { return "JackedSubject" }

        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("parent", parent as Any),
                ("downstream", downstream as Any),
                ("demand", demand),
                ("subject", parent as Any)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}


#if canImport(COpenCombineHelpers)
import COpenCombineHelpers

fileprivate typealias UnfairLock = __UnfairLock
fileprivate typealias UnfairRecursiveLock = __UnfairRecursiveLock

#elseif canImport(Foundation)
import class Foundation.NSLock

fileprivate class __UnfairLock {
    let _lock = NSLock()

    static func allocate() -> UnfairLock {
        return .init()
    }

    func lock() {
        _lock.lock()
    }

    func unlock() {
        _lock.unlock()
    }

    func assertOwner() {
    }

    func deallocate() {
    }
}

import class Foundation.NSRecursiveLock

fileprivate class __UnfairRecursiveLock {
    let _lock = NSRecursiveLock()

    static func allocate() -> UnfairRecursiveLock {
        return .init()
    }

    func lock() {
        _lock.lock()
    }

    func unlock() {
        _lock.unlock()
    }

    func deallocate() {
    }
}

fileprivate typealias UnfairLock = __UnfairLock
fileprivate typealias UnfairRecursiveLock = __UnfairRecursiveLock
#endif


fileprivate class ConduitBase<Output, Failure: Error>: Subscription {

    fileprivate init() {}

    func offer(_ output: Output) {
        abstractMethod()
    }

    func finish(completion: Subscribers.Completion<Failure>) {
        abstractMethod()
    }

    func request(_ demand: Subscribers.Demand) {
        abstractMethod()
    }

    func cancel() {
        abstractMethod()
    }
}

extension ConduitBase: Equatable {
    static func == (lhs: ConduitBase<Output, Failure>,
                             rhs: ConduitBase<Output, Failure>) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension ConduitBase: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

fileprivate enum ConduitList<Output, Failure: Error> {
    case empty
    case single(ConduitBase<Output, Failure>)
    case many(Set<ConduitBase<Output, Failure>>)
}

fileprivate protocol HasDefaultValue {
    init()
}

extension HasDefaultValue {

    @inline(__always)
    mutating func take() -> Self {
        let taken = self
        self = .init()
        return taken
    }
}

extension Array: HasDefaultValue {}

extension Dictionary: HasDefaultValue {}

extension Optional: HasDefaultValue {
    init() {
        self = nil
    }
}

extension ConduitList: HasDefaultValue {
    init() {
        self = .empty
    }
}

fileprivate extension ConduitList {
    mutating func insert(_ conduit: ConduitBase<Output, Failure>) {
        switch self {
        case .empty:
            self = .single(conduit)
        case .single(conduit):
            break // This element already exists.
        case .single(let existingConduit):
            self = .many([existingConduit, conduit])
        case .many(var set):
            set.insert(conduit)
            self = .many(set)
        }
    }

    func forEach(
        _ body: (ConduitBase<Output, Failure>) throws -> Void
    ) rethrows {
        switch self {
        case .empty:
            break
        case .single(let conduit):
            try body(conduit)
        case .many(let set):
            try set.forEach(body)
        }
    }

    mutating func remove(_ conduit: ConduitBase<Output, Failure>) {
        switch self {
        case .single(conduit):
            self = .empty
        case .empty, .single:
            break
        case .many(var set):
            set.remove(conduit)
            self = .many(set)
        }
    }
}

fileprivate extension Subscribers.Demand {
    func assertNonZero(file: StaticString = #file,
                                line: UInt = #line) {
        if self == .none {
            fatalError("API Violation: demand must not be zero", file: file, line: line)
        }
    }
}

fileprivate func abstractMethod(file: StaticString = #file, line: UInt = #line) -> Never {
    fatalError("Abstract method call", file: file, line: line)
}

