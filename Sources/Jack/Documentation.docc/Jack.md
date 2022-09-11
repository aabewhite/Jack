# ``Jack``

Jack uses [JXKit](https://www.jective.org/JXKit/documentation/jxkit/)
to provide a simple way to export your Swift properties
and functions to an embedded JavaScript context.

The framework is cross-platform (iOS/macOS/tvOS/Linux) and 
can be used to export Swift instanced to a scripting
envrionment.

## Property Wrappers

Jack provides the following property wrappers that can be
used within a ``JackedObject``.

### @Tracked

A ``Tracked`` property is the equivalent to the ``Published``
property for the ``ObservableObject`` conformance of a ``JackedObject``.
Note that it is not possible to use ``Published`` in ``JackedObject``,
so ``Tracked`` provides equivalent functionality and works transparently
as an ``ObservableObject``, such as in a SwiftUI ``EnvironmentObject``.

### @Jacked

A ``Jacked`` propery is published (like the ``Tracked`` wrapped), and it is
additionally exposed to the [JXContext] as a property. Properties
can be get and set from within JavaScript as if they were regular
properties of objects.

The conforming types are numbers, strings, and booleans.
For general support for other codable value types,
use ``Coded``.

### @Coded

A ``Coded`` property is similar to ``Jacked``, but it passes objects
back and forth between Swift and JavaScript by encoding its values.

### @Jumped

A ``Jumped`` proeprty applies to closure properties as a means
of exposing Swift functions to the JavaScript environment.


## JackPod

A ``JackPod`` provides a set of native properties and functions
that are exported to a [JXContext]. It can be used to provide
interfaces to the os logging, file system, and custom frameworks.
It also bridges JavaScript and Swift concurrency primitivies, 
to enable JavaScript's `await` to call back into a swift `async` function.


[JXContext]: https://www.jective.org/JXKit/documentation/jxkit/jxcontext
[JXValue]: https://www.jective.org/JXKit/documentation/jxkit/jxvalue
