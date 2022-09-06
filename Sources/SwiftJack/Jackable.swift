
/// A ``Jackable`` type can be passed efficiently back and forth to a ``JXContext`` without serialization.
public protocol Jackable {
    /// Converts this value into a JXContext
    mutating func getJX(from context: JXContext) -> JXValue

    /// Sets the value of this property
    mutating func setJX(value: JXValue, in context: JXContext) throws
}

extension RawRepresentable where RawValue : Jackable {
    public mutating func getJX(from context: JXContext) -> JXValue {
        var rv = self.rawValue
        return rv.getJX(from: context)
    }

    public mutating func setJX(value: JXValue, in context: JXContext) throws {
        var rv = self.rawValue
        try rv.setJX(value: value, in: context)
        guard let newSelf = Self(rawValue: rv) else {
            throw JackError.rawInitializerFailed(value, JackError.Context(context: context))
        }
        self = newSelf
    }
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
            throw JackError.valueWasNotAString
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
            throw JackError.valueWasNotANumber
        }
        self = .init(integerLiteral: .init(num))
    }
}

extension BinaryFloatingPoint where Self : ExpressibleByFloatLiteral {
    public func getJX(from context: JXContext) -> JXValue {
        JXValue(double: Double(self), in: context)
    }

    public mutating func setJX(value: JXValue, in context: JXContext) throws {
        guard let num = value.numberValue else {
            throw JackError.valueWasNotANumber
        }
        self = .init(num)
    }
}


extension Int : Jackable { }
extension Int16 : Jackable { }
extension Int32 : Jackable { }
extension Int64 : Jackable { }
extension Double : Jackable { }
extension Float : Jackable { }

#if canImport(Foundation)
import struct Foundation.Data

extension Data : Jackable {
    public mutating func getJX(from context: JXContext) -> JXValue {
        withUnsafeMutableBytes { bytes in
            JXValue(newArrayBufferWithBytesNoCopy: bytes,
                deallocator: { _ in
                    //print("buffer deallocated")
                },
                in: context)
        }
    }

    public mutating func setJX(value: JXValue, in context: JXContext) throws {
        if value.isArrayBuffer { // fast track
            fatalError("array buffer")
        } else if value.isArray { // slow track
            // copy the array manually
            let length = value["length"]

            guard length.isNumber, let count = length.numberValue, let max = Int(exactly: count) else {
                throw JackError.valueNotArray(value, JackError.Context(context: context))
            }

            let data: [UInt8] = try (0..<max).map { index in
                let element = value[index]
                guard element.isNumber, let num = element.numberValue else {
                    throw JackError.dataElementNotNumber(index, value, JackError.Context(context: context))
                }

                guard num <= .init(UInt8.max), num >= .init(UInt8.min), let byte = UInt8(exactly: num) else {
                    throw JackError.dataElementOutOfRange(index, value, JackError.Context(context: context))
                }

                return byte
            }

            self = Data(data)
        } else {
            throw JackError.valueNotArray(value, JackError.Context(context: context))
        }
    }
}
#endif

