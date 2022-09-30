# ``Jack``

Jack is a cross-platform framework that enables you to export
properties of your Swift classes to an embedded JavaScript environment,
enabling your app to provide scriptable extensions.

```swift
import Jack

class AppleJack : JackedObject { 
    @Stack var name: String // exports the property to JS and acts as Combine.Published 
    @Stack var age: Int

    /// An embedded `JXKit` script context that has access to the jacked properties and jumped functions
    lazy var jxc = jack().env

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    /// Functions are exported as method properties, and can be re-named for export
    @Jack("haveBirthday") var _haveBirthday = haveBirthday
    func haveBirthday() -> Int {
        age += 1
        return age
    }

    static func demo() throws {
        let jackApp = AppleJack(name: "Jack Appleseed", age: 24)

        let namejs = try jackApp.jxc.eval("name").stringValue
        assert(namejs == jackApp.name)

        let agejs = try jackApp.jxc.eval("age").numberValue
        assert(agejs == Double(jackApp.age)) // JS numbers are doubles

        assert(jackApp.haveBirthday() == 25) // direct Swift call
        let newAge = try jackApp.jxc.eval("haveBirthday()").numberValue // script invocation

        assert(newAge == 26.0)
        assert(jackApp.age == 26)
    }
}

```


Jack uses [JXKit](https://www.jective.org/JXKit/documentation/jxkit/)
to provide a simple way to export your Swift properties
and functions to an embedded JavaScript context.

The framework is cross-platform (iOS/macOS/tvOS/Linux) and 
can be used to export Swift instanced to a scripting
envrionment.

## Property Wrappers

Jack provides the following property wrappers that can be
used within a ``JackedObject``.

### @Track

A ``Track`` property is the equivalent to the ``Published``
property for the ``ObservableObject`` conformance of a ``JackedObject``.
Note that it is not possible to use ``Published`` in ``JackedObject``,
so ``Track`` provides equivalent functionality and works transparently
as an ``ObservableObject``, such as in a SwiftUI ``EnvironmentObject``.

### @Stack

A ``Stack`` propery is published (like the ``Track`` wrapper), and it is
additionally exposed to the [JXContext] as a property. Properties
can be get and set from within JavaScript as if they were regular
properties of objects.

The conforming types are numbers, strings, and booleans.
For general support for other codable value types,
use ``Pack``.

### @Pack

A ``Pack`` property is similar to ``Stack``, but it passes objects
back and forth between Swift and JavaScript by encoding its values.

### @Jack

A ``Jack`` property applies to closure properties as a means
of exposing Swift functions to the JavaScript environment.


## JackPod

A ``JackPod`` provides a set of native properties and functions
that are exported to a [JXContext]. It can be used to provide
interfaces to the os logging, file system, and custom frameworks.
It also bridges JavaScript and Swift concurrency primitivies, 
to enable JavaScript's `await` to call back into a swift `async` function.


[JXContext]: https://www.jective.org/JXKit/documentation/jxkit/jxcontext
[JXValue]: https://www.jective.org/JXKit/documentation/jxkit/jxvalue
