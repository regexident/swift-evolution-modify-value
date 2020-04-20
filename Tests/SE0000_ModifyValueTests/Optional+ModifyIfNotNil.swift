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

import XCTest

import SE0000_ModifyValue

final class OptionalModifyIfNotNilTests: XCTestCase {
    func testModifyIfNotNil() {
        var possibleNumber: Int? = Int("42")
        possibleNumber.modifyIfNotNil { $0 *= 2 }
        XCTAssertEqual(possibleNumber, 84)

        var noNumber: Int? = nil
        noNumber.modifyIfNotNil { $0 *= 2 }
        XCTAssertEqual(noNumber, nil)
    }
}
