import Jack

import struct Foundation.URL
import struct Foundation.CharacterSet

#if canImport(CoreGraphics)

#endif

// MARK: CanvasPod

@available(macOS 11, iOS 13, tvOS 13, *)
public protocol CanvasPod : JackPod {
}

@available(macOS 11, iOS 13, tvOS 13, *)
open class AbstractCanvasPod : CanvasPod {
    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    @Jacked open var width: Double = 1
    @Jacked open var height: Double = 1

    @Jacked open var fillStyle: String = "#000"
    @Jacked open var strokeStyle: String = "#000"

    /// The current text style to use when drawing text. This string uses the same syntax as the CSS font specifier.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/font)
    @Jacked open var font: String = "10px sans-serif"

    /// The current text alignment used when drawing text.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/textAlign)
    @Jacked open var textAlign: String = "start"

    /// The current text baseline used when drawing text.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/textBaseline)
    @Jacked open var textBaseline: String = "alphabetic"

    /// The shape used to draw the end points of lines.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/lineCap)
    @Jacked open var lineCap: String = "butt"

    /// Sets the line dash offset, or "phase."
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/lineDashOffset)
    @Jacked open var lineDashOffset: Double = 0.0

    /// The shape used to join two line segments where they meet.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/lineJoin)
    @Jacked open var lineJoin: String = "miter"

    /// The thickness of lines.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/lineWidth)
    @Jacked open var lineWidth: Double = 1.0

    /// The miter limit ratio.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/miterLimit)
    @Jacked open var miterLimit: Double = 10.0

    /// The amount of blur applied to shadows.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/shadowBlur)
    @Jacked open var shadowBlur: Double = 0

    /// The color of shadows
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/shadowColor)
    @Jacked open var shadowColor: String = "rgba(0, 0, 0, 0)" // WebKit's version of: "The default value is fully-transparent black"

    /// The distance that shadows will be offset horizontally.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/shadowOffsetX)
    @Jacked open var shadowOffsetX: Double = 0

    /// The distance that shadows will be offset vertically.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/shadowOffsetY)
    @Jacked open var shadowOffsetY: Double = 0

    /// The alpha (transparency) value that is applied to shapes and images before they are drawn onto the canvas.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/globalAlpha)
    @Jacked open var globalAlpha: Double = 1.0

    /// The type of compositing operation to apply when drawing new shapes.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/globalCompositeOperation)
    @Jacked open var globalCompositeOperation: String = "source-over"

    /// The imageSmoothingEnabled property of the CanvasRenderingContext2D interface, part of the Canvas API, determines whether scaled images are smoothed (true, default) or not (false). On getting the imageSmoothingEnabled property, the last value it was set to is returned.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/imageSmoothingEnabled)
    @Jacked open var imageSmoothingEnabled: Bool = true

    public lazy var pod = jack()

    public init() {
    }

    /// Returns a TextMetrics object that contains information about the measured text (such as its width, for example).
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/measureText)
    @Jumped("measureText") private var _measureText = measureText
    open func measureText(value: String) -> TextMetrics? {
        /// Text measurement merely returns the number of characters in the text multiplied by the font size
        // naïve font size parsing: just grab the first numbers in the font string
        let fontSize = font
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first.flatMap(Double.init)
        let factor = 0.8
        return TextMetrics(width: (fontSize ?? 0) * Double(value.count) * factor)
    }

    /// A structure describing text measurments.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/TextMetrics)
    public struct TextMetrics : Codable, Equatable, Conveyable {
        /// TextMetrics.width Read only
        /// Is a double giving the calculated width of a segment of inline text in CSS pixels. It takes into account the current font of the context.
        public var width: Double

        /// TextMetrics.actualBoundingBoxLeft Read only
        /// Is a double giving the distance from the alignment point given by the CanvasRenderingContext2D.textAlign property to the left side of the bounding rectangle of the given text, in CSS pixels. The distance is measured parallel to the baseline.
        public var actualBoundingBoxLeft: Double?

        /// TextMetrics.actualBoundingBoxRight Read only
        /// Is a double giving the distance from the alignment point given by the CanvasRenderingContext2D.textAlign property to the right side of the bounding rectangle of the given text, in CSS pixels. The distance is measured parallel to the baseline.
        public var actualBoundingBoxRight: Double?

        /// TextMetrics.fontBoundingBoxAscent Read only
        /// Is a double giving the distance from the horizontal line indicated by the CanvasRenderingContext2D.textBaseline attribute to the top of the highest bounding rectangle of all the fonts used to render the text, in CSS pixels.
        public var fontBoundingBoxAscent: Double?

        /// TextMetrics.fontBoundingBoxDescent Read only
        /// Is a double giving the distance from the horizontal line indicated by the CanvasRenderingContext2D.textBaseline attribute to the bottom of the bounding rectangle of all the fonts used to render the text, in CSS pixels.
        public var fontBoundingBoxDescent: Double?

        /// TextMetrics.actualBoundingBoxAscent Read only
        /// Is a double giving the distance from the horizontal line indicated by the CanvasRenderingContext2D.textBaseline attribute to the top of the bounding rectangle used to render the text, in CSS pixels.
        public var actualBoundingBoxAscent: Double?

        /// TextMetrics.actualBoundingBoxDescent Read only
        /// Is a double giving the distance from the horizontal line indicated by the CanvasRenderingContext2D.textBaseline attribute to the bottom of the bounding rectangle used to render the text, in CSS pixels.
        public var actualBoundingBoxDescent: Double?

        /// TextMetrics.emHeightAscent Read only
        /// Is a double giving the distance from the horizontal line indicated by the CanvasRenderingContext2D.textBaseline property to the top of the em square in the line box, in CSS pixels.
        public var emHeightAscent: Double?

        /// TextMetrics.emHeightDescent Read only
        /// Is a double giving the distance from the horizontal line indicated by the CanvasRenderingContext2D.textBaseline property to the bottom of the em square in the line box, in CSS pixels.
        public var emHeightDescent: Double?

        /// TextMetrics.hangingBaseline Read only
        /// Is a double giving the distance from the horizontal line indicated by the CanvasRenderingContext2D.textBaseline property to the hanging baseline of the line box, in CSS pixels.
        public var hangingBaseline: Double?

        /// TextMetrics.alphabeticBaseline Read only
        /// Is a double giving the distance from the horizontal line indicated by the CanvasRenderingContext2D.textBaseline property to the alphabetic baseline of the line box, in CSS pixels.
        public var alphabeticBaseline: Double?

        /// TextMetrics.ideographicBaseline Read only
        /// Is a double giving the distance from the horizontal line indicated by the CanvasRenderingContext2D.textBaseline property to the ideographic baseline of the line box, in CSS pixels.
        public var ideographicBaseline: Double?

        public init(width: Double, actualBoundingBoxLeft: Double? = nil, actualBoundingBoxRight: Double? = nil, fontBoundingBoxAscent: Double? = nil, fontBoundingBoxDescent: Double? = nil, actualBoundingBoxAscent: Double? = nil, actualBoundingBoxDescent: Double? = nil, emHeightAscent: Double? = nil, emHeightDescent: Double? = nil, hangingBaseline: Double? = nil, alphabeticBaseline: Double? = nil, ideographicBaseline: Double? = nil) {
            self.width = width
            self.actualBoundingBoxLeft = actualBoundingBoxLeft
            self.actualBoundingBoxRight = actualBoundingBoxRight
            self.fontBoundingBoxAscent = fontBoundingBoxAscent
            self.fontBoundingBoxDescent = fontBoundingBoxDescent
            self.actualBoundingBoxAscent = actualBoundingBoxAscent
            self.actualBoundingBoxDescent = actualBoundingBoxDescent
            self.emHeightAscent = emHeightAscent
            self.emHeightDescent = emHeightDescent
            self.hangingBaseline = hangingBaseline
            self.alphabeticBaseline = alphabeticBaseline
            self.ideographicBaseline = ideographicBaseline
        }
    }
}


