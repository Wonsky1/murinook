import Foundation
import XCTest
@testable import MurinookDomain

final class HistoryLayoutPreferencesTests: XCTestCase {
    func testLegacyPreferencesAddListLayoutWithoutLosingExistingChoices() throws {
        let data = Data(#"{"retentionDays":90,"showsDockIcon":true,"languageCode":"uk"}"#.utf8)
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        XCTAssertEqual(json["historyLayout"] as? String, "list")
        XCTAssertEqual(preferences.retentionDays, 90)
        XCTAssertTrue(preferences.showsDockIcon)
        XCTAssertEqual(preferences.languageCode, "uk")
    }

    func testEveryLayoutPersistsAcrossEncodeDecode() throws {
        for layout in ["grid", "list", "strip"] {
            let preferences = try JSONDecoder().decode(AppPreferences.self, from: Data("{\"historyLayout\":\"\(layout)\"}".utf8))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
            XCTAssertEqual(json["historyLayout"] as? String, layout)
        }
    }
}
