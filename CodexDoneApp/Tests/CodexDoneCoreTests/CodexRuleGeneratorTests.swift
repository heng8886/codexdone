import XCTest
@testable import CodexDoneCore

final class CodexRuleGeneratorTests: XCTestCase {
    func testGeneratedRuleIncludesCommandAndFailureGuidance() {
        let rule = CodexRuleGenerator.rule(commandName: "custom-done")

        XCTAssertTrue(rule.contains("每当你完成一个阶段性任务"))
        XCTAssertTrue(rule.contains("custom-done"))
        XCTAssertTrue(rule.contains("--event testFailed"))
        XCTAssertTrue(rule.contains("通知失败"))
        XCTAssertTrue(rule.contains("不要中断任务"))
    }
}
