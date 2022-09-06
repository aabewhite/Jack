@_exported import JXKit

public struct SwiftJackModule {
    public static let version = "1.0.0"
    public var swiftJackName = "SwiftJack"

    public static let shared = Self()
}

public enum JackError : Error {
    /// The context in which the error occurred.
    public struct Context {
        /// A description of what went wrong, for debugging purposes.
        //public let debugDescription: String

        /// The underlying error which caused this error, if any.
        //public let underlyingError: Error?

        public let context: JXContext
    }

    /// An indication that a value of the given type could not be decoded because
    /// it did not match the type of what was found in the encoded payload.
    ///
    /// As associated values, this case contains the attempted type and context
    /// for debugging.

    case valueWasNotANumber(_ value: JXValue, Context)
    case valueWasNotAString(_ value: JXValue, Context)
    case valueWasNotABoolean(_ value: JXValue, Context)
    case valueWasNotADate(_ value: JXValue, Context)

    /// Tried to set a raw value but couldn't initialize
    case rawInitializerFailed(_ value: JXValue, Context)

    /// Expected an array or an array buffer
    case valueNotArray(_ value: JXValue, Context)

    case dataElementNotNumber(_ index: Int, _ value: JXValue, Context)

    case dataElementOutOfRange(_ index: Int, _ value: JXValue, Context)


}


/// Work-in-Progress marker
@available(*, deprecated, message: "work in progress")
@inlinable internal func wip<T>(_ value: T) -> T { value }
