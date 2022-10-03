# ``Jack``


Jack is a cross-platform framework for exporting the properties and functions 
of your Swift classes to an embedded JavaScript environment,
enabling your app to provide scriptable extensions.

Jack uses the pure-Swift [JXKit](https://www.jective.org/JXKit/documentation/jxkit/)
JavaScript framework and exports your class's Swift properties
and functions to an embedded JavaScript context, similar to 
 [`@JSExport`](https://developer.apple.com/documentation/javascriptcore/jsexport)
in the Objective-C world. It also enabled the tracking of properties
as a ``Combine.ObservableObject``.

The framework is cross-platform (iOS/macOS/tvOS/Linux) and 
can be used to export Swift instances to a scripting envrionment.

## Property Wrappers

Jack provides the following property wrappers that can be
used within a ``JackedObject``.

Swift                       | JackedObject |   JavaScript   | Combine    |
---------------------------:|--------------|----------------|------------|
Any                         | @Track       | *not exported* | @Published |
Primitive / String / RawRep | @Stack       | Property       | @Published | 
Codable                     | @Pack        | Property       | @Published |
Function                    | @Jack        | Method         | *none*     |



### Example

```swift
import Jack

class AppleJack : JackedObject { 
    @Stack var name: String // exports the property to JS and acts as Combine.Published 
    @Stack var age: Int

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

        let jxc = try jackApp.jack().ctx

        let namejs = try jxc.eval("name").stringValue
        assert(namejs == jackApp.name)

        let agejs = try jxc.eval("age").numberValue
        assert(agejs == Double(jackApp.age)) // JS numbers are doubles

        assert(jackApp.haveBirthday() == 25) // direct Swift call
        let newAge = try jxc.eval("haveBirthday()").numberValue // script invocation

        assert(newAge == 26.0)
        assert(jackApp.age == 26)
    }
}

```


### @Track

A ``Track`` property is the equivalent to the ``Published``
property for the ``ObservableObject`` conformance of a ``JackedObject``.
Note that it is not possible to use ``Published`` in ``JackedObject``,
so ``Track`` provides equivalent functionality and works transparently
as an ``ObservableObject``, such as in a  ``SwiftUI.EnvironmentObject``.

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
