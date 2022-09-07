import OpenCombineShim

/// A publisher for properties marked with the `@Jacked` attribute.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
public struct JackedPublisher<Value>: Publisher {
    public typealias Output = Value
    public typealias Failure = Never
    internal let subject: JackedSubject<Value>

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Value, Downstream.Failure == Never
    {
        subject.subscribe(subscriber)
    }

    internal init(_ output: Output) {
        subject = .init(output)
    }

    enum Storage {
        case value(Value)
        case publisher(JackedPublisher)
    }
}
