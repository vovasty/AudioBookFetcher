import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(PathFormatterTests.allTests),
        ]
    }
#endif