/// The CanvasGradient interface represents an opaque object describing a gradient. It is returned by the methods CanvasRenderingContext2D.createLinearGradient() or CanvasRenderingContext2D.createRadialGradient().
///
/// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasGradient)
public struct CanvasGradientAPI : Codable, Conveyable {
    /// adds a new color stop, defined by an offset and a color, to a given canvas gradient.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasGradient/addColorStop)
    //func addColorStop(offset: Double, color: String)
}

public struct CanvasPatternAPI : Codable, Conveyable {
    /// Applies an SVGMatrix or DOMMatrix representing a linear transform to the pattern
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasPattern/setTransform)
    //func setTransform(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double)
}

public struct ImageDataAPI : Codable, Conveyable {
}

public struct CanvasRenderingContext2DSettingsAPI : Codable, Conveyable {
}

/// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/DOMMatrix)
public struct DOMMatrixAPI : Codable, Conveyable {
}


#if canImport(CoreGraphics)
import CoreGraphics

import class Foundation.NSAttributedString
import func CoreText.CTLineDraw
import func CoreText.CTLineCreateWithAttributedString

//@available(*, deprecated, message: "TODO")
func wipcanvas<T>(_ value: T) -> T { value }

//@available(*, deprecated, message: "TODO")
func wipgrad<T>(_ value: T) -> T { value }


