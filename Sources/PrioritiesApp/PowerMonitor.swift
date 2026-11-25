import Combine
import Foundation
import IOKit.ps

@MainActor
final class PowerMonitor: ObservableObject {
    @Published private(set) var isPluggedIn = false
    @Published private(set) var batteryPercent: Double?
    @Published private(set) var statusDescription = "Checking power status"
    private var timer: Timer?

    init() {
        refresh()
        // Polling also catches a changed source after the Mac wakes from sleep.
        let pollTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        pollTimer.tolerance = 0.1
        RunLoop.main.add(pollTimer, forMode: .common)
        timer = pollTimer
    }

    deinit { timer?.invalidate() }

    func canRun(minimumBattery: Double) -> Bool {
        if isPluggedIn { return true }
        guard let batteryPercent, minimumBattery.isFinite else { return false }
        return batteryPercent >= min(100, max(0, minimumBattery))
    }

    func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            setUnavailable()
            return
        }
        let sourceType = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        let pluggedIn = sourceType == kIOPSACPowerValue
        var percentage: Double?
        if let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let values = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                      values[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                      let current = values[kIOPSCurrentCapacityKey] as? NSNumber,
                      let maximum = values[kIOPSMaxCapacityKey] as? NSNumber,
                      maximum.doubleValue > 0 else { continue }
                percentage = min(100, max(0, current.doubleValue / maximum.doubleValue * 100))
                break
            }
        }
        if isPluggedIn != pluggedIn { isPluggedIn = pluggedIn }
        if batteryPercent != percentage { batteryPercent = percentage }
        let description: String
        if pluggedIn {
            description = percentage.map { "Plugged in, \(Int($0.rounded()))% battery" } ?? "Plugged in"
        } else if let percentage {
            description = "On battery, \(Int(percentage.rounded()))% remaining"
        } else {
            description = "Power status unavailable"
        }
        if statusDescription != description { statusDescription = description }
    }

    private func setUnavailable() {
        isPluggedIn = false
        batteryPercent = nil
        statusDescription = "Power status unavailable"
    }
}
