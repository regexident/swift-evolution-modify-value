# Package Name

> **Note:** This package is a part of a Swift Evolution proposal for
  inclusion in the Swift standard library, and is not intended for use in
  production code at this time.

* Proposal: [SE-NNNN](https://github.com/apple/swift-evolution/proposals/NNNN-filename.md) ( 👉[Draft](./PROPOSAL.md))
* Author(s): [Vincent Esche](https://github.com/regexident)

## Introduction

This proposal adds the following APIs to the Swift standard library:

* `Optional`:
  * `modifyIfNotNil(_:)`
* `Dictionary`:
  * `modifyValue(forKey:_:)`
  * `modifyValue(forKey:default:_:)`
* `MutableCollection`:
  * `modifyElement(at:_:)`

The methods provide a no-surprises API for efficiently modifying a collection's specific value, preventing the user from accidentally triggering unwanted copy-on-write semantics, reducing the number of required key-lookups, while also making the user's intention clearer (i.e. "modify a value" vs. "get/remove a value, then insert a modified value").

```swift
import SE0000_ModifyValue

var hues = ["Heliotrope": 296, "Coral": 16]

hues.modifyValue(forKey: "Heliotrope", default: 296) { value in
    value += 2
}
print(hues["Coral"] as Any)
// Prints "Optional(18)"

hues.modifyValue(forKey: "Cerise", default: 328) { value in
    value += 2
}
print(hues["Cerise"] as Any)
// Prints "Optional(330)"

hues.modifyValue(forKey: "Coral") { value in
    value.modifyIfNotNil { value in
        value += 2
    }
}
print(hues["Coral"] as Any)
// Prints "Optional(18)"

hues.modifyValue(forKey: "Aquamarine") { value in
    value = 156
}
print(hues["Aquamarine"] as Any)
// Prints "Optional(156)"

print(hues)
// Prints ["Aquamarine": 156, "Heliotrope": 296, "Coral": 18, "Cerise": 330]
```

## Usage

To use this library in a Swift Package Manager project,
add the following to your `Package.swift` file's dependencies:

```swift
.package(
    url: "https://github.com/regexident/swift-evolution-modify-value.git",
    .branch("master")
),
```