@available(macOS 11, iOS 13, tvOS 13, *)
public class CoreGraphicsCanvasPod : AbstractCanvasPod {
    private let ctx: CGContext

    /// The background color to draw for `clearRect`
    open var backgroundColor: CGColor?

    /// The size of the canvas
    public var size: CGSize {
        didSet {
            // every time we change the size, re-apply the transform to fix Quartz's flipped coordinate system
            resetTransform()
        }
    }

    /// The width of the canvas
    public override var width: Double {
        get {
            Double(size.width)
        }

        set {
            size.width = CGFloat(size.width)
        }
    }

    /// The height of the canvas
    public override var height: Double {
        get {
            Double(size.height)
        }

        set {
            size.height = CGFloat(size.height)
        }
    }

    /// Creates a pod that wraps the given context.
    /// - Parameters:
    ///   - context: the context to use
    ///   - size: the size of the drawing canvas
    public required init(context: CGContext, size: CGSize) {
        self.ctx = context
        self.size = size
    }

    /// The transform for flipping along the Y axis
    private func flippedYTransform() -> CGAffineTransform {
        #if os(macOS)
        return CGAffineTransform.identity.translatedBy(x: 0, y: .init(self.size.height))
            .scaledBy(x: 1, y: -1)
        #else
        return CGAffineTransform.identity
        #endif
    }

    /// Flip vertical since Quartz coordinates have origin at lower-left
    private func resetTransform() {
        ctx.concatenate(ctx.ctm.inverted()) // revert to the identity so we can apply the transform…
        ctx.concatenate(flippedYTransform()) // …then flip the image so the origin is what Canvas2D expects
    }

    open override var lineCap: String {
        didSet {
            switch lineCap {
            case "butt": ctx.setLineCap(.butt)
            case "round": ctx.setLineCap(.round)
            case "square": ctx.setLineCap(.square)
            default: break
            }
        }
    }

    open override var lineJoin: String {
        didSet {
            switch lineJoin {
            case "bevel": ctx.setLineJoin(.bevel)
            case "round": ctx.setLineJoin(.round)
            case "miter": ctx.setLineJoin(.miter)
            default: break
            }
        }
    }

    open override var lineWidth: Double {
        didSet {
            ctx.setLineWidth(.init(lineWidth))
        }
    }

    private var lineDashInfo: (segments: [Double], offset: Double) = ([], 0) {
        didSet {
            ctx.setLineDash(phase: .init(lineDashInfo.offset), lengths: lineDashInfo.segments.map({ .init($0) }))
        }
    }

    open override var lineDashOffset: Double {
        get { lineDashInfo.offset }
        set { lineDashInfo.offset = newValue }
    }

    @Jumped("setLineDash") private var _setLineDash = setLineDash
    public func setLineDash(segments: [Double]) {
        lineDashInfo.segments = segments
    }

    @Jumped("getLineDash") private var _getLineDash = getLineDash
    public func getLineDash() -> [Double] {
        lineDashInfo.segments
    }

    open override var miterLimit: Double {
        didSet {
            ctx.setMiterLimit(.init(miterLimit))
        }
    }

    open override var globalAlpha: Double {
        didSet {
            ctx.setAlpha(.init(globalAlpha))
        }
    }

