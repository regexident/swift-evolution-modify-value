# Adding `modify…(…)` methods to `Dictionary`/`MutableCollection`/`Optional`

* Proposal: [SE-NNNN](NNNN-filename.md)
* Authors: [Vincent Esche](https://github.com/regexident)
* Review Manager: TBD
* Status: **Implemented**

<!-- *During the review process, add the following fields as needed:*

* Implementation: [apple/swift#NNNNN](https://github.com/apple/swift/pull/NNNNN) or [apple/swift-evolution-staging#NNNNN](https://github.com/apple/swift-evolution-staging/pull/NNNNN)
* Decision Notes: [Rationale](https://forums.swift.org/), [Additional Commentary](https://forums.swift.org/)
* Bugs: [SR-NNNN](https://bugs.swift.org/browse/SR-NNNN), [SR-MMMM](https://bugs.swift.org/browse/SR-MMMM)
* Previous Revision: [1](https://github.com/apple/swift-evolution/blob/...commit-ID.../proposals/NNNN-filename.md)
* Previous Proposal: [SE-XXXX](XXXX-filename.md) -->

## Introduction

We propose adding the following APIs to the Swift standard library:

* `Optional`:
  * `modifyIfNotNil(_:)`
* `Dictionary`:
  * `modifyValue(forKey:_:)`
  * `modifyValue(forKey:default:_:)`
* `MutableCollection`:
  * `modifyElement(at:_:)`

The methods provide a no-surprises API for efficiently modifying a collection's specific value, preventing the user from accidentally triggering unwanted copy-on-write semantics, reducing the number of required key-lookups, while also making the user's intention clearer (i.e. "modify a value" vs. "get/remove a value, then insert a modified value").

Swift-evolution thread: [Discussion thread topic for that proposal](https://forums.swift.org/)

## Motivation

For collections, it is common to want to efficiently modify individual values.  

(Note: For the rest of this proposal we will consider `Optional` to be semantically equivalent to a zero-or-one element collection.)

For situations where the value's type already provides a mutating method (or operator) that implements the desired modification Swift already provides convenient support to modify a collection's specific element (e.g. via subscripts):

```swift
// only increment if not nil:
valueOrNil? += 1

// only increment a dictionary's value if its key exists:
dictionary["foo"]? += 1
// increment a dictionary's value, inserting a default value if its key doesn't yet exist:
dictionary["bar", default: 0] += 1

// increment an array's element:
array[42] += 1
```

Unfortunately however often times the required modification is more complex than a single expression and due to extern constraints you are being forced into a certain order of operations, or need to pass the value in question to some secondary API immediately before or after modification (but only if a modification took place), which makes direct usage of the `subscript` combined with optional chaining inapplicable.

<details>
<summary>Contrived example</summary>

```swift
protocol ControllerDelegate: AnyObject {
    func didUpdateState(_ state: State, forKey key: String)
}

class Controller {
    weak var delegate: ControllerDelegate?

    var statesByKey: [String: State] = [:] {
        didSet {
            // respond to added/removed states
        }
    }

    func updateStates() {
        let updates: Updates = .init(updatesByKey: [:])

        for (key, update) in updates.updatesByKey {
            if var state = self.statesByKey[key] {
                self.delegate?.willUpdateState(state, forKey: key)
                state.update(update)
                self.statesByKey[key] = state
                self.delegate?.didUpdateState(state, forKey: key)
            }

            // vs.:
            // self.statesByKey.modifyValue(forKey: key) { state in
            //     self.delegate?.willUpdateState(state, forKey: key)
            //     state.update(update)
            //     self.delegate?.didUpdateState(state, forKey: key)
            // }
        }
    }
}
```

</details>

In these situations a common workaround is to split the operation into three phases:

* getting the value
* modifying the value
* setting the value

Which, if applied to above code example would look something like this:

```swift
// only update optional's wrapped value, if not nil:
if var modifiedValue = valueOrNil {
    // ...
    valueOrNil = modifiedValue
}

// only update a dictionary's value if its key exists:
if var modifiedValue = dictionary[key] {
    // ...
    dictionary[key] = modifiedValue
}

// update a dictionary's value, inserting a default value if its key doesn't yet exist:
var modifiedValue = dictionary[key] ?? …
// ...
dictionary[key] = modifiedValue

// update an array's element:
var modifiedElement = array[index]
// ...
array[index] = modifiedElement
```

There are a couple of issues with seemingly unremarkable and contrived code examples above:

* ### Clarity

  For multi-line modifications the intention/semantics may not be clear at first glance, as it only becomes apparent by realizing that there are two mirroring subscript get/set lines, which might be separated by several other seemingly unrelated lines of code, forming a rather weak semantic coupling. This has the potential of hiding helpful semantic information from both, the reader as well as the compiler.

* ### Robustness

  The weak semantic coupling of getter and setter also make it rather easy to be broken unintentionally. One such possible source of breakage would be the inconsiderate removal of `dict[key] = value`, which while introducing a bug would still compile. An easily missed bug.

  Similarly one might add a `return`/`continue`/`break` somewhere between getter and setter and forget to move the latter into a `defer { … }` first, causing it to be skipped on some branches. Another easily missed bug.

* ### Copy-on-write

  Using a collection's getter (e.g. `var value = dict[key]`) followed up by its getter (e.g. `dict[key] = value`) for the same element (after having applied a modification to `value`) will result in a hard to notice and usually unwanted copy of `value` as Swift effectively sees two ownerships of the same value: one from the collection (e.g. `dictionary`), as well as one from the local variable binding (here: `value`) and thus the copy-on-write semantics invoke a copy of the shared value on mutation, regardless of whether the other ownership is dropped shortly after.

  For a user unaware of the delicate details of Swift's copy-on-write semantics (a significant number of people as is to be expected) it is in no way clear how using a subscript's getter or setter on their own could be just fine to use, but using them together suddenly leads to undesired side-effects and performance regressions. The documentation of `Dictionary`'s `subscript(key:)` or `subscript(key:default:)` further more mention no such pitfalls.

  One way to get rid of the unwanted copy is to retrieve the value via `var value = dict.removeValue(forKey: key)`, instead of `var value = dict[key]`, which moves the value out of the dictionary, thus retaining a single unique ownership at the time of mutation. This workaround however is not always applicable as it introduces additional removal/insertion changes that might be undesired, especially if the variable holding the dictionary has a `didSet` block associated with it that responds to the individual changes made to the dictionary: The change of a value would be disguised as pair of removes/inserts, instead of retaining its true semantic meaning — a modification change.

* ### Efficiency

  Modifying a value by calling `var value = dict[key]` (or the more appropriate `var value = dict.removeValue(forKey: key)`) followed by `dict[key] = value` requires two separate and potentially computationally expensive key lookups (such as for a `Dictionary` that's filled close to its capacity with a large number of hash collisions), whereas a dedicated method could effectively make use of a single lookup per modification.
  
  As such all the value modifications executed in the code examples above exihibit bad efficiency characteristics by effectively causing an unnecessary insertion of a copy (by the compiler) of the value prior to its mutation. While a future version of the Swift compiler might be powerful enough to eliminate such superfluous copies in many if not all cases, for performance-critical projects leaving the underlying semantics of such operations to chance is barely acceptable.

* ### Predictability

  The `Dictionary`'s [subscript API](https://developer.apple.com/documentation/swift/dictionary/2894528-subscript) bears another unexpected and subtle foot-gun, of which qe quote the relevant "note" here, verbatim:

  > **Note**
  >
  > Do not use this subscript to modify dictionary values if the dictionary’s Value type is a class.
  > In that case, the default value and key are not written back to the dictionary after an operation.

  As such the very same code behaves subtly different depending on the dictionary's value type:

  ```swift
  struct CounterStruct: CustomStringConvertible {
      var count: Int = 0
      mutating func increment() { self.count += 1 }
      var description: String { self.count.description }
  }

  final class CounterClass: CustomStringConvertible {
      var count: Int = 0
      func increment() { self.count += 1 }
      var description: String { self.count.description }
  }

  var structs: [String: CounterStruct] = [
      "foo": .init()
  ]
  structs["bar", default: .init()].increment()
  print(structs)
  // Prints ["bar": 1, "foo": 0]

  var classes: [String: CounterClass] = [
      "foo": .init()
  ]
  classes["bar", default: .init()].increment()
  print(classes)
  // Prints ["foo": 0]
  ```

Especially in situations where the value type is generic (and could thus exhibit either value or class copy semantics) Swift's subscripts currently provide no predictable semantics.

## Proposed solution

By addition of the proposed methods `modifyValue(forKey:_:)` and `modifyValue(forKey:default:_:)` the above code can be refined like this:

```swift
// only update optional's wrapped value, if not nil:
valueOrNil.modifyIfNotNil { value in
    // ...
}

// only update a dictionary's value if its key exists:
dictionary.modifyValue(forKey: key) { value in
    // ...
}

// update a dictionary's value, inserting a default value if its key doesn't yet exist:
dictionary.modifyValue(forKey: key, default: …) { value in
    // ...
}

// update an array's element:
array.modifyElement(at: index) { value in
    // ...
}
```

At first glance the differences might seem minute. The implications however are quite significant:

* ### Improved clarity

  Calling `modifyValue(forKey:)` on `dictionary` expresses a clear intention: to modify the value associated with the given key, which on a conceptual level has little to do with removing and/or adding a value (unlike the code from earlier).

* ### Improved robustness

  The API takes care of ensuring that the change of value is applied to the collection. No manual code review necessary.

* ### Improved copy-on-write

  By avoiding the creation of a temporary copy optimal efficiency is guaranteed and the code is no longer vulnerable to subtle changes that could introduce a performance regression.

* ### Improved efficiency

  By using just a single key lookup per modification we not only are more efficient, but also can optimize the implementation in a way that even avoids temporarily removing a value from the dictionary and instead modifies it in-place.

* ### Improved predictability

  By giving the methods an unambiguously value-mutating semantic we can provide an API that behaves uniformly (by always writing key and value back to the dictionary after an operation) regardless of whether the dictionary's `Value` type is a class or not.

### Example

```swift
var hues = ["Heliotrope": 296, "Coral": 16]

hues.modifyValue(forKey: "Coral", default: 16) { value in
    value += 2
}
print(hues["Coral"] as Any)
// Prints "Optional(18)"

hues.modifyValue(forKey: "Cerise", default: 328) { value in
    value += 2
}
print(hues["Cerise"] as Any)
// Prints "Optional(330)"

hues.modifyValue(forKey: "Coral") { valueOrNil in
    valueOrNil.modifyIfNotNil { value in
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
// Prints "[\"Aquamarine\": 156, \"Heliotrope\": 296, \"Coral\": 18, \"Cerise\": 330]"
```

## Detailed design

### Adding `.modifyIfNotNil(…)` to `Optional`

We propose adding the following API to `Optional`:

```swift
extension Optional {
    /// Evaluates the given closure when this `Optional` instance is not `nil`,
    /// passing the unwrapped value as an inout parameter.
    /// As such `modifyIfNotNil` can be thought of as a variant of `Optional.map`
    /// that mutates the receiving instance, instead pf producing a new instance.
    ///
    /// Use the `modifyIfNotNil` method with a closure that modifies the unwrapped value.
    /// This example performs an arithmetic operation on an optional integer.
    ///
    ///     var possibleNumber: Int? = Int("42")
    ///     possibleNumber.modifyIfNotNil { $0 *= 2 }
    ///     print(possibleNumber)
    ///     // Prints "Optional(84)"
    ///
    ///     var noNumber: Int? = nil
    ///     noNumber.modifyIfNotNil { $0 *= 2 }
    ///     print(noNumber)
    ///     // Prints "nil"
    ///
    /// - Parameters:
    ///   - _: A closure that modifies the unwrapped value of the instance.
    @inlinable
    @inline(__always)
    public mutating func modifyIfNotNil(
        _ _: (inout Wrapped) throws -> Void
    ) rethrows {
        // implementation omitted
    }
}
```

While the use/necessity of `value.modifyIfNotNil { value in … }` may seem a bit confusing at first glance, it is essentially made necessary by the lack of an API for modifying its wrapped value in-place, thus falling into the same trap as all other collections: unintended value copies on modification by use of mutable local bindings.

Additional need for `Optional.modifyIfNotNil(…)` is given by the fact that `inout` is only applicable in argument position. This effectively prevents the copy-efficient unwrapping of a `Dictionary`'s `inout Value?`  to `inout Value` with existing conventional language constructs in Swift.

### Adding `.modifyValue(…)` to `Dictionary`

We propose adding the following API to `Dictionary`:

```swift
extension Dictionary {
    /// Accesses the value associated with the given key and passes it to the provided closure for modifications.
    ///
    /// The following example creates a new dictionary and modifies the value of a
    /// key found in the dictionary (`"Coral"`) and a key not found in the
    /// dictionary (`"Cerise"`).
    ///
    /// When you modify a value for a key and that key already exists, the
    /// dictionary overwrites the existing value and returns `true`. If the dictionary doesn't
    /// contain the key, the key and value are kept unchanged and `false` is returned.
    ///
    /// Here, the value for the key `"Coral"` is incremented by `2` from `16` to `18`
    /// and a modification of a missing key `"Cerise"` does nothing.
    ///
    ///     var hues = ["Heliotrope": 296, "Coral": 16, "Aquamarine": 156]
    ///
    ///     hues.modifyValue(forKey: "Coral", default: 16) { value in
    ///         value += 2
    ///     }
    ///     print(hues["Coral"] as Any)
    ///     // Prints "Optional(18)"
    ///
    ///     hues.modifyValue(forKey: "Cerise", default: 328) { value in
    ///         value += 2
    ///     }
    ///     print(hues["Cerise"] as Any)
    ///     // Prints "Optional(330)"
    ///
    ///     print(hues)
    ///     // Prints "[\"Aquamarine\": 156, \"Heliotrope\": 296, \"Coral\": 18, \"Cerise\": 330]"
    ///
    /// - Note: Unlike `subscript(_:default:)` this method writes the default value and key back to
    ///   the dictionary after the operation, regardless of whether dictionary’s `Value` type is a class.
    ///
    /// - Parameters:
    ///   - key: The key to find in the dictionary.
    ///   - defaultValue: The default value to use if key doesn’t exist in the dictionary.
    ///   - _: The modifications to apply to the key's associated value.
    @inlinable
    @inline(__always)
    public mutating func modifyValue(
        forKey key: Key,
        default defaultValue: @autoclosure () -> Value,
        _: (inout Value) throws -> Void
    ) rethrows {
        // implementation omitted
    }

    /// Accesses the value associated with the given key and passes it to the provided closure for modifications.
    ///
    /// The following example creates a new dictionary and modifies the value of a
    /// key found in the dictionary (`"Coral"`) and two keys not found in the
    /// dictionary (`"Cerise"` and `"Aquamarine"`).
    ///
    /// If you only want to modify a value for a key if that key already exists, then
    /// the modifying logic needs to be further wrapped in `value.modifyIfNotNil { value in … }`,
    /// otherwise you can simply assign the value to be inserted for the missing key to the passed `value`.
    ///
    /// Here, the value for the key `"Coral"` is incremented by `2` from `16` to `18`,
    /// a modification of a missing key `"Cerise"` does nothing,
    /// while a default value is inserted for `"Aquamarine"`.
    ///
    ///     var hues = ["Heliotrope": 296, "Coral": 16]
    ///
    ///     hues.modifyValue(forKey: "Coral") { valueOrNil in
    ///         valueOrNil.modifyIfNotNil { value in
    ///             value  += 2
    ///         }
    ///     }
    ///     print(hues["Coral"] as Any)
    ///     // Prints "Optional(18)"
    ///
    ///     hues.modifyValue(forKey: "Cerise") { valueOrNil in
    ///         valueOrNil.modifyIfNotNil { value in
    ///             value  += 2
    ///         }
    ///     }
    ///     print(hues["Cerise"] as Any)
    ///     // Prints "nil"
    ///
    ///     hues.modifyValue(forKey: "Aquamarine") { value in
    ///         value = 156
    ///     }
    ///     print(hues["Aquamarine"] as Any)
    ///     // Prints "Optional(156)"
    ///
    /// - Parameters:
    ///   - key: The key to find in the dictionary.
    ///   - _: The modifications to apply to the key's associated value.
    @inlinable
    @inline(__always)
    public mutating func modifyValue(
        forKey key: Key,
        _: (inout Value?) throws -> Void
    ) rethrows {
        // implementation omitted
    }
}
```

The method `Dictionary.modifyValue(forKey:default:_:)` allows for efficiently modifying (or inserting) a value mirroring the functionality and semantics of `Dictionary.subscript(key:default:)`.

The method `Dictionary.modifyValue(forKey:_:)` allows for efficiently inserting, modifying or inserting a value mirroring the functionality and semantics of `Dictionary.subscript(key:)`.

Given that a key-value pair for a given key might not yet be present in a dictionary the closure passed to `Dictionary.modifyValue(forKey:_:)` retrieves an `inout Value?`. As shown above, unwrapping it with a normal `if var value = valueOrNil { … }` would cause a copy, hence the use of `valueOrNil.modifyIfNotNil { value in … }`.

Important: Unlike the `subscript` equivalents this API will ALWAYS insert a value on mutation regardless of whether the value's type is a `struct`/`enum` or `class`, predictably.

A possible implementation for these methods on `Dictionary` might simply call the `modify` subscript accessor of the dictionary.

### Adding `.modifyElement(…)` to `MutableCollection`

We propose adding the following API to `MutableCollection`:

```swift
/// Accesses the element at the specified position and passes it to the provided closure for modifications.
///
/// For example, you can modify an element of an array by using like this:
///
///     var streets = ["Adams Street", "Butler", "Channing Street"]
///     streets.modifyElement(at: 1) { street in
///         street.append(" Street")
///     }
///     print(streets[1])
///     // Prints "Butler Street"
///
/// - Parameter position: The position of the element to access. `position`
///   must be a valid index of the collection that is not equal to the
///   `endIndex` property.
///
/// - Complexity: O(1)
public mutating func modifyElement(
    at index: Self.Index,
    _: (inout Self.Element) throws -> Void
) rethrows {
    // implementation omitted
}
```

This adds alternative support for index-based modifications on `Dictionary`, as well as general support for all other index-based collections.

Most index-based collections do not allow for temporarily nulling the collection's internal stored value in order to avoid copying, which suggests the addition of `.modifyElement(at:)`.

A possible implementation for these methods on `MutableCollection` might simply call the `modify` subscript accessor of the collection.

## Source compatibility

This is strictly additive.

## Effect on ABI stability

N/A

## Effect on API resilience

N/A

## Alternatives considered

### Alternative names

The following naming schemes were considered (and subsequently rejected in favor of what is being proposed):

  * `modifyWrapped` / … / …

    While being more consistent (`Optional.Wrapped` -> `modifyWrapped`, `Dictionary.Value` -> `modifyValue`) we rejected `modifyWrapped` in favor of `modifyIfNotNil`,
    based on the reasoning that `…Wrapped` could be falsely misunderstood for a wrapping operation and `modifyIfNotNil` being rather nice to read and clear in intention.

    Another argument in favor of `modifyIfNotNil` is the fact that many people using Swift are still unaware of the fact that `T?` is an instance of `Optional<T>`, rather than a special language construct, let alone what a `Wrapped` value has to do with `T?`, which is nowhere to be found on `T`.

  * `modifySome` / … / …

    After `modifyIfNotNil` this (i.e. `modifySome`) is probably the strongest contender, when it comes to naming `Option.modify…(…)`.

  * `withWrappedIfNotNil` / `withValue` / `withElement`

    While the `with…` is a fairly common naming scheme for APIs that pass the receiver as first argument to a provided closure,
    the name does not quite make it clear that the operation performed on the passed value is a mutating one,
    regardless of whether the closure actually contains a mutation.
  
  * `mutateIfNotNil` / `mutateValue` / `mutateElement`
  
    While `mutating` is the term used for modifying a value there is no existing API in the Swift standard library using the word.
    Given that the proposed methods is similar in semantics to the `modify` accessor we are thus preferring `modify…`,

  * `updateIfNotNil` / `updateValue` / `updateElement`
  
    `Dictionary` already provides the following method with entirely different semantics:

    ```swift
    mutating func updateValue(_ value: Value, forKey key: Key) -> Value?
    ```

### Alternative APIs

#### `Dictionary.modifyValue(forKey:_:)`

Instead of passing the arguably somehwat obscure and difficult to work with `inout Value?`
(that is without the addition of `Optional.modifyIfNotNil()`)
one could have the method only call the closure if the key already exists in the dictionary
(hence removing the immediate need for a nested call to `Optional.modifyIfNotNil()`
when modifying an existing value within `Dictionary.modifyValue(forKey:_:)`):

```swift
extension Dictionary {
    @inlinable
    @inline(__always)
    public mutating func modifyValue(
        forKey key: Key,
        _: (inout Value) throws -> Void
    ) rethrows {
        // implementation omitted
    }
}
```

We rejected this alternative on the basis of it being significantly different in functionality to the corresponding `subscript(key:)` operator
including the aspect that —unlike the proposed variant— it would not allow for inserting/removing values.

### Open questions

#### Support for `Result`

A somewhat obvious logical addition to the already discussed API would be an equivalent API for `Result`.
Due to not being aware of a way to switch on an enum, while consuming the passed-in value we however couldn't figure out
how to make an API like `Result.modifySuccess(_:)` happen for `Result`, without having it cause unwanted value copies.

The provided preview implementation currently makes use of a sentinel value for `Optional.modifyIfNotNil`
that is used as stand-in while operating on the moved-out associated case value.

It would be preferable to have access to consuming (or `inout`) pattern matching.

Assuming such a solution exists, an API like this would be desirable for `Result`:

```swift
extension Result {
    @inlinable
    @inline(__always)
    public mutating func modifySuccess(
        _ modifications: (inout Success) throws -> Void
    ) rethrows {
        // implementation omitted
    }

    @inlinable
    @inline(__always)
    public mutating func modifyFailure(
        _ modifications: (inout Failure) throws -> Void
    ) rethrows {
        // implementation omitted
    }
}
```

In this case it might also be desirable to rename `Optional.modifyIfNotNil` to a more consistent `Optional.modifyWrapped` or `Optional.modifySome` to ease API discoverability, following the [principle of least astonishment](https://en.wikipedia.org/wiki/Principle_of_least_astonishment).
