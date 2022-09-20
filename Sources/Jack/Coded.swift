import class Foundation.JSONEncoder
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

// MARK: Coded

/// A type that publishes a property marked with an attribute and exports that property to an associated ``JXContext``
/// by serializing the codable type.
///
/// Publishing a property with the `@Coded` attribute creates a publisher of this
/// type. You access the publisher with the `$` operator, as with ``Jacked``.
///
@available(macOS 11, iOS 13, tvOS 13, *)
@propertyWrapper
public struct Coded<Value : Codable> : _TrackableProperty {
    /// The key that will be used to export the instance; a nil key will prevent export.
    internal let key: String?

    /// The key that will be used to export the instance; a nil key will prevent export.
    internal let encoder: JSONEncoder

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
    /// the `@Jacked` attribute, as shown here:
    ///
    ///     @Jacked var lastUpdated: Date = Date()
    ///
    /// - Parameter wrappedValue: The publisher's initial value.
    public init(initialValue: Value, _ key: String? = nil, encoder: JSONEncoder? = nil) {
        self.init(wrappedValue: initialValue, key, encoder: encoder)
    }

    /// Creates the published instance with an initial value.
    ///
    /// Don't use this initializer directly. Instead, create a property with
    /// the `@Jacked` attribute, as shown here:
    ///
    ///     @Jacked var lastUpdated: Date = Date()
    ///
    /// - Parameter initialValue: The publisher's initial value.
    public init(wrappedValue: Value, _ key: String? = nil, encoder: JSONEncoder? = nil) {
        _storage = Box(wrappedValue: .value(wrappedValue))
        self.key = key
        self.encoder = encoder ?? defaultEncoder
    }

    /// The property for which this instance exposes a publisher.
    ///
    /// The `projectedValue` is the property accessed with the `$` operator.
    public var projectedValue: JackPublisher<Value> {
        mutating get {
            return getPublisher()
        }
        set { // swiftlint:disable:this unused_setter_value
            switch storage {
            case .value(let value):
                storage = .publisher(JackPublisher(value))
            case .publisher:
                break
            }
        }
    }

    /// Note: This method can mutate `storage`
    fileprivate func getPublisher() -> JackPublisher<Value> {
        switch storage {
        case .value(let value):
            let publisher = JackPublisher(value)
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
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Coded<Value>>
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
                object[keyPath: storageKeyPath].storage = .publisher(JackPublisher(newValue))
            case .publisher(let publisher):
                publisher.subject.value = newValue
            }
        }
    }
}


/// The shared default encoder for `Coded` types
@available(macOS 11, iOS 13, tvOS 13, *)
private let defaultEncoder : JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()


// This is similar to the OpenCombine implementation except we handle both `*Combine.Published` and `Jack.Jacked`

@available(macOS 11, iOS 13, tvOS 13, *)
extension Coded : _JackableProperty {
    var exportedKey: String? { key }

    subscript(in context: JXContext, owner: AnyObject?) -> JXValue {
        get throws {
            switch _storage.wrappedValue {
            case .value(let value):
                return try context.encode(value)
            case .publisher(let publisher):
                return try context.encode(publisher.subject.value)
            }
        }
    }

    func setValue(_ newValue: JXValue, in context: JXContext, owner: AnyObject?) throws {
        switch _storage.wrappedValue {
        case .value(_):
            storage = .publisher(JackPublisher(try newValue.toDecodable(ofType: Value.self)))
        case .publisher(let publisher):
            publisher.subject.value = try newValue.toDecodable(ofType: Value.self)
        }
    }
}
