import XCTest
@testable import CodexDoneCore

final class MacOSVoiceCatalogTests: XCTestCase {
    func testParsesSayVoiceListWithSpacesAndLocalizedNames() {
        let output = """
        Albert              en_US    # Hello! My name is Albert.
        Bad News            en_US    # Hello! My name is Bad News.
        Eddy (中文（中国大陆）)     zh_CN    # 你好！我叫Eddy。
        """

        let voices = MacOSVoiceCatalog.parseSayVoiceList(output)

        XCTAssertEqual(voices.count, 3)
        XCTAssertEqual(voices[0], MacOSVoice(name: "Albert", languageCode: "en-US", sample: "Hello! My name is Albert."))
        XCTAssertEqual(voices[1].name, "Bad News")
        XCTAssertEqual(voices[2].name, "Eddy (中文（中国大陆）)")
        XCTAssertEqual(voices[2].languageCode, "zh-CN")
        XCTAssertEqual(voices[2].sample, "你好！我叫Eddy。")
    }
}
