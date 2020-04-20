import XCTest

struct CopySpy {
	struct Error: Swift.Error, CustomStringConvertible {
		var description: String {
			"Encountered an unexpected copy"
		}
	}

	private class Storage {}

    private let expectation: XCTestExpectation?

    private var storage: Storage = .init()

    public init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

	mutating func mutate() throws {
        self.expectation?.fulfill()

		if !Swift.isKnownUniquelyReferenced(&self.storage) {
			throw Error()
		}
	}
}
