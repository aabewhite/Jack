
/// A ``Jackable`` type can be passed efficiently back and forth to a ``JXContext`` without serialization.
public protocol Jackable {
    /// Create a new instance from the given value
    init(value: JXValue, in context: JXContext) throws

    /// Converts this value into a JXContext
    mutating func getJX(from context: JXContext) -> JXValue

    /// Sets the value of this property
    mutating func setJX(value: JXValue, in context: JXContext) throws

}

extension RawRepresentable where RawValue : Jackable {
    public init(value: JXValue, in context: JXContext) throws {
        guard let newSelf = Self(rawValue: try .init(value: value, in: context)) else {
            throw JackError.rawInitializerFailed(value, .init(context: context))
        }
        self = newSelf
    }

    public mutating func getJX(from context: JXContext) -> JXValue {
        var rv = self.rawValue
        return rv.getJX(from: context)
    }
}

public extension Jackable {
    mutating func setJX(value: JXValue, in context: JXContext) throws {
        self = try Self(value: value, in: context)
    }
}

extension Bool : Jackable {
    public init(value: JXValue, in context: JXContext) throws {
        guard value.isBoolean else {
            throw JackError.valueWasNotABoolean(value, .init(context: context))
        }
        self = value.booleanValue
    }

    public func getJX(from context: JXContext) -> JXValue {
        JXValue(bool: self, in: context)
    }
}

extension String : Jackable {
    public init(value: JXValue, in context: JXContext) throws {
        guard value.isString, let str = value.stringValue else {
            throw JackError.valueWasNotAString(value, .init(context: context))
        }
        self = str
    }

    public func getJX(from context: JXContext) -> JXValue {
        JXValue(string: self, in: context)
    }
}

extension BinaryInteger where Self : _ExpressibleByBuiltinIntegerLiteral {
    public init(value: JXValue, in context: JXContext) throws {
        guard let num = value.numberValue, !num.isNaN else {
            throw JackError.valueWasNotANumber(value, .init(context: context))
        }
        self = .init(integerLiteral: .init(num))
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
    public init(value: JXValue, in context: JXContext) throws {
        guard let num = value.numberValue else {
            throw JackError.valueWasNotANumber(value, .init(context: context))
        }
        self = .init(num)
    }

    public func getJX(from context: JXContext) -> JXValue {
        JXValue(double: Double(self), in: context)
    }
}


extension Double : Jackable { }
extension Float : Jackable { }


extension Array : Jackable where Element : Jackable {
    public init(value: JXValue, in context: JXContext) throws {
        guard value.isArray, let arrayValue = value.array else {
            throw JackError.valueNotArray(value, .init(context: context))
        }

        self = try arrayValue.map({ jx in
            try Element(value: jx, in: context)
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
    public init(value: JXValue, in context: JXContext) throws {
        guard let date = value.dateValue else {
            throw JackError.valueWasNotADate(value, .init(context: context))
        }
        self = date

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
    public init(value: JXValue, in context: JXContext) throws {
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

            self = Data(data)
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

