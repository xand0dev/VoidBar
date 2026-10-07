import Foundation
import IOKit.pwr_mgt

/// Keeps the Mac awake: the same assertion `caffeinate -d` takes, held by
/// VoidBar itself instead of a helper process. The display stays on, and the
/// Mac with it. The system releases the assertion if VoidBar quits or crashes,
/// so it can never be left on by accident.
@MainActor
final class CaffeineStore: ObservableObject {
    @Published private(set) var isOn = false
    private var assertion = IOPMAssertionID(0)

    func toggle() {
        isOn ? turnOff() : turnOn()
    }

    func turnOn() {
        guard !isOn else { return }
        let reason = "VoidBar: keeping the Mac awake" as CFString
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertion
        )
        isOn = status == kIOReturnSuccess
    }

    func turnOff() {
        guard isOn else { return }
        IOPMAssertionRelease(assertion)
        assertion = IOPMAssertionID(0)
        isOn = false
    }
}
