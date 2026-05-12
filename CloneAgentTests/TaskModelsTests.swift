import XCTest

@testable import CloneAgent

final class TaskModelsTests: XCTestCase {
    func testDecodeAPITask() throws {
        let json = """
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "status": "summary_ready",
          "summaryMarkdown": "Hello",
          "previewUrl": null,
          "errorMessage": null,
          "createdAt": "2026-05-12T12:00:00.000Z",
          "updatedAt": "2026-05-12T12:00:01.000Z",
          "remoteAgentId": "agent-1",
          "remoteRunIdPhase1": "run-1",
          "remoteRunIdPhase2": null
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let task = try JSONDecoder().decode(APITask.self, from: data)
        XCTAssertEqual(task.id.uuidString.lowercased(), "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(task.status, .summaryReady)
        XCTAssertEqual(task.summaryMarkdown, "Hello")
        XCTAssertEqual(task.remoteAgentId, "agent-1")
    }
}
