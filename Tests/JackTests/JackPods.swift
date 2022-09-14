import Foundation
import Jack

// MARK: JackPod

/// A ``JackPod`` is a unit of native functionality that can be exported to a scripting environment via a ``JackedObject``.
@available(macOS 11, iOS 13, tvOS 13, *)
public protocol JackPod : JackedObject {
    /// The metadata for this pod
    var metadata: JackPodMetaData { get }

    /// The value in which the pod uses to expose its properties and methods.
    var pod: JXValue { get }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JackPod {
    /// The context for the pod.
    public var jxc: JXContext { pod.env }
}

@available(macOS 11, iOS 13, tvOS 13, *)
public struct JackPodMetaData : Codable {
    public var homePage: URL
}
