
public protocol JackPeerable : JXConvertible {
//    init()

    /// The corresponding peer object for this instance on the JavaScript side.
    var peer: JXValue? { get nonmutating set }
}

extension JackPeerable where Self : JackedObject {
    /// `JXConvertible` implementation for `JackedObject`,
    public static func fromJX(_ value: JXValue) throws -> Self {
        guard let obj = value.peer else {
            throw JackError.invalidReferenceContext(value, .init(context: value.context))
        }

        guard let jobj = obj as? Self else { // TODO: what if some already conveyed this to a different wrapper type?
            //print("bad type obj:", wip(obj), type(of: Self.self))
            throw JackError.invalidReferenceType(value, .init(context: value.context))
        }

        return jobj
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        if let obj = self.peer { // do we already have a counterpart on the JX side?
            return obj
        }

        let obj = context.object(peer: self) // create a new object in the context // TODO: should we set a class name on the type?
        try inject(into: obj)
        self.peer = obj
        return obj
    }
}

/// A `JackedReference` is a concrete base class implementation of `JackedObject`
/// that tracks the instance's native peer.
///
/// A `JackedReference` can only ever be associated with a single `JXContext`.
open class JackedReference : JackedObject, JackPeerable {
    /// The counterpart JXValue for a given context
    public weak var peer: JXValue? = nil

    public init() {
        
    }
}

