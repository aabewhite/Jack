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

/// A ``Jackable`` type can be passed efficiently back and forth to a ``JXContext`` without serialization.
///
/// This type is used to constrain arument and return types that should be passed efficiently between the host Swift environment and the embedded JSC.
///
/// To support for passing codable types through serialization, use ``Pack``
public protocol Jackable : JXConvertible {
}

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
public struct Stack<Value : Jackable> : _TrackableProperty {
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


// Stack is always a _TrackableProperty, but is only a _JackableProperty when the embedded type is itself `Jackable`
extension Stack: _JackableProperty where Value : Jackable {
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

// MARK: Default Implementations

public extension RawRepresentable where RawValue : Jackable {
    static func makeJXRaw(from value: JXValue) throws -> Self {
        guard let newSelf = Self(rawValue: try .fromJX(value)) else {
            throw JackError.rawInitializerFailed(value, .init(context: value.context))
        }
        return newSelf
    }

    func getJXRaw(from context: JXContext) throws -> JXValue {
        try self.rawValue.toJX(in: context)
    }

    static func fromJX(_ value: JXValue) throws -> Self {
        try makeJXRaw(from: value)
    }

    func toJX(in context: JXContext) throws -> JXValue {
        try getJXRaw(from: context)
    }
}

extension Bool : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self {
        guard value.isBoolean else {
            throw JackError.valueWasNotABoolean(value, .init(context: value.context))
        }
        return value.bool
    }

    public func toJX(in context: JXContext) -> JXValue {
        context.boolean(self)
    }
}

extension String : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self {
        try value.string
    }

    public func toJX(in context: JXContext) -> JXValue {
        context.string(self)
    }
}

extension BinaryInteger where Self : _ExpressibleByBuiltinIntegerLiteral {
    static func _fromJX(_ value: JXValue) throws -> Self {
        let num = try value.double
        guard !num.isNaN else {
            throw JackError.valueWasNotANumber(value, .init(context: value.context))
        }
        return .init(integerLiteral: .init(num))
    }

    func _toJX(in context: JXContext) -> JXValue {
        context.number(self)
    }
}

extension Int : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}

extension Int16 : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}

extension Int32 : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}

extension Int64 : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}

extension UInt : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}

extension UInt16 : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}

extension UInt32 : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}

extension UInt64 : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}


extension BinaryFloatingPoint where Self : ExpressibleByFloatLiteral {
    static func _fromJX(_ value: JXValue) throws -> Self {
        Self(try value.double)
    }

    func _toJX(in context: JXContext) -> JXValue {
        context.number(self)
    }
}


extension Double : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}

extension Float : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}


extension Optional : Jackable where Wrapped : JXConvertible {
}

extension Array : Jackable where Element : JXConvertible {
}

#if canImport(CoreGraphics)
import typealias CoreGraphics.CGFloat
extension CGFloat : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self { try _fromJX(value) }
    public func toJX(in context: JXContext) -> JXValue { _toJX(in: context) }
}
#endif

#if canImport(Foundation)
import struct Foundation.Date

extension Date : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self {
        try value.date // ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        try context.date(self)
    }
}
#endif


#if canImport(Foundation)
import struct Foundation.Data

extension Data : Jackable {
    public static func fromJX(_ value: JXValue) throws -> Self {
//        if value.isArrayBuffer { // fast track
//            #warning("TODO: array buffer")
//            fatalError("array buffer") // TODO
//        } else
        if value.isArray { // slow track
            // copy the array manually
            let length = try value["length"]

            let count = try length.double
            guard length.isNumber, let max = UInt32(exactly: count) else {
                throw JackError.valueNotArray(value, .init(context: value.context))
            }

            let data: [UInt8] = try (0..<max).map { index in
                let element = try value[.init(index)]
                guard element.isNumber else {
                    throw JackError.dataElementNotNumber(Int(index), value, .init(context: value.context))
                }
                let num = try element.double
                guard num <= .init(UInt8.max), num >= .init(UInt8.min), let byte = UInt8(exactly: num) else {
                    throw JackError.dataElementOutOfRange(Int(index), value, .init(context: value.context))
                }

                return byte
            }

            return Data(data)
        } else {
            throw JackError.valueNotArray(value, .init(context: value.context))
        }
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        var d = self
        return try d.withUnsafeMutableBytes { bytes in
            try JXValue(newArrayBufferWithBytesNoCopy: bytes,
                deallocator: { _ in
                    //print("buffer deallocated")
                },
                in: context)
        }
    }
}
#endif

