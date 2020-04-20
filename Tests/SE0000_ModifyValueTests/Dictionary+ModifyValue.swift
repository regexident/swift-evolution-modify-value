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

final class DictionaryModifyValueTests: XCTestCase {
    // MARK: - With Default

    func testModifyValueForKeyDefault() {
        var hues = ["Heliotrope": 296, "Coral": 16]

        hues.modifyValue(forKey: "Coral", default: 16) { value in
            value += 2
        }
        XCTAssertEqual(hues["Coral"], 18)

        hues.modifyValue(forKey: "Cerise", default: 328) { value in
            value += 2
        }
        XCTAssertEqual(hues["Cerise"], 330)

        XCTAssertEqual(hues, ["Heliotrope": 296, "Coral": 18, "Cerise": 330])
    }

    func testModifyValueForKeyDefaultDoesNotCopy() throws {
        var spies: [String: CopySpy] = [
            "spy": .init(expectation: self.expectation(
                description: "expected call to `mutate()` method"
            )),
        ]

        try spies.modifyValue(forKey: "spy", default: .init()) { spy in
            XCTAssertNoThrow(try spy.mutate())
        }

        self.waitForExpectations(timeout: 1.0)
    }

    // MARK: - Without Default

    func testModifyValueForKey() {
        var hues = ["Heliotrope": 296, "Coral": 16]

        hues.modifyValue(forKey: "Coral") { value in
            value.modifyIfNotNil { value in
                value  += 2
            }
        }
        XCTAssertEqual(hues["Coral"], 18)

        hues.modifyValue(forKey: "Cerise") { value in
            value.modifyIfNotNil { value in
                value  += 2
            }
        }
        XCTAssertEqual(hues["Cerise"], nil)

        hues.modifyValue(forKey: "Aquamarine") { value in
            value = 156
        }
        XCTAssertEqual(hues["Aquamarine"], 156)

        XCTAssertEqual(hues, ["Heliotrope": 296, "Coral": 18, "Aquamarine": 156])
    }

    func testModifyValueForKeyDoesNotCopy() throws {
        var spies: [String: CopySpy] = [
            "spy": .init(expectation: self.expectation(
                description: "expected call to `mutate()` method"
            )),
        ]

        try spies.modifyValue(forKey: "spy") { spyOrNil in
            try spyOrNil.modifyIfNotNil { spy in
                XCTAssertNoThrow(try spy.mutate())
            }
        }

        self.waitForExpectations(timeout: 1.0)
    }

    // MARK: - Value Semantics

    struct CounterStruct: Equatable, ExpressibleByIntegerLiteral, CustomStringConvertible {
        typealias IntegerLiteralType = Int

        var count: Int

        var description: String { self.count.description }

        init(integerLiteral value: Int) {
            self.count = value
        }

        mutating func increment() { self.count += 1 }
    }

    func testModifyValueForKeyWithStructValue() {
        var structs: [String: CounterStruct] = [
            "foo": 0,
        ]

        structs["bar"]?.increment()
        XCTAssertEqual(structs, ["foo": 0])

        structs.modifyValue(forKey: "baz") { value in
            value = 1
        }
        XCTAssertEqual(structs, ["foo": 0, "baz": 1])

        structs.modifyValue(forKey: "baz") { value in
            value.modifyIfNotNil { value in
                value.increment()
            }
        }
        XCTAssertEqual(structs, ["foo": 0, "baz": 2])

        structs.modifyValue(forKey: "blee") { value in
            // keeps dictionary unchanged
        }
        XCTAssertEqual(structs, ["foo": 0, "baz": 2])
    }

    func testModifyValueForKeyDefaultWithStructValue() {
        var structs: [String: CounterStruct] = [
            "foo": 0,
        ]

        structs["bar", default: 0].increment()
        XCTAssertEqual(structs, ["foo": 0, "bar": 1])

        structs.modifyValue(forKey: "baz", default: 0) { value in
            // inserts default, even if left empty
        }
        XCTAssertEqual(structs, ["foo": 0, "bar": 1, "baz": 0])

        structs.modifyValue(forKey: "blee", default: 0) { value in
            value.increment()
        }
        XCTAssertEqual(structs, ["foo": 0, "bar": 1, "baz": 0, "blee": 1])
    }

    // MARK: - Class Semantics

    final class CounterClass: Equatable, ExpressibleByIntegerLiteral, CustomStringConvertible {
        typealias IntegerLiteralType = Int

        var count: Int

        var description: String { self.count.description }

        init(integerLiteral value: Int) {
            self.count = value
        }

        func increment() { self.count += 1 }

        static func == (lhs: CounterClass, rhs: CounterClass) -> Bool {
            lhs.count == rhs.count
        }
    }

    func testModifyValueForKeyWithClassValue() {
        var classes: [String: CounterClass] = [
            "foo": 0,
        ]

        classes["bar"]?.increment()
        XCTAssertEqual(classes, ["foo": 0])

        classes.modifyValue(forKey: "baz") { value in
            value = 1
        }
        XCTAssertEqual(classes, ["foo": 0, "baz": 1])

        classes.modifyValue(forKey: "baz") { value in
            value.modifyIfNotNil { value in
                value.increment()
            }
        }
        XCTAssertEqual(classes, ["foo": 0, "baz": 2])

        classes.modifyValue(forKey: "blee") { value in
            // keeps dictionary unchanged
        }
        XCTAssertEqual(classes, ["foo": 0, "baz": 2])
    }

    func testModifyValueForKeyDefaultWithClassValue() {
        var classes: [String: CounterClass] = [
            "foo": 0,
        ]

        classes["bar", default: 0].increment()
        XCTAssertEqual(classes, ["foo": 0])

        classes.modifyValue(forKey: "baz", default: 0) { value in
            // inserts default, even if left empty
        }
        XCTAssertEqual(classes, ["foo": 0, "baz": 0])

        classes.modifyValue(forKey: "blee", default: 0) { value in
            value.increment()
        }
        XCTAssertEqual(classes, ["foo": 0, "baz": 0, "blee": 1])
    }
}
