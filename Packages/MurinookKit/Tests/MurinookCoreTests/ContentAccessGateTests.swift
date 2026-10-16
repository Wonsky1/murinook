import XCTest
import MurinookUseCases

@MainActor
final class ContentAccessGateTests: XCTestCase {
    func testMaintenanceWaitsUntilSynchronousReadersRelease() async {
        let gate = ContentAccessGate()
        XCTAssertTrue(gate.tryBeginAccess())
        var maintenanceStarted = false

        let maintenance = Task {
            await gate.withMaintenance {
                maintenanceStarted = true
                XCTAssertFalse(gate.tryBeginAccess())
            }
        }
        await Task.yield()
        XCTAssertFalse(maintenanceStarted)

        gate.endAccess()
        await maintenance.value
        XCTAssertTrue(maintenanceStarted)
    }

    func testNestedReaderCanEnterWhileMaintenanceIsWaiting() async {
        let gate = ContentAccessGate()
        var nestedReaderFinished = false
        var maintenanceFinished = false

        let outerReader = Task {
            await gate.withAccess {
                let maintenance = Task {
                    await gate.withMaintenance { maintenanceFinished = true }
                }
                await Task.yield() // Let maintenance queue behind this reader.
                await gate.withAccess { nestedReaderFinished = true }
                return maintenance
            }
        }

        let maintenance = await outerReader.value
        XCTAssertTrue(nestedReaderFinished)
        await maintenance.value
        XCTAssertTrue(maintenanceFinished)
    }
}
