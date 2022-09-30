import class Foundation.Bundle
import class Foundation.NSDictionary

// This class supports extracting the version information of the runtime.

// MARK: Jack Module Metadata

/// The bundle for the `Jack` module.
public let JackBundle = Foundation.Bundle.module

/// The information plist for the `Jack` module, which is stored in `Resources/Jack.plist` (until SPM supports `Info.plist`).
private let JackPlist = JackBundle.url(forResource: "Jack", withExtension: "plist")!

/// The info dictionary for the `Jack` module.
public let JackInfo = NSDictionary(contentsOf: JackPlist)

/// The bundle identifier of the `Jack` module as specified by the `CFBundleIdentifier` of the `JackInfo`.
public let JackBundleIdentifier: String! = JackInfo?["CFBundleIdentifier"] as? String

/// The version of the `Jack` module as specified by the `CFBundleShortVersionString` of the `JackInfo`.
public let JackVersion: String! = JackInfo?["CFBundleShortVersionString"] as? String

/// The version components of the `CFBundleShortVersionString` of the `JackInfo`, such as `[0, 0, 1]` for "0.0.1" ` or `[1, 2]` for "1.2"
private let JackV = { JackVersion.components(separatedBy: .decimalDigits.inverted).compactMap({ Int($0) }).dropFirst($0).first }

/// The major, minor, and patch version components of the `Jack` module's `CFBundleShortVersionString`
public let (JackVersionMajor, JackVersionMinor, JackVersionPatch) = (JackV(0), JackV(1), JackV(2))

/// A comparable representation of ``JackVersion``, which can be used for comparing known versions and sorting via semver semantics.
///
/// The form of the number is `(major*1M)+(minor*1K)+patch`, so version "1.2.3" becomes `001_002_003`.
/// Caveat: any minor or patch version components over `999` will break the comparison expectation.
public let JackVersionNumber = ((JackVersionMajor ?? 0) * 1_000_000) + ((JackVersionMinor ?? 0) * 1_000) + (JackVersionPatch ?? 0)