    open override var globalCompositeOperation: String {
        didSet {
            switch globalCompositeOperation {
            case "source-over": ctx.setBlendMode(.normal) // "source over" mode is called `kCGBlendModeNormal'
            case "source-in": ctx.setBlendMode(.sourceIn)
            case "source-out": ctx.setBlendMode(.sourceOut)
            case "source-atop": ctx.setBlendMode(.sourceAtop)
            case "destination-over": ctx.setBlendMode(.destinationOver)
            case "destination-in": ctx.setBlendMode(.destinationIn)
            case "destination-out": ctx.setBlendMode(.destinationOut)
            case "destination-atop": ctx.setBlendMode(.destinationAtop)
            case "lighter": ctx.setBlendMode(.lighten)
            case "copy": ctx.setBlendMode(.copy)
            case "xor": ctx.setBlendMode(.xor)
            case "multiply": ctx.setBlendMode(.multiply)
            case "screen": ctx.setBlendMode(.screen)
            case "overlay": ctx.setBlendMode(.overlay)
            case "darken": ctx.setBlendMode(.darken)
            case "lighten": ctx.setBlendMode(.lighten)
            case "color-dodge": ctx.setBlendMode(.colorDodge)
            case "color-burn": ctx.setBlendMode(.colorBurn)
            case "hard-light": ctx.setBlendMode(.hardLight)
            case "soft-light": ctx.setBlendMode(.softLight)
            case "difference": ctx.setBlendMode(.difference)
            case "exclusion": ctx.setBlendMode(.exclusion)
            case "hue": ctx.setBlendMode(.hue)
            case "saturation": ctx.setBlendMode(.saturation)
            case "color": ctx.setBlendMode(.color)
            case "luminosity": ctx.setBlendMode(.luminosity)
            default: break
            }
        }
    }

    /// The color, gradient, or pattern to use inside shapes.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/fillStyle)
    open override var fillStyle: String {
        didSet {
            let _ = wipcanvas("TODO: CSS parsing")
//            if let color = CSS.parseColorStyle(css: fillStyle) {
//                ctx.setFillColor(color)
//            } else {
//                ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
//            }
        }
    }

    /// The color, gradient, or pattern to use for the strokes (outlines) around shapes.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/strokeStyle)
    open override var strokeStyle: String {
        didSet {
            let _ = wipcanvas("TODO: CSS parsing")
//            if let color = CSS.parseColorStyle(css: strokeStyle) {
//                ctx.setStrokeColor(color)
//            } else {
//                ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
//            }
        }
    }

    @Jumped("beginPath") var _beginPath = beginPath
    public func beginPath() {
        ctx.beginPath()
    }

    @Jumped("closePath") var _closePath = closePath
    public func closePath() {
        ctx.closePath()
    }

    @Jumped("rect") private var _rect = rect
    public func rect(x: Double, y: Double, w: Double, h: Double) {
        ctx.addRect(CGRect(x: x, y: y, width: w, height: h))
    }

