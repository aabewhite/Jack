import OpenCombineShim

/// A ``Jackable`` instance can be passed back and forth to a ``JXContext`` through serialization.
public typealias Jackable = Codable


/// A JackedObject is an ObservableObject with the ability to share their properties automatically with a ``JXJit\\JXContext``
///
/// This type extends from ``JackedObject``, which is a type of object with a publisher that emits before the object has changed.
///
/// By default an `JackedObject` synthesizes an `objectWillChange` publisher that
/// emits the changed value before any of its `@Jacked` properties changes.
///
///     class Contact : JackedObject {
///         @Jacked var name: String
///         @Jacked var age: Int
///
///         init(name: String, age: Int) {
///             self.name = name
///             self.age = age
///         }
///
///         func haveBirthday() -> Int {
///             age += 1
///         }
///     }
///
///     let john = Contact(name: "John Appleseed", age: 24)
///     cancellable = john.objectWillChange
///         .sink { _ in
///             print("\(john.age) will change")
///         }
///     print(john.haveBirthday())
///     // Prints "24 will change"
///     // Prints "25"
@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
public protocol JackedObject : ObservableObject {

}


@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
public extension JackedObject {
    func objectMap() -> Void {

    }
}

// MARK: Jacked

// Sadly, this is mostly just a copy & paste re-implementation of OpenCombile.Published.
// This is because the Combine & OpenCombine type implementations are private or internal, and so cannot be re-used.


/// A type that publishes a property marked with an attribute and exports that property to an associated ``JXKit\\JXContext``.
///
/// Publishing a property with the `@Jacked` attribute creates a publisher of this
/// type. You access the publisher with the `$` operator, as shown here:
///
///     class Weather {
///         @Jacked var temperature: Double
///         init(temperature: Double) {
///             self.temperature = temperature
///         }
///     }
///
///     let weather = Weather(temperature: 20)
///     cancellable = weather.$temperature
///         .sink() {
///             print ("Temperature now: \($0)")
///         }
///     weather.temperature = 25
///
///     // Prints:
///     // Temperature now: 20.0
///     // Temperature now: 25.0
///
/// When the property changes, publishing occurs in the property's `willSet` block,
/// meaning subscribers receive the new value before it's actually set on the property.
/// In the above example, the second time the sink executes its closure, it receives
/// the parameter value `25`. However, if the closure evaluated `weather.temperature`,
/// the value returned would be `20`.
///
/// > Important: The `@Jacked` attribute is class constrained. Use it with properties
/// of classes, not with non-class types like structures.
///
/// ### See Also
///
/// - `Publisher.assign(to:)`
@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
@propertyWrapper
public struct Jacked<Value : Jackable> {
    /// The key that will be used to export the instance; a nil key will prevent export.
    private let key: String?

    // private let defaultValue: Value

    /// A publisher for properties marked with the `@Jacked` attribute.
    public struct JackedPublisher: Publisher {
        public typealias Output = Value
        public typealias Failure = Never
        fileprivate let subject: JackedSubject<Value>

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Value, Downstream.Failure == Never
        {
            subject.subscribe(subscriber)
        }

        fileprivate init(_ output: Output) {
            subject = .init(output)
        }
    }

    private enum Storage {
        case value(Value)
        case publisher(JackedPublisher)
    }
    @propertyWrapper
    private final class Box {
        var wrappedValue: Storage

        init(wrappedValue: Storage) {
            self.wrappedValue = wrappedValue
        }
    }

    @Box private var storage: Storage

    public var objectWillChange: ObservableObjectPublisher? {
        get {
            switch storage {
            case .value:
                return nil
            case .publisher(let publisher):
                return publisher.subject.objectWillChange
            }
        }
        nonmutating set {
            getPublisher().subject.objectWillChange = newValue
        }
    }

    /// Creates the published instance with an initial wrapped value.
    ///
    /// Don't use this initializer directly. Instead, create a property with
    /// the `@Jacked` attribute, as shown here:
    ///
    ///     @Jacked var lastUpdated: Date = Date()
    ///
    /// - Parameter wrappedValue: The publisher's initial value.
    public init(initialValue: Value, _ key: String?) {
        self.init(wrappedValue: initialValue, key)
    }

