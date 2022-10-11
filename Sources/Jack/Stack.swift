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

import Dispatch
import JXKit

// MARK: Stack

// Sadly, this is mostly just a copy & paste re-implementation of OpenCombile.Published.
// This is because the Combine & OpenCombine type implementations are private or internal, and so cannot be re-used.


/// A type that publishes a property marked with an attribute and exports that property to an associated ``JXKit\\JXContext``.
///
/// Publishing a property with the `@Stack` attribute creates a publisher of this
/// type. You access the publisher with the `$` operator, as shown here:
///
///     class Weather {
///         @Stack var temperature: Double
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
/// > Important: The `@Stack` attribute is class constrained. Use it with properties
/// of classes, not with non-class types like structures.
///
/// ### See Also
///
/// - `Publisher.assign(to:)`
@propertyWrapper
public struct Stack<Value : JXConvertible> : _TrackableProperty {
    /// The key that will be used to export the instance; a nil key will prevent export.
    public let key: String?

    /// The binding prefix to use, if any
    public let bindingPrefix: String?

    #warning("WIP: implement non-mutable access protection")

    /// If false then writing to the property will fail with an exception
    public let mutable: Bool?

    /// Whether changes should be published on a certai queue
    internal let queue: DispatchQueue?

    typealias Storage = JackPublisher<Value>.Storage

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
    /// the `@Stack` attribute, as shown here:
    ///
    ///     @Stack var lastUpdated: Date = Date()
    ///
    /// - Parameter wrappedValue: The publisher's initial value.
    public init(initialValue: Value, _ key: String? = nil, mutable: Bool? = nil, bind: String? = nil, queue: DispatchQueue? = nil) {
        self.init(wrappedValue: initialValue, key, mutable: mutable, bind: bind, queue: queue)
    }

    /// Creates the published instance with an initial value.
    ///
    /// Don't use this initializer directly. Instead, create a property with
    /// the `@Stack` attribute, as shown here:
    ///
    ///     @Stack var lastUpdated: Date = Date()
    ///
    /// - Parameter initialValue: The publisher's initial value.
    public init(wrappedValue: Value, _ key: String? = nil, mutable: Bool? = nil, bind bindingPrefix: String? = nil, queue: DispatchQueue? = nil) {
        _storage = Box(wrappedValue: .value(wrappedValue))
        self.key = key
        self.mutable = mutable
        self.bindingPrefix = bindingPrefix
        self.queue = queue
    }

    /// The property for which this instance exposes a publisher.
    ///
    /// The `projectedValue` is the property accessed with the `$` operator.
    public var projectedValue: JackPublisher<Value> {
        mutating get {
            return getPublisher()
        }
        set {
            switch storage {
            case .value(let value):
                storage = .publisher(JackPublisher(value, queue: queue))
            case .publisher:
                break
            }
        }
    }

    /// Note: This method can mutate `storage`
    fileprivate func getPublisher() -> JackPublisher<Value> {
        switch storage {
        case .value(let value):
            let publisher = JackPublisher(value, queue: queue)
            storage = .publisher(publisher)
            return publisher
        case .publisher(let publisher):
            return publisher
        }
    }

    @available(*, unavailable, message: "@Stack is only available on properties of classes")
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }
    

    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Stack<Value>>
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
                object[keyPath: storageKeyPath].storage = .publisher(JackPublisher(newValue, queue: object[keyPath: storageKeyPath].queue))
            case .publisher(let publisher):
                publisher.subject.value = newValue
            }
        }
    }
}


// Stack is always a _TrackableProperty, but is only a _JackableProperty when the embedded type is itself `JXConvertible`
extension Stack: _JackableProperty where Value : JXConvertible {
    var exportedKey: String? { key }

    subscript(in context: JXContext, owner: AnyObject?) -> JXValue {
        get throws {
            switch _storage.wrappedValue {
            case .value(let value):
                return try value.toJX(in: context)
            case .publisher(let publisher):
                return try publisher.subject.value.toJX(in: context)
            }
        }
    }

    func setValue(_ newValue: JXValue, in context: JXContext, owner: AnyObject?) throws {
        switch _storage.wrappedValue {
        case .value(var value):
            value = try Value.fromJX(newValue)
            storage = .publisher(JackPublisher(value, queue: queue))
        case .publisher(let publisher):
            let jx = try Value.fromJX(newValue)
            if let queue = queue {
                queue.async {
                    publisher.subject.value = jx
                }
            } else {
                publisher.subject.value = jx
            }
        }
    }
}
