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

extension MutableCollection {
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
    /// - Parameters:
    ///   - position: The position of the element to access. `position`
    ///     must be a valid index of the collection that is not equal to the
    ///     `endIndex` property.
    ///   - modifications: The modifications to apply to the element.
    ///
    /// - Complexity: O(1)
    @inlinable
    @inline(__always)
    public mutating func modifyElement<R>(
        at index: Index,
        _ modifications: (inout Element) throws -> R
    ) rethrows -> R {
        return try modifications(&self[index])
    }
}
