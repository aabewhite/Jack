Jack
========

[![Build Status][GitHubActionBadge]][ActionsLink]
[![Swift5 compatible][Swift5Badge]][Swift5Link] 
![Platform][SwiftPlatforms]
<!-- [![](https://tokei.rs/b1/github/jectivex/Jack)](https://github.com/jectivex/Jack) -->

Jack is a cross-platform Swift framework that enables a Combine (or OpenCombine) `ObservableObject` to expose and share its properties and functionality with an embedded JavaScriptCore runtime. 

This framework integrates transparently with SwiftUI's `EnvironmentObject` pattern, and so can be used to enhance existing `ObservableObject` instances with scriptable app-specific plug-ins.

Consider an example ping-pong game between Swift and JavaScript:

```swift
import Jack

// A standard Combine-based ObservableObject
class PingPongNative : ObservableObject {
    @Published var score = 0

    /// - Returns: true if a point was scored
    func ping() -> Bool {
        if Bool.random() == true {
            self.score += 1
            return true // score
        } else {
            return false // returned
        }
    }
}

// An enhanced scriptable ObservableObject
class PingPongScripted : JackedObject {
    @Jacked var score = 0
    private lazy var jsc = jack() // a JSContext bound to this instance

    /// - Returns: true if a point was scored
    func pong() throws -> Bool {
        // evaluate the javascript with "score" as a readable/writable property
        try jsc.eval("Math.random() > 0.5 ? this.score += 1 : false").booleanValue
    }
}

let playerA = PingPongNative()
let playerB = PingPongScripted()

var server: any ObservableObject = Bool.random() ? playerA : playerB

let announcer = playerA.$score.combineLatest(playerB.$score).sink { scoreA, scoreB in
    print("SCORE:", scoreA, scoreB, "Serving:", server === playerA ? "SWIFT" : "JAVASCRIPT")
}

while playerA.score < 21 && playerB.score < 21 {
    if server === playerA {
        while try !playerA.ping() && !playerB.pong() { continue }
    } else if server === playerB {
        while try !playerB.pong() && !playerA.ping() { continue }
    }
    if (playerA.score + playerB.score) % 5 == 0 {
        print("Switching Servers")
        server = server === playerA ? playerB : playerA
    }
}

print("Winner: ", playerA.score > playerB.score ? "Swift" : "JavaScript")
_ = announcer // no longer needed

```

An excerpt from a game might be appear as:

```
SCORE: 0 0 Serving: JAVASCRIPT
SCORE: 1 0 Serving: JAVASCRIPT

Switching Servers

SCORE: 2 3 Serving: SWIFT
SCORE: 3 6 Serving: SWIFT
SCORE: 3 7 Serving: SWIFT

Switching Servers

SCORE: 3 7 Serving: JAVASCRIPT
SCORE: 4 11 Serving: JAVASCRIPT
SCORE: 13 20 Serving: JAVASCRIPT
SCORE: 13 21 Serving: JAVASCRIPT

Winner:  JavaScript
```


## Installation

### Swift Package Manager

The [Swift Package Manager][] is a tool for managing the distribution of
Swift code.

Add the following to your `Package.swift` file:

  ```swift
  dependencies: [
      .package(url: "https://github.com/jectivex/Jack", from: "1.0.0")
  ]
  ```

[Swift Package Manager]: https://swift.org/package-manager

## Communication

[See the planning document] for a roadmap and existing feature requests.

 - Need **help** or have a **general question**? [Ask on Stack
   Overflow][] (tag `swiftjack`).
 - Found a **bug** or have a **feature request**? [Open an issue][].
 - Want to **contribute**? [Submit a pull request][].

[See the planning document]: /Documentation/Planning.md
[Read the contributing guidelines]: ./CONTRIBUTING.md#contributing
[Ask on Stack Overflow]: https://stackoverflow.com/questions/tagged/swiftjack
[Open an issue]: https://github.com/jectivex/Jack/issues/new
[Submit a pull request]: https://github.com/jectivex/Jack/fork

## Related

These projects are used by Jack:

 - [OpenCombine][] provides Combine on Linux
 - [JXKit][] Cross-platform Swift interface to JavaScriptCore


[ProjectLink]: https://github.com/jectivex/Jack
[ActionsLink]: https://github.com/jectivex/Jack/actions

[Swift]: https://swift.org/
[OpenCombine]: https://github.com/OpenCombine/OpenCombine
[Jack]: https://github.com/github/jectivex/Jack
[JXKit]: https://github.com/github/jectivex/JXKit

[GitHubActionBadge]: https://img.shields.io/github/workflow/status/jectivex/Jack/Jack%20CI

[Swift5Badge]: https://img.shields.io/badge/swift-5-orange.svg?style=flat
[Swift5Link]: https://developer.apple.com/swift/
[SwiftPlatforms]: https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20Linux-teal.svg

