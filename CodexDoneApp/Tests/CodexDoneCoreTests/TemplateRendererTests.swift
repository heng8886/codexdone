import XCTest
@testable import CodexDoneCore

final class TemplateRendererTests: XCTestCase {
    func testRendersSupportedVariables() {
        let context = TemplateContext(
            project: "13codexdone",
            message: "代码修改完成",
            time: "09:30"
        )

        let rendered = TemplateRenderer.render(
            "{project}: {message} at {time}",
            context: context
        )

        XCTAssertEqual(rendered, "13codexdone: 代码修改完成 at 09:30")
    }

    func testLeavesUnknownVariablesVisible() {
        let context = TemplateContext(project: "A", message: "B", time: "C")

        let rendered = TemplateRenderer.render("{duration} {project}", context: context)

        XCTAssertEqual(rendered, "{duration} A")
    }

    func testReplacementValuesContainingTokensStayLiteral() {
        let context = TemplateContext(
            project: "{message}",
            message: "actual message",
            time: "09:30"
        )

        let rendered = TemplateRenderer.render("{project}", context: context)

        XCTAssertEqual(rendered, "{message}")
    }

    func testRepeatedVariablesAreAllReplaced() {
        let context = TemplateContext(project: "A", message: "B", time: "C")

        let rendered = TemplateRenderer.render("{project} / {project}", context: context)

        XCTAssertEqual(rendered, "A / A")
    }
}
