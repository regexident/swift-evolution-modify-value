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

final class MutableCollectionModifyTests: XCTestCase {
    func testModifyElementAt() {
        struct Hue: Equatable {
            let name: String
            var value: Int

            public init(_ name: String, _ value: Int) {
                self.name = name
                self.value = value
            }
        }

        var hues: [Hue] = [Hue("Heliotrope", 296), Hue("Coral", 16)]

        hues.modifyElement(at: 1) { hue in
            hue.value += 2
        }
        XCTAssertEqual(hues[1], Hue("Coral", 18))

        XCTAssertEqual(hues, [Hue("Heliotrope", 296), Hue("Coral", 18)])
    }

    func testModifyElementAtDoesNotCopy() throws {
        var array: [CopySpy] = [
            .init(expectation: self.expectation(
                description: "expected call to `mutate()` method"
            )),
        ]

        try array.modifyElement(at: 0) { spy in
            XCTAssertNoThrow(try spy.mutate())
        }

        self.waitForExpectations(timeout: 1.0)
    }
}
