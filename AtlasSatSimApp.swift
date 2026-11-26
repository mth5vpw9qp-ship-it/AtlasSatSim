import SwiftUI
import UIKit
import Foundation

@main
struct AtlasSatSimApp: App {
    var body: some Scene { WindowGroup { AtlasDashboardView() } }
}

// Capability adapters intentionally report status only. No exploit or system modification is implemented.
enum CapabilityState: String {
    case available = "Available"
    case unlinked = "Not linked"
    case uninitialized = "Not initialized"
    case simulation = "Simulation only"
    case unverified = "Unverified"
}

struct ComponentStatus: Identifiable {
    let id = UUID()
    let name: String
    let state: CapabilityState
    let detail: String
}

protocol AtlasAdapter {
    var name: String { get }
    var status: CapabilityState { get }
    var detail: String { get }
}

// These adapters deliberately stop at integration/compatibility reporting.
// HookKit is a jailbreak-side hooking runtime, not a general-purpose API for a
// sandboxed iOS app. Procursus and RootHide are bootstrap environments, not
// Swift packages that this app can install or activate.
struct HookKitAdapter: AtlasAdapter {
    let name = "HookKit"

    #if canImport(HookKit)
    let status: CapabilityState = .uninitialized
    let detail = "HookKit module is visible at build time. No runtime is created and no hooks are installed."
    #else
    let status: CapabilityState = .unlinked
    let detail = "HookKit SDK is not linked. It must be integrated in a compatible jailbreak-side target; this app does not perform injection."
    #endif
}

struct ProcursusAdapter: AtlasAdapter {
    let name = "Procursus"
    let status: CapabilityState = .unverified
    let detail = "External bootstrap/package environment. Installation and presence cannot be verified from this sandboxed app."
}

struct RootHideAdapter: AtlasAdapter {
    let name = "RootHide"
    let status: CapabilityState = .unverified
    let detail = "Separate RootHide bootstrap lane. It is not combined with Procursus and cannot be installed or verified by this app."
}

enum DeviceDiagnostics {
    static var model: String { UIDevice.current.model }
    static var osVersion: String { UIDevice.current.systemVersion }
    static var architecture: String {
        #if arch(arm64)
        return "arm64 (arm64e capability is not asserted by this app)"
        #else
        return "Unknown / simulator architecture"
        #endif
    }
}

struct SimulationScenario: Identifiable, Hashable {
    let id: Int
    let title: String
    let steps: [String]
    static let all: [SimulationScenario] = [
        .init(id: 1, title: "Emergency SOS flow (simulation)", steps: ["Scenario selected", "Searching for a clear view", "Simulated message prepared", "Simulation complete — nothing was transmitted"]),
        .init(id: 2, title: "Roadside assistance (simulation)", steps: ["Scenario selected", "Location payload simulated", "Assistance request previewed", "Simulation complete — no service contacted"]),
        .init(id: 3, title: "Find My location (simulation)", steps: ["Scenario selected", "Location sharing flow simulated", "Recipient preview displayed", "Simulation complete — no location was sent"]),
        .init(id: 4, title: "Connectivity unavailable (simulation)", steps: ["Scenario selected", "No-network condition simulated", "Retry guidance displayed", "Simulation complete — device radios untouched"])
    ]
}

struct AtlasDashboardView: View {
    @State private var selected: SimulationScenario?
    @State private var output = ["Atlas initialized in informational mode.", "No jailbreak, kernel access, or satellite communication is active."]
    private let adapters: [AtlasAdapter] = [HookKitAdapter(), ProcursusAdapter(), RootHideAdapter()]

    var body: some View {
        NavigationView {
            List {
                Section("Device diagnostics") {
                    row("Device", DeviceDiagnostics.model)
                    row("iOS", DeviceDiagnostics.osVersion)
                    row("Architecture", DeviceDiagnostics.architecture)
                }
                Section("Atlas components") {
                    row("Atlas Core", "Available — diagnostics only")
                    ForEach(adapters, id: \.name) { row($0.name, "\($0.status.rawValue) — \($0.detail)") }
                    row("Kernel mechanism", "Unverified — no mechanism implemented")
                    row("Satellite simulator", "Simulation only")
                }
                Section("Satellite simulator") {
                    ForEach(SimulationScenario.all) { scenario in
                        Button(scenario.title) { run(scenario) }
                    }
                }
                Section("Diagnostic output") {
                    ForEach(Array(output.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.caption, design: .monospaced))
                    }
                }
                Section {
                    Text("All satellite scenarios are local scripted simulations. They do not communicate with CommCenter, satellite hardware, emergency services, or Find My.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Project Atlas")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(value).font(.caption).foregroundColor(.secondary) }
    }

    private func run(_ scenario: SimulationScenario) {
        selected = scenario
        output.append("▶ \(scenario.title)")
        output.append(contentsOf: scenario.steps)
    }
}
