import SwiftUI
import UIKit
import Foundation
import Darwin

@main
struct AtlasSatSimApp: App {
    var body: some Scene { WindowGroup { AtlasDashboardView() } }
}

enum CapabilityState: String {
    case available = "Available"
    case unlinked = "Not linked"
    case uninitialized = "Not initialized"
    case unavailable = "Not accessible from app sandbox"
}

protocol AtlasAdapter {
    var name: String { get }
    var status: CapabilityState { get }
    var detail: String { get }
}

// This is a build-time linkage check only. It does not prove a runtime is active.
struct HookKitAdapter: AtlasAdapter {
    let name = "HookKit"
    #if canImport(HookKit)
    let status: CapabilityState = .uninitialized
    let detail = "The HookKit module is visible to the compiler. Runtime availability and hook state are not verified."
    #else
    let status: CapabilityState = .unlinked
    let detail = "HookKit is not linked to this app target."
    #endif
}

struct ProcursusAdapter: AtlasAdapter {
    let name = "Procursus"
    let status: CapabilityState = .unavailable
    let detail = "A sandboxed app cannot reliably inspect or control an external bootstrap environment."
}

struct RootHideAdapter: AtlasAdapter {
    let name = "RootHide"
    let status: CapabilityState = .unavailable
    let detail = "RootHide state cannot be reliably verified from this app sandbox."
}

struct KernelSnapshot {
    let systemName: String
    let kernelRelease: String
    let kernelVersion: String
    let machine: String

    static func read() -> KernelSnapshot {
        var info = utsname()
        guard uname(&info) == 0 else {
            return KernelSnapshot(
                systemName: "Unavailable",
                kernelRelease: "Unavailable",
                kernelVersion: "Unavailable",
                machine: "Unavailable"
            )
        }

        func string<T>(from value: inout T) -> String {
            withUnsafePointer(to: &value) {
                $0.withMemoryRebound(
                    to: CChar.self,
                    capacity: MemoryLayout<T>.size
                ) {
                    String(cString: $0)
                }
            }
        }

        let system = string(from: &info.sysname)
        let release = string(from: &info.release)
        let version = string(from: &info.version)
        let machine = string(from: &info.machine)

        return KernelSnapshot(
            systemName: system,
            kernelRelease: release,
            kernelVersion: version,
            machine: machine
        )
    }
}

struct DeviceSnapshot {
    let model: String
    let systemVersion: String
    let kernel: KernelSnapshot
    let processorCount: Int
    let physicalMemoryGB: String
    let uptime: String
    let thermalState: String

    static func read() -> DeviceSnapshot {
        let process = ProcessInfo.processInfo
        let memoryGB = Double(process.physicalMemory) / 1_073_741_824
        let uptimeSeconds = Int(process.systemUptime)
        let hours = uptimeSeconds / 3600
        let minutes = (uptimeSeconds % 3600) / 60

        let thermal: String
        switch process.thermalState {
        case .nominal: thermal = "Nominal"
        case .fair: thermal = "Fair"
        case .serious: thermal = "Serious"
        case .critical: thermal = "Critical"
        @unknown default: thermal = "Unknown"
        }

        return DeviceSnapshot(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            kernel: KernelSnapshot.read(),
            processorCount: process.activeProcessorCount,
            physicalMemoryGB: String(format: "%.1f GB", memoryGB),
            uptime: "\(hours)h \(minutes)m",
            thermalState: thermal
        )
    }
}

struct SimulationScenario: Identifiable, Hashable {
    let id: Int
    let title: String
    let steps: [String]

    static let all: [SimulationScenario] = [
        .init(id: 1, title: "Emergency SOS flow (simulation)", steps: [
            "Scenario selected",
            "Searching for a clear view",
            "Simulated message prepared",
            "Simulation complete — nothing was transmitted"
        ]),
        .init(id: 2, title: "Roadside assistance (simulation)", steps: [
            "Scenario selected",
            "Location payload simulated",
            "Assistance request previewed",
            "Simulation complete — no service contacted"
        ]),
        .init(id: 3, title: "Find My location (simulation)", steps: [
            "Scenario selected",
            "Location sharing flow simulated",
            "Recipient preview displayed",
            "Simulation complete — no location was sent"
        ]),
        .init(id: 4, title: "Connectivity unavailable (simulation)", steps: [
            "Scenario selected",
            "No-network condition simulated",
            "Retry guidance displayed",
            "Simulation complete — device radios untouched"
        ])
    ]
}

struct AtlasDashboardView: View {
    @State private var snapshot = DeviceSnapshot.read()
    @State private var output = [
        "Atlas initialized.",
        "Read-only device diagnostics are active.",
        "Kernel memory access and privilege escalation are not implemented."
    ]

    private let adapters: [AtlasAdapter] = [
        HookKitAdapter(),
        ProcursusAdapter(),
        RootHideAdapter()
    ]

    var body: some View {
        NavigationView {
            List {
                Section("Device diagnostics") {
                    row("Device", snapshot.model)
                    row("iOS version", snapshot.systemVersion)
                    row("Hardware identifier", snapshot.kernel.machine)
                    row("Processor cores", "\(snapshot.processorCount)")
                    row("Installed physical memory", snapshot.physicalMemoryGB)
                    row("System uptime", snapshot.uptime)
                    row("Thermal state", snapshot.thermalState)
                    Button("Refresh diagnostics") {
                        refreshDiagnostics()
                    }
                }

                Section("Kernel information — read only") {
                    row("Kernel family", snapshot.kernel.systemName)
                    row("Kernel release", snapshot.kernel.kernelRelease)
                    row("Kernel build string", snapshot.kernel.kernelVersion)
                    Text(
                        "These values come from uname(). They identify the running kernel; " +
                        "they do not provide kernel memory access, kernel read/write, or elevated privileges."
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }

                Section("Integration checks") {
                    ForEach(adapters, id: \.name) { adapter in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(adapter.name).font(.headline)
                                Spacer()
                                Text(adapter.status.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(adapter.detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }

                Section("Kernel capability") {
                    row("Kernel memory access", "Unavailable to this sandboxed app")
                    row("Kernel modification", "Not implemented")
                    row("Privilege escalation", "Not implemented")
                    row("Jailbreak state", "Not reliably detectable from this app")
                }

                Section("Satellite scenarios") {
                    ForEach(SimulationScenario.all) { scenario in
                        Button(scenario.title) {
                            run(scenario)
                        }
                    }
                }

                Section("Diagnostic log") {
                    ForEach(Array(output.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Project Atlas")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func refreshDiagnostics() {
        snapshot = DeviceSnapshot.read()
        output.append(
            "Device and kernel metadata refreshed at " +
            Date().formatted(date: .omitted, time: .standard) + "."
        )
    }

    private func run(_ scenario: SimulationScenario) {
        output.append("▶ \(scenario.title)")
        output.append(contentsOf: scenario.steps)
    }
}
