import OpenCombineShim
import class Foundation.JSONEncoder

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
@propertyWrapper
public struct JackedCodable<Value : Codable> {
    /// The key that will be used to export the instance; a nil key will prevent export.
    internal let key: String?

    /// The key that will be used to export the instance; a nil key will prevent export.
    internal let encoder: JSONEncoder

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
    @available(*, unavailable, message: "@Jacked is only available on properties of classes")
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() } // swiftlint:disable:this unused_setter_value
    }
    // swiftlint:enable let_var_whitespace

    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, JackedCodable<Value>>
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


/// The shared default encoder for `JackedCodable` types
@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
private let defaultEncoder : JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()


// This is similar to the OpenCombine implementation except we handle both `*Combine.Published` and `SwiftJack.Jacked`

@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
extension JackedCodable : _JackableProperty where Value : Codable {
    var exportedKey: String? { key }

    subscript(in context: JXContext) -> JXValue {
        get {
            do {
                switch _storage.wrappedValue {
                case .value(let value):
                    return try context.encode(value)
                case .publisher(let publisher):
                    return try context.encode(publisher.subject.value)
                }
            } catch {
                return JXValue(newErrorFromMessage: "\(error)", in: wip(context))
            }
        }

        nonmutating set {
            do {
                switch _storage.wrappedValue {
                case .value(let value):
                    fatalError(wip("how to decode the value"))
                case .publisher(let publisher):
                    fatalError(wip("how to decode the value"))
                }
            } catch {
                context.currentError = JXValue(string: "\(error)", in: context)
            }
        }
    }
}


