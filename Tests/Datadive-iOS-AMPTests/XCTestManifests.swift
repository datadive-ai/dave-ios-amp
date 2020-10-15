import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(Datadive_iOS_AMPTests.allTests),
    ]
}
#endif
