//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation

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
    ///   - modifications: The modifications to apply to the key's associated value.
    @inlinable
    @inline(__always)
    public mutating func modifyValue<R>(
        forKey key: Key,
        default defaultValue: @autoclosure () -> Value,
        _ modifications: (inout Value) throws -> R
    ) rethrows -> R {
        try modifications(&self[key, default: defaultValue()])
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
    ///     hues.modifyValue(forKey: "Coral") { value in
    ///         value.modifyIfNotNil { value in
    ///             value  += 2
    ///         }
    ///     }
    ///     print(hues["Coral"] as Any)
    ///     // Prints "Optional(18)"
    ///
    ///     hues.modifyValue(forKey: "Cerise") { value in
    ///         value.modifyIfNotNil { value in
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
    ///   - modifications: The modifications to apply to the key's associated value.
    @inlinable
    @inline(__always)
    public mutating func modifyValue<R>(
        forKey key: Key,
        _ modifications: (inout Value?) throws -> R
    ) rethrows -> R {
        try modifications(&self[key])
    }
}