    /// Creates the published instance with an initial value.
    ///
    /// Don't use this initializer directly. Instead, create a property with
    /// the `@Jacked` attribute, as shown here:
    ///
    ///     @Jacked var lastUpdated: Date = Date()
    ///
    /// - Parameter initialValue: The publisher's initial value.
    public init(wrappedValue: Value, _ key: String?) {
        _storage = Box(wrappedValue: .value(wrappedValue))
        self.key = key
    }

    /// The property for which this instance exposes a publisher.
    ///
    /// The `projectedValue` is the property accessed with the `$` operator.
    public var projectedValue: JackedPublisher {
        mutating get {
            return getPublisher()
        }
        set { // swiftlint:disable:this unused_setter_value
            switch storage {
            case .value(let value):
                storage = .publisher(JackedPublisher(value))
            case .publisher:
                break
            }
        }
    }

    /// Note: This method can mutate `storage`
    fileprivate func getPublisher() -> JackedPublisher {
        switch storage {
        case .value(let value):
            let publisher = JackedPublisher(value)
            storage = .publisher(publisher)
            return publisher
        case .publisher(let publisher):
            return publisher
        }
    }
    // swiftlint:disable let_var_whitespace
    @available(*, unavailable, message: """
               @Jacked is only available on properties of classes
               """)
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() } // swiftlint:disable:this unused_setter_value
    }
    // swiftlint:enable let_var_whitespace

    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Jacked<Value>>
    ) -> Value {
        get {
            switch object[keyPath: storageKeyPath].storage {
            case .value(let value):
                return value
            case .publisher(let publisher):
                return publisher.subject.value
            }
        }
        set {
            switch object[keyPath: storageKeyPath].storage {
            case .value:
                object[keyPath: storageKeyPath].storage = .publisher(JackedPublisher(newValue))
            case .publisher(let publisher):
                publisher.subject.value = newValue
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
fileprivate final class JackedSubject<Output>: Subject {
    typealias Failure = Never
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
            lock.lock()
            defer { lock.unlock() }
            changePublisher = newValue
        }
    }

    init(_ value: Output) {
        self.currentValue = value
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
private protocol _ObservableObjectProperty {
    //var objectWillChange: ObservableObjectPublisher? { get nonmutating set }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
private protocol _JackableProperty : _ObservableObjectProperty {
    var objectWillChange: ObservableObjectPublisher? { get nonmutating set }
}

// This is identical to the OpenCombine implementation except for notifications we handle both `*Combine.Published` and `SwiftJack.Jacked`

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jacked: _JackableProperty {}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Published: _ObservableObjectProperty {
}

// this is what we need to be able to suport both @Jacked and @Published, but it relies on internal Published details

//@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
//extension Published: _JackableProperty {
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension JackedObject where ObjectWillChangePublisher == ObservableObjectPublisher {

    /// A publisher that emits before the object has changed.
    public var objectWillChange: ObservableObjectPublisher {
        var installedPublisher: ObservableObjectPublisher?
        var reflection: Mirror? = Mirror(reflecting: self)
        while let aClass = reflection {
            for (_, property) in aClass.children {

                guard let property = property as? _ObservableObjectProperty else {
                    // Visit other fields until we meet a @Published field
                    continue
                }

                guard let property = property as? _JackableProperty else {
                    // TODO: how can we implemnent support for both 
                    fatalError("instances may not currently have both @Published and @Jacked properties")
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

                // Continue visiting other fields.
            }
            reflection = aClass.superclassMirror
        }
        return installedPublisher ?? ObservableObjectPublisher()
    }
}

#if canImport(COpenCombineHelpers)
import COpenCombineHelpers
#endif

#if WASI
fileprivate struct __UnfairLock { // swiftlint:disable:this type_name
    static func allocate() -> UnfairLock { return .init() }
    func lock() {}
    func unlock() {}
    func assertOwner() {}
    func deallocate() {}
}

fileprivate struct __UnfairRecursiveLock { // swiftlint:disable:this type_name
    static func allocate() -> UnfairRecursiveLock { return .init() }
    func lock() {}
    func unlock() {}
    func deallocate() {}
}
#endif // WASI

fileprivate typealias UnfairLock = __UnfairLock
fileprivate typealias UnfairRecursiveLock = __UnfairRecursiveLock


@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension ConduitBase: Equatable {
    static func == (lhs: ConduitBase<Output, Failure>,
                             rhs: ConduitBase<Output, Failure>) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension ConduitBase: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension ConduitList: HasDefaultValue {
    init() {
        self = .empty
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
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