    @Jumped("fillRect") private var _fillRect = fillRect
    public func fillRect(x: Double, y: Double, w: Double, h: Double) {
        ctx.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    @Jumped("stroke") private var _stroke = stroke
    public func stroke() {
        // restore afterwards because “The current path is cleared as a side effect of calling this function"
        continuingPath {
            ctx.strokePath()
        }
    }

    @Jumped("fill") private var _fill = fill
    public func fill() {
        // restore afterwards because “After filling the path, this method clears the context’s current path.”
        continuingPath {
            // fillStyle can be a color, gradient or pattern (unsupported)
//            if let gradient = self.fillStyle as? CanvasGradientAPI {
//                restoringContext {
//                    //gradient.fill(context: ctx)
//                    let _ = wipcanvas("TODO: gradient fill")
//                }
//            } else {
                ctx.fillPath()
//            }
        }
    }

    @Jumped("save") private var _save = save
    public func save() {
        ctx.saveGState()
    }

    @Jumped("restore") private var _restore = restore
    public func restore() {
        ctx.restoreGState()
    }

    @Jumped("clip") private var _clip = clip
    public func clip() {
        ctx.clip()
    }

    @Jumped("clearRect") private var _clearRect = clearRect
    public func clearRect(x: Double, y: Double, w: Double, h: Double) {
        // When this is a PDF context it draws a black background because: “If the provided context is a window or bitmap context, Core Graphics clears the rectangle. For other context types, Core Graphics fills the rectangle in a device-dependent manner. However, you should not use this function in contexts other than window or bitmap contexts.”
        // ctx.clear(.init(x: x, y: y, width: w, height: h))
        self.restoringContext {
            if let backgroundColor = self.backgroundColor {
                ctx.setFillColor(backgroundColor)
                ctx.fill(.init(x: x, y: y, width: w, height: h))
            } else {
                ctx.clear(CGRect(x: x, y: y, width: w, height: h))
            }
        }
    }

    @Jumped("moveTo") private var _moveTo = moveTo
    public func moveTo(x: Double, y: Double) {
        ctx.move(to: CGPoint(x: x, y: y))
    }

    @Jumped("lineTo") private var _lineTo = lineTo
    public func lineTo(x: Double, y: Double) {
        ctx.addLine(to: CGPoint(x: x, y: y))
    }

    @Jumped("strokeRect") private var _strokeRect = strokeRect
    public func strokeRect(x: Double, y: Double, width: Double, height: Double) {
        ctx.stroke(CGRect(x: x, y: y, width: width, height: height))
    }

    @Jumped("quadraticCurveTo") private var _quadraticCurveTo = quadraticCurveTo
    public func quadraticCurveTo(cpx: Double, cpy: Double, x: Double, y: Double) {
        ctx.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cpx, y: cpy))
    }

    @Jumped("bezierCurveTo") private var _bezierCurveTo = bezierCurveTo
    public func bezierCurveTo(cp1x: Double, cp1y: Double, cp2x: Double, cp2y: Double, x: Double, y: Double) {
        ctx.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: cp1x, y: cp1y), control2: CGPoint(x: cp2x, y: cp2y))
    }

    @Jumped("arc") private var _arc = arc
    public func arc(x: Double, y: Double, radius: Double, startAngle: Double, endAngle: Double, anticlockwise: Bool) {
        ctx.addArc(center: CGPoint(x: x, y: y), radius: CGFloat(radius), startAngle: CGFloat(startAngle), endAngle: CGFloat(endAngle), clockwise: !anticlockwise) // anti-anticlockwise
    }

    @Jumped("arcTo") private var _arcTo = arcTo
    public func arcTo(x1: Double, y1: Double, x2: Double, y2: Double, radius: Double) {
        ctx.addArc(tangent1End: CGPoint(x: x1, y: y1), tangent2End: CGPoint(x: x2, y: y2), radius: CGFloat(radius))
    }

    @Jumped("rotate") private var _rotate = rotate
    public func rotate(angle: Double) {
        ctx.rotate(by: CGFloat(angle))
    }

    @Jumped("translate") private var _translate = translate
    public func translate(x: Double, y: Double) {
        ctx.translateBy(x: CGFloat(x), y: CGFloat(y))
    }

    @Jumped("transform") private var _transform = transform
    public func transform(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double) {
        ctx.concatenate(CGAffineTransform(a: CGFloat(a), b: CGFloat(b), c: CGFloat(c), d: CGFloat(d), tx: CGFloat(e), ty: CGFloat(f)))
    }

    @Jumped("isPointInPath") private var _isPointInPath = isPointInPath
    public func isPointInPath(x: Double, y: Double) -> Bool {
        #if os(macOS)
        // TODO: CGContextGetCTM
        #endif
        return ctx.pathContains(CGPoint(x: x, y: y), mode: .fill)
    }

    @Jumped("isPointInStroke") private var _isPointInStroke = isPointInStroke
    public func isPointInStroke(x: Double, y: Double) -> Bool {
        ctx.pathContains(CGPoint(x: x, y: y), mode: .stroke)
    }

    /// Resets (overrides) the current transformation to the identity matrix, and then invokes a transformation described by the arguments of this method.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/setTransform)
    @Jumped("setTransform") private var _setTransform = setTransform
    public func setTransform(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double) {
        resetTransform() // restore the identity (flipped) transform…
        transform(CGFloat(a), CGFloat(b), CGFloat(c), CGFloat(d), CGFloat(e), CGFloat(f)) // …then apply the new transform
    }

    /// Multiplies the current transformation with the matrix described by the arguments of this method.
    ///
    /// See: [MDN](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/transform)
    func transform(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat, _ e: CGFloat, _ f: CGFloat) {
        ctx.concatenate(CGAffineTransform(a: a, b: b, c: c, d: d, tx: e, ty: f))
    }

    public func drawFocusIfNeeded(path: Any, element: Any) {
        // focus drawing not supported
    }

    @Jumped("getTransform") private var _getTransform = getTransform
    public func getTransform() -> DOMMatrixAPI? {
        wipcanvas(nil)
    }

    @Jumped("scale") private var _scale = scale
    public func scale(x: Double, y: Double) {
        wipcanvas(())
    }

    @Jumped("measureText") private var _measureText = measureText
    public override func measureText(value: String) -> AbstractCanvasPod.TextMetrics? {
        let astr = NSAttributedString(string: value, attributes: self.textAttributes(stroke: false))
        return AbstractCanvasPod.TextMetrics(width: .init(astr.size().width))
    }

    @Jumped("fillText") private var _fillText = fillText
    public func fillText(text: String, x: Double, y: Double, maxWidth: Double) {
        renderText(mode: .fill, text, x, y, maxWidth)
    }

    @Jumped("strokeText") private var _strokeText = strokeText
    public func strokeText(text: String, x: Double, y: Double, maxWidth: Double) {
        renderText(mode: .stroke, text, x, y, maxWidth)
    }

    private func renderText(mode: CGTextDrawingMode, _ text: String, _ x: Double, _ y: Double, _ maxWidth: Double) {
        restoringContext {
            self.ctx.concatenate(flippedYTransform().inverted()) // flip back…
            var position = CGPoint(x: x, y: y).applying(flippedYTransform()) // …and re-apply transform to origin
            let astr = NSAttributedString(string: text, attributes: self.textAttributes(stroke: mode == .stroke))
            let width = astr.size().width

            switch self.textAlign {
            case "left": break // nothing to do
            case "center": position.x -= width / 2
            case "right": position.x -= width
            default: break
            }

            self.ctx.textPosition = position
            self.ctx.setTextDrawingMode(mode)
            let line = CTLineCreateWithAttributedString(astr)
            CTLineDraw(line, self.ctx)
        }
    }

    /// Returns the current text attributes for drawing text
    func textAttributes(stroke: Bool? = nil) -> [NSAttributedString.Key: NSObject] {
        var attrs: [NSAttributedString.Key: NSObject] = [:]
        attrs.removeAll()
        let _ = wipcanvas("need CSS")
//        if let font = CSS.parseFontStyle(css: self.font) {
//            attrs[NSAttributedString.Key.font] = font
//        }

        return attrs
    }

    @Jumped("ellipse") private var _ellipse = ellipse
    public func ellipse(x: Double, y: Double, radiusX: Double, radiusY: Double, rotation: Double, startAngle: Double, endAngle: Double) {
        //ctx.addEllipse(in: <#T##CGRect#>)
        wipcanvas(())
    }

    @Jumped("createLinearGradient") private var _createLinearGradient = createLinearGradient
    public func createLinearGradient(x0: Double, y0: Double, x1: Double, y1: Double) -> CanvasGradientAPI? {
        wipcanvas(nil)
    }

    @Jumped("createConicGradient") private var _createConicGradient = createConicGradient
    public func createConicGradient(startAngle: Double, x: Double, y: Double) -> CanvasGradientAPI? {
        wipcanvas(nil)
    }

    @Jumped("createPattern") private var _createPattern = createPattern
    public func createPattern(image: ImageDataAPI, repetition: String) -> CanvasPatternAPI? {
        wipcanvas(nil)
    }

    @Jumped("createRadialGradient") private var _createRadialGradient = createRadialGradient
    public func createRadialGradient(x0: Double, y0: Double, r0: Double, x1: Double, y1: Double, r1: Double) -> CanvasGradientAPI? {
        wipcanvas(nil)
    }

    @Jumped("drawImage") private var _drawImage = drawImage
    public func drawImage(image: ImageDataAPI, dx: Double, dy: Double, dWidth: Double, dHeight: Double) {
        wipcanvas(())
    }

    @Jumped("createImageData") private var _createImageData = createImageData
    public func createImageData(width: Double, height: Double) -> ImageDataAPI? {
        wipcanvas(nil)
    }

    @Jumped("getImageData") private var _getImageData = getImageData
    public func getImageData(sx: Double, sy: Double, sw: Double, sh: Double) -> ImageDataAPI? {
        wipcanvas(nil)
    }

    @Jumped("putImageData") private var _putImageData = putImageData
    public func putImageData(imageData: ImageDataAPI, dx: Double, dy: Double) {
        wipcanvas(())
    }

    @Jumped("getContextAttributes") private var _getContextAttributes = getContextAttributes
    public func getContextAttributes() -> CanvasRenderingContext2DSettingsAPI? {
        wipcanvas(nil)
    }

    /// Perform the given block and then restore the context
    private func restoringContext(_ f: () throws -> ()) rethrows {
        save()
        defer { restore() }
        try f()
    }

    /// Perform the given block and then re-set the current path
    private func continuingPath(_ f: () throws -> ()) rethrows {
        // operations like `fillPath` clears the path, so grab a copy to add it back
        let path = ctx.path?.copy()
        defer {
            // continue the current path
            if let path = path {
                ctx.addPath(path)
            }
        }
        try f()
    }

}

