import OpenCombineShim

/// A ``Jackable`` type can be passed efficiently back and forth to a ``JXContext`` without serialization.
///
/// This type is used to constrain arument and return types that should be passed efficiently between the host Swift environment and the embedded JSC.
///
/// To support for passing codable types through serialization, use ``Jugglable``
public protocol Jackable : Jumpable {
    /// Sets the value of this property
    mutating func setJX(value: JXValue, in context: JXContext) throws

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
public struct Jacked<Value : Jackable> : _TrackableProperty {
    /// The key that will be used to export the instance; a nil key will prevent export.
    internal let key: String?

    typealias Storage = JackedPublisher<Value>.Storage

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
    public init(initialValue: Value, _ key: String? = nil) {
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
    public init(wrappedValue: Value, _ key: String? = nil) {
        _storage = Box(wrappedValue: .value(wrappedValue))
        self.key = key
    }

    /// The property for which this instance exposes a publisher.
    ///
    /// The `projectedValue` is the property accessed with the `$` operator.
    public var projectedValue: JackedPublisher<Value> {
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
    fileprivate func getPublisher() -> JackedPublisher<Value> {
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
    @available(*, unavailable, message: "@Jacked is only available on properties of classes")
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



// This is close to the OpenCombine implementation except we handle both `*Combine.Published` and `Jack.Jacked`


// Jacked is always a _TrackableProperty, but is only a _JackableProperty when the embedded type is itself `Jackable`
@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension Jacked: _JackableProperty where Value : Jackable {
    var exportedKey: String? { key }

    subscript(in context: JXContext, owner: AnyObject?) -> JXValue {
        get {
            switch _storage.wrappedValue {
            case .value(var value):
                return value.getJX(from: context)
            case .publisher(let publisher):
                return publisher.subject.value.getJX(from: context)
            }
        }

        nonmutating set {
            do {
                switch _storage.wrappedValue {
                case .value(let value):
                    var v = value
                    try v.setJX(value: newValue, in: context)
                    storage = .publisher(JackedPublisher(v))
                case .publisher(let publisher):
                    try publisher.subject.value.setJX(value: newValue, in: context)
                }
            } catch {
                context.currentError = JXValue(string: "\(error)", in: context)
            }
        }
    }
}

// MARK: Default Implementations

extension RawRepresentable where RawValue : Jackable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard let newSelf = Self(rawValue: try .makeJX(from: value, in: context)) else {
            throw JackError.rawInitializerFailed(value, .init(context: context))
        }
        return newSelf
    }

    public mutating func getJX(from context: JXContext) -> JXValue {
        var rv = self.rawValue
        return rv.getJX(from: context)
    }
}

public extension Jackable {
    mutating func setJX(value: JXValue, in context: JXContext) throws {
        self = try Self.makeJX(from: value, in: context)
    }
}

extension Bool : Jackable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard value.isBoolean else {
            throw JackError.valueWasNotABoolean(value, .init(context: context))
        }
        return value.booleanValue
    }

    public func getJX(from context: JXContext) -> JXValue {
        JXValue(bool: self, in: context)
    }
}

extension String : Jackable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard value.isString, let str = value.stringValue else {
            throw JackError.valueWasNotAString(value, .init(context: context))
        }
        return str
    }

    public func getJX(from context: JXContext) -> JXValue {
        JXValue(string: self, in: context)
    }
}

extension BinaryInteger where Self : _ExpressibleByBuiltinIntegerLiteral {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard let num = value.numberValue, !num.isNaN else {
            throw JackError.valueWasNotANumber(value, .init(context: context))
        }
        return .init(integerLiteral: .init(num))
    }

    public func getJX(from context: JXContext) -> JXValue {
        JXValue(double: Double(self), in: context)
    }
}

extension Int : Jackable { }
extension Int16 : Jackable { }
extension Int32 : Jackable { }
extension Int64 : Jackable { }
extension UInt : Jackable { }
extension UInt16 : Jackable { }
extension UInt32 : Jackable { }
extension UInt64 : Jackable { }

extension BinaryFloatingPoint where Self : ExpressibleByFloatLiteral {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard let num = value.numberValue else {
            throw JackError.valueWasNotANumber(value, .init(context: context))
        }
        return .init(num)
    }

    public func getJX(from context: JXContext) -> JXValue {
        JXValue(double: Double(self), in: context)
    }
}


extension Double : Jackable { }
extension Float : Jackable { }


extension Array : Jackable, Jumpable where Element : Jumpable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard value.isArray, let arrayValue = value.array else {
            throw JackError.valueNotArray(value, .init(context: context))
        }

        return try arrayValue.map({ jx in
            try Element.makeJX(from: jx, in: context)
        })
    }

    public mutating func getJX(from context: JXContext) -> JXValue {
        JXValue(newArrayIn: context, values: self.map({ x in
            var x = x
            return x.getJX(from: context)
        }))
    }

}


#if canImport(Foundation)
import struct Foundation.Date

extension Date : Jackable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard let date = value.dateValue else {
            throw JackError.valueWasNotADate(value, .init(context: context))
        }
        return date
    }

    public mutating func getJX(from context: JXContext) -> JXValue {
        JXValue(date: self, in: context)
    }
}
#endif


#if canImport(Foundation)
import struct Foundation.Data

@available(macOS 10.12, iOS 10.0, tvOS 10.0, *)
extension Data : Jackable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
//        if value.isArrayBuffer { // fast track
//            #warning("TODO: array buffer")
//            fatalError("array buffer") // TODO
//        } else
        if value.isArray { // slow track
            // copy the array manually
            let length = value["length"]

            guard length.isNumber, let count = length.numberValue, let max = Int(exactly: count) else {
                throw JackError.valueNotArray(value, .init(context: context))
            }

            let data: [UInt8] = try (0..<max).map { index in
                let element = value[index]
                guard element.isNumber, let num = element.numberValue else {
                    throw JackError.dataElementNotNumber(index, value, .init(context: context))
                }

                guard num <= .init(UInt8.max), num >= .init(UInt8.min), let byte = UInt8(exactly: num) else {
                    throw JackError.dataElementOutOfRange(index, value, .init(context: context))
                }

                return byte
            }

            return Data(data)
        } else {
            throw JackError.valueNotArray(value, .init(context: context))
        }
    }

    public mutating func getJX(from context: JXContext) -> JXValue {
        withUnsafeMutableBytes { bytes in
            JXValue(newArrayBufferWithBytesNoCopy: bytes,
                deallocator: { _ in
                    //print("buffer deallocated")
                },
                in: context)
        }
    }
}
#endif

