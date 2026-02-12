import AudioBookFetcherTests
import XCTest

var tests = [XCTestCaseEntry]()
tests += AudioBookFetcherTests.allTests()
tests += AKnigaTests.allTests()
XCTMain(tests)
