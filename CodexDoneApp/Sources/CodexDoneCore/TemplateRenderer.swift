import Foundation

public struct TemplateContext: Equatable {
    public var project: String
    public var message: String
    public var time: String

    public init(project: String, message: String, time: String) {
        self.project = project
        self.message = message
        self.time = time
    }
}

public enum TemplateRenderer {
    public static func render(_ template: String, context: TemplateContext) -> String {
        let replacements: [(token: String, value: String)] = [
            ("{project}", context.project),
            ("{message}", context.message),
            ("{time}", context.time)
        ]

        var rendered = ""
        var index = template.startIndex

        while index < template.endIndex {
            if let replacement = replacements.first(where: { template[index...].hasPrefix($0.token) }) {
                rendered += replacement.value
                index = template.index(index, offsetBy: replacement.token.count)
            } else {
                rendered.append(template[index])
                index = template.index(after: index)
            }
        }

        return rendered
    }
}
