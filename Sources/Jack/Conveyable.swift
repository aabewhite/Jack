
/// A type that can move back and forth between Swift and JavaScipt, either through direct reference or by serialization.
///
/// In order to export Swift properties to the JS context, the types must conform to ``Conveyable``.`
@available(macOS 11, iOS 13, tvOS 13, *)
public protocol Conveyable {
    /// Converts this value into a JXContext
    static func makeJX(from value: JXValue, in context: JXContext) throws -> Self

    /// Converts this value into a JXContext
    func getJX(from context: JXContext) throws -> JXValue
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {
    /// Attempts to convey the given result from the JS environment.
    /// - Parameter context: the context to use
    /// - Returns: the conveyed instance
    public func convey<T : Conveyable>(in context: JXContext) throws -> T {
        try T.makeJX(from: self, in: context)
    }
}

/// Default implementation of ``Conveyable`` will be to encode and decode ``Codable`` instances between Swift & JS
@available(macOS 11, iOS 13, tvOS 13, *)
extension Conveyable where Self : Codable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        try value.toDecodable(ofType: Self.self)
    }

    public func getJX(from context: JXContext) throws -> JXValue {
        try context.encode(self)
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue : Conveyable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard let value = value as? Self else {
            throw JackError.jumpContextInvalid(.init(context: context))
        }
        return value
    }

    /// Converts this value into a JXContext
    public func getJX(from context: JXContext) -> JXValue {
        self
    }
}