@available(macOS 11, iOS 13, tvOS 13, *)
extension CoreGraphicsCanvasPod {
    /// Creates a PDF graphics context and invokes the hanlder with a temporary
    /// - Parameters:
    ///   - size: the size of canvas to create
    ///   - handler: the drawing handler, which will take an instance of `CoreGraphicsCanvasPod` and use it for drawing.
    /// - Returns: the raw PDF data of the drawing operations
    public static func drawPDF(size: CGSize, handler: (CoreGraphicsCanvasPod) throws -> ()) throws -> Data {
        let size = CGSize(width: 512, height: 512)
        let outputData = NSMutableData()

        var imageRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        let properties: [String: Any] = [:]

        enum Errors : Error {
            case cannotCreateDataConsumer
            case cannotCreateContext
        }

        guard let dataConsumer = CGDataConsumer(data: outputData) else {
            throw Errors.cannotCreateDataConsumer
        }

        guard let ctx = CGContext(consumer: dataConsumer, mediaBox: &imageRect, properties as NSDictionary) else {
            throw Errors.cannotCreateContext
        }

        let pod = Self(context: ctx, size: size)
        ctx.beginPDFPage(nil)
        try handler(pod)
        ctx.endPage()
        ctx.closePDF()

        return outputData as Data
    }
}
#endif


