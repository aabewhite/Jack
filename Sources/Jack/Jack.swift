@_exported import JXKit

#if canImport(Combine)
import Combine
/// A type alias for the Combine framework’s type for an object with a publisher that emits before the object has changed.
public typealias ObservableObject = Combine.ObservableObject
/// A type alias for the Combine framework’s type that publishes a property marked with an attribute.
public typealias Published = Combine.Published
#else
import OpenCombine
/// A type alias for the Combine framework’s type for an object with a publisher that emits before the object has changed.
public typealias ObservableObject = OpenCombine.ObservableObject
/// A type alias for the Combine framework’s type that publishes a property marked with an attribute.
public typealias Published = OpenCombine.Published
#if canImport(OpenCombineDispatch)
import OpenCombineDispatch
#endif
#if canImport(OpenCombineFoundation)
import OpenCombineFoundation
#endif
#endif

import Dispatch

/// A publisher for properties marked with the `@Jacked` attribute.
public struct JackPublisher<Value>: Publisher {
    public typealias Output = Value
    public typealias Failure = Never
    internal let subject: JackedSubject<Value>

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Value, Downstream.Failure == Never
    {
        subject.subscribe(subscriber)
    }

    internal init(_ output: Output, queue: DispatchQueue?) {
        subject = .init(output, queue: queue)
    }

    enum Storage {
        case value(Value)
        case publisher(JackPublisher)
    }
}

public enum JackError : Error {
    /// The context in which the error occurred.
    public struct Context {
        /// A description of what went wrong, for debugging purposes.
        //public let debugDescription: String

        /// The underlying error which caused this error, if any.
        //public let underlyingError: Error?

        public let context: JXContext
        public init(context: JXContext) {
            self.context = context
        }
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

    /// Functions can only be initialized from the Swift side and cannot be changed.
    case functionPropertyReadOnly(_ value: JXValue, Context)

    /// A `JXValue` mapped to a `JackedObject` could not be found.
    case invalidReferenceContext(_ value: JXValue, Context)

    /// A `JXValue` mapped to a `JackedObject` was of the wrong type.
    case invalidReferenceType(_ value: JXValue, Context)
}


/// Work-in-Progress marker
@available(*, deprecated, message: "work in progress")
@inlinable internal func wip<T>(_ value: T) -> T { value }
