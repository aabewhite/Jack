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

### @``Tracked``

### @``Jacked``

### @``Coded``

### @``Jumped``


## JackPod

A ``JackPod`` provides a set of native properties and functions
that are exported to a ``JXContext``. It can be used to provide
interfaces to the os logging, file system, and custom frameworks.
It also bridges JavaScript and Swift concurrency primitivies, 
to enable JavaScript's `await` to call back into a swift `async` function.
