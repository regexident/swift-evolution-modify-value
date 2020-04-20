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
    ///   - modifications: A closure that modifies the unwrapped value of the instance.
    @inlinable
    @inline(__always)
    public mutating func modifyIfNotNil(
        _ modifications: (inout Wrapped) throws -> Void
    ) rethrows {
        // We extract the value out of self, or return early:
        guard var value = self else { return }
        // Then we clear the remaining use in `self`,
        // which essentially moves the value out of self, temporarily:
        self = nil

        // Make sure to put the modified value back in in the end,
        // no matter what happens during modifications:
        defer {
            self = value
        }

        // Then we try to apply our modifications:
        try modifications(&value)
    }
}
