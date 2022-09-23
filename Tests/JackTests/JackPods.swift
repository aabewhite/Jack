import Foundation
import Jack

// MARK: JackPod

/// A ``JackPod`` is a unit of native functionality that can be exported to a scripting environment via a ``JackedObject``.
public protocol JackPod : JackedObject {
    /// The metadata for this pod
    var metadata: JackPodMetaData { get }

    /// The value in which the pod uses to expose its properties and methods.
    var pod: JXValue { get }
}

extension JackPod {
    /// The context for the pod.
    public var jxc: JXContext { pod.env }
}

public struct JackPodMetaData : Codable {
    public var homePage: URL
}