#if canImport(SwiftUI)
import SwiftUI

@available(macOS 12, iOS 15, tvOS 15, *)
public class SwiftUICanvasPod<Symbols : View> : JackPod, CanvasPod {
    private let canvas: Canvas<Symbols>

    public init(canvas: Canvas<Symbols>) {
        self.canvas = canvas
    }

    public var metadata: JackPodMetaData {
        JackPodMetaData(homePage: URL(string: "https://www.example.com")!)
    }

    public lazy var pod = jack()
}
#endif



#if canImport(XCTest)
import XCTest

@available(macOS 11, iOS 13, tvOS 13, *)
class CanvasPodTest : XCTestCase {
    #if canImport(CoreGraphics)
    func testCoreGraphicsCanvasPod() throws {
        let properties: [String: Any] = [:]
        let size = CGSize(width: 512, height: 512)
        let outputData = NSMutableData()

        var imageRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        guard let dataConsumer = CGDataConsumer(data: outputData) else {
            return XCTFail("no consumer")
        }

        guard let ctx = CGContext(consumer: dataConsumer, mediaBox: &imageRect, properties as NSDictionary) else {
            return XCTFail("no context")
        }

        let pod = CoreGraphicsCanvasPod(context: ctx, size: size)
        ctx.beginPDFPage(nil)

        let jxc = pod.jack(as: "canvas").env
        //try pod.jxc.eval("transform(1,2,3,4,5,6)")

        func metrics(_ string: String) throws -> CoreGraphicsCanvasPod.TextMetrics {
            try jxc.global.setProperty("txt", jxc.string(string))
            return try jxc.eval("canvas.measureText(txt)").convey(in: jxc)
        }

        XCTAssertEqual(24, try metrics("ABC").width, accuracy: 1.0)
        XCTAssertEqual(99, try metrics("this is a long string").width, accuracy: 1.0)
        XCTAssertEqual(99, try metrics("this is a long string\nwith a newline").width, accuracy: 1.0) // not naïve

    }
    #endif

    #if canImport(CoreGraphics)
    func testPDFCanvasPod() throws {
        let pdf = try CoreGraphicsCanvasPod.drawPDF(size: CGSize(width: 512, height: 512)) { ctx in
            ctx.moveTo(x: 10, y: 10)
            ctx.lineTo(x: 20, y: 20)
            ctx.fillRect(x: 10, y: 10, w: 20, h: 20)
        }
        print("created PDF size:", pdf)
        try pdf.write(to: URL(fileURLWithPath: "/tmp/canvasdemo.pdf"))
    }
    #endif
}
#endif
