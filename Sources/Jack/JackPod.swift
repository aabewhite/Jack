import Foundation

// MARK: JackPod

/// A ``JackPod`` is a unit of native functionality that can be exported to a scripting environment via a ``JackedObject``.
public protocol JackPod : JackedObject {
    /// The metadata for this pod
    var metadata: JackPodMetaData { get }
}

/// Information about the jackpod
public struct JackPodMetaData : Codable {
    public var homePage: URL

    public init(homePage: URL) {
        self.homePage = homePage
    }
}
