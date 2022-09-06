/// A ``Jackable`` instance can be passed back and forth to a ``JXContext`` through serialization.
public protocol Jackable {
    /// Converts this value into a JXContext
    func getJX(from context: JXContext) -> JXValue
    mutating func setJX(value: JXValue, in context: JXContext) throws
}

extension Bool : Jackable {
    public func getJX(from context: JXContext) -> JXValue {
        JXValue(bool: self, in: context)
    }

    public mutating func setJX(value: JXValue, in context: JXContext) throws {
        self = value.booleanValue
    }
}

extension String : Jackable {
    public func getJX(from context: JXContext) -> JXValue {
        JXValue(string: self, in: context)
    }

    public mutating func setJX(value: JXValue, in context: JXContext) throws {
        guard let str = value.stringValue else {
            throw JackableError.valueWasNotAString
        }
        self = str
    }
}

extension BinaryInteger where Self : _ExpressibleByBuiltinIntegerLiteral {
    public func getJX(from context: JXContext) -> JXValue {
        JXValue(double: Double(self), in: context)
    }

    public mutating func setJX(value: JXValue, in context: JXKit.JXContext) throws {
        guard let num = value.numberValue, !num.isNaN else {
            throw JackableError.valueWasNotANumber
        }
        self = .init(integerLiteral: .init(num))
    }
}

//extension BinaryFloatingPoint where Self : ExpressibleByFloatLiteral {
//    public func getJX(from context: JXContext) -> JXValue {
//        JXValue(double: Double(self), in: context)
//    }
//
//    mutating func setJX(value: JXValue, in context: JXContext) throws {
//        guard let num = value.numberValue else {
//            throw JackableError.valueWasNotANumber
//        }
//        self = .init(floatLiteral: .init(num))
//    }
//}

enum JackableError : Error {
    case valueWasNotANumber
    case valueWasNotAString
}

extension Int : Jackable { }
extension Int16 : Jackable { }
extension Int32 : Jackable { }
extension Int64 : Jackable { }
//extension Double : Jackable { }
//extension Float : Jackable { }

