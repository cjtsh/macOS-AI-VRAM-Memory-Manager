import AppKit
import Metal
import SwiftUI

@main
struct MacAIMemoryManagerApp: App {
    @StateObject private var monitor = MemoryMonitor()

    var body: some Scene {
        MenuBarExtra {
            DashboardView(monitor: monitor)
                .frame(width: 360)
        } label: {
            Label("Memory", systemImage: "memorychip")
        }
        .menuBarExtraStyle(.window)

        Window("AI Memory Manager", id: "dashboard") {
            DashboardView(monitor: monitor)
                .frame(minWidth: 520, minHeight: 560)
        }
        .defaultSize(width: 560, height: 640)
    }
}

@MainActor
final class MemoryMonitor: ObservableObject {
    @Published private(set) var usedBytes: UInt64 = 0
    @Published private(set) var totalBytes = ProcessInfo.processInfo.physicalMemory
    @Published private(set) var gpuWorkingSet: UInt64?
    @Published private(set) var gpuName = "Metal GPU"
    @Published private(set) var wiredLimitMiB: Int32?
    @Published private(set) var updatedAt = Date()

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        totalBytes = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let page = UInt64(vm_page_size)
            let active = UInt64(stats.active_count) * page
            let wired = UInt64(stats.wire_count) * page
            let compressed = UInt64(stats.compressor_page_count) * page
            usedBytes = min(totalBytes, active + wired + compressed)
        }
        if let device = MTLCreateSystemDefaultDevice() {
            gpuName = device.name
            gpuWorkingSet = device.recommendedMaxWorkingSetSize
        }
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("iogpu.wired_limit_mb", &value, &size, nil, 0) == 0, value >= 0 {
            wiredLimitMiB = value
        } else {
            wiredLimitMiB = nil
        }
        updatedAt = Date()
    }

    var freeBytes: UInt64 { totalBytes > usedBytes ? totalBytes - usedBytes : 0 }
}

struct DashboardView: View {
    @ObservedObject var monitor: MemoryMonitor
    @State private var showingExplanation = false
    @State private var showingLegal = false

    private var fraction: Double {
        guard monitor.totalBytes > 0 else { return 0 }
        return Double(monitor.usedBytes) / Double(monitor.totalBytes)
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Memory Manager").font(.title2.bold())
                    Text("Unified memory, made understandable").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .help("Quit AI Memory Manager before installing an update")
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(format(monitor.usedBytes)).font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text("of \(format(monitor.totalBytes)) in use").foregroundStyle(.secondary)
                    Spacer()
                    Text(monitor.freeBytes < 3 * 1_073_741_824 ? "Low headroom" : "Live")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(statusColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor)
                }
                ProgressView(value: fraction).tint(statusColor).scaleEffect(x: 1, y: 1.5, anchor: .center)
                HStack { Text("Available ~\(format(monitor.freeBytes))"); Spacer(); Text("Updates every 2 sec") }
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Label("GPU & AI workloads", systemImage: "gpu")
                    .font(.headline)
                metric("GPU", value: monitor.gpuName)
                metric("Metal recommended working set", value: monitor.gpuWorkingSet.map(format) ?? "Unavailable")
                metric("GPU wired-memory ceiling", value: monitor.wiredLimitMiB.map { $0 == 0 ? "System managed" : format(UInt64($0) * 1_048_576) } ?? "Not exposed by this macOS")
            }
            .padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))

            MemoryLimitControls(monitor: monitor)

            VStack(alignment: .leading, spacing: 8) {
                Label("What this means", systemImage: "info.circle").font(.headline)
                Text("Apple silicon shares one pool of memory between the CPU and GPU. A larger GPU limit does not add memory or make the GPU faster; it can leave less room for macOS and other apps. The available estimate uses active, wired, and compressed pages.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("How AI model memory works") { showingExplanation = true }
                    .buttonStyle(.link).padding(.top, 2)
            }
            .padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))

            HStack {
                Text("Updated \(monitor.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button { monitor.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .buttonStyle(.borderless)
            }

            HStack {
                Label("Use at your own risk", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Terms & License") { showingLegal = true }
                    .font(.caption)
                    .buttonStyle(.link)
            }
        }
        .padding(20)
        }
        .sheet(isPresented: $showingLegal) { LegalInformationView() }
        .alert("AI model memory", isPresented: $showingExplanation) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Model weights, context (KV cache), and other apps all use the same physical memory. Metal’s recommended working-set size is a useful runtime signal, not a promise that every model will fit. Leave headroom for macOS and monitor memory pressure during long sessions.")
        }
    }

    private var statusColor: Color {
        monitor.freeBytes < 3 * 1_073_741_824 ? .orange : .green
    }

    private func metric(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).multilineTextAlignment(.trailing).lineLimit(2)
        }.font(.callout)
    }

    private func format(_ bytes: UInt64) -> String {
        ByteCountFormatStyle(style: .memory, allowedUnits: [.gb, .tb], spellsOutZero: false)
            .format(Int64(clamping: bytes))
    }
}

private struct MemoryLimitPreset: Identifiable {
    let percent: Int
    let gibibytes: Int
    var megabytes: Int32 { Int32(gibibytes * 1024) }
    var id: Int32 { megabytes }
    var title: String { "\(percent)% — \(gibibytes) GiB" }
}

private struct MemoryLimitControls: View {
    @ObservedObject var monitor: MemoryMonitor
    @State private var requestedMiB: Int32 = 0
    @State private var customGiB = 64.0
    @State private var initialized = false
    @State private var showingConfirmation = false
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var totalGiB: Double {
        Double(monitor.totalBytes) / 1_073_741_824
    }

    private var maximumGiB: Double {
        max(1, floor(totalGiB * 0.95))
    }

    private var presets: [MemoryLimitPreset] {
        var seen = Set<Int32>()
        return [75, 80, 85, 90, 95].compactMap { percent in
            let gib = Int(floor(totalGiB * Double(percent) / 100))
            guard gib > 0 else { return nil }
            let preset = MemoryLimitPreset(percent: percent, gibibytes: gib)
            guard seen.insert(preset.megabytes).inserted else { return nil }
            return preset
        }
    }

    private var requestedGiB: Double {
        Double(requestedMiB) / 1024
    }

    private var currentLimitText: String {
        guard let value = monitor.wiredLimitMiB else { return "Not available" }
        guard value != 0 else { return "System managed" }
        return String(format: "%.1f GiB", Double(value) / 1024)
    }

    private var requestText: String {
        requestedMiB == 0 ? "System managed" : String(format: "%.1f GiB", requestedGiB)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("GPU memory ceiling", systemImage: "slider.horizontal.3")
                .font(.headline)
            Text("Choose the maximum memory macOS may wire for the GPU. This is a ceiling, not a reservation or a speed boost.")
                .font(.callout).foregroundStyle(.secondary)

            if monitor.wiredLimitMiB == nil {
                Label("This macOS does not expose a supported control here.", systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Picker("Preset", selection: $requestedMiB) {
                    Text("System Managed").tag(Int32(0))
                    ForEach(presets) { preset in
                        Text(preset.title).tag(preset.megabytes)
                    }
                }
                .onChange(of: requestedMiB) { _, value in
                    guard value > 0 else { return }
                    customGiB = min(maximumGiB, max(1, (Double(value) / 1024).rounded()))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Custom ceiling")
                        Spacer()
                        Text(String(format: "%.0f GiB", customGiB))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $customGiB, in: 1...maximumGiB, step: 1) { Text("Custom GPU memory ceiling") }
                        .onChange(of: customGiB) { _, value in
                            requestedMiB = Int32(value) * 1024
                        }
                }

                HStack {
                    Text("Current setting")
                    Spacer()
                    Text(currentLimitText).foregroundStyle(.secondary)
                }
                .font(.callout)

                if requestedGiB > totalGiB * 0.90 {
                    Label("High ceiling: macOS and other apps have less memory headroom. This can make the Mac unresponsive.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }

                HStack {
                    Button(isApplying ? "Applying…" : "Apply for This Session") {
                        showingConfirmation = true
                    }
                    .disabled(isApplying || requestedMiB == monitor.wiredLimitMiB)

                    Spacer()

                    Button("Reset to System Managed") {
                        requestedMiB = 0
                        showingConfirmation = true
                    }
                    .disabled(isApplying || monitor.wiredLimitMiB == 0)
                }

                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .font(.caption).foregroundStyle(.red)
                }

                Text("Changes require administrator approval and last until restart. This macOS GPU setting is undocumented and may change in a future update.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            guard !initialized else { return }
            if let value = monitor.wiredLimitMiB {
                requestedMiB = value
                if value > 0 { customGiB = min(maximumGiB, max(1, Double(value) / 1024)) }
                else { customGiB = min(64, maximumGiB) }
            }
            initialized = true
        }
        .confirmationDialog("Apply GPU memory ceiling?", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Apply \(requestText)", role: .destructive) {
                applySelection()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This changes the system-wide GPU wired-memory ceiling for this session. It does not reserve memory, and a high value can leave too little headroom for macOS, causing slowdowns, hangs, forced restarts, or data loss. The change resets to system-managed after restart. Continue only if you understand the risk.")
        }
    }

    private func applySelection() {
        isApplying = true
        errorMessage = nil
        successMessage = nil
        let value = requestedMiB

        Task {
            do {
                try await PrivilegedSysctl.setWiredLimit(mebibytes: value)
                monitor.refresh()
                guard monitor.wiredLimitMiB == value else {
                    throw NSError(domain: "MemoryLimit", code: 1, userInfo: [NSLocalizedDescriptionKey: "macOS did not report the requested value after applying it. The setting may not be supported on this system."])
                }
                isApplying = false
                successMessage = value == 0 ? "System-managed mode restored." : "GPU ceiling updated for this session."
            } catch {
                isApplying = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum PrivilegedSysctl {
    static func setWiredLimit(mebibytes: Int32) async throws {
        guard mebibytes >= 0 else { throw SysctlError.invalidValue }
        let command = "/usr/sbin/sysctl -w iogpu.wired_limit_mb=\(mebibytes)"
        let script = "do shell script \"\(command)\" with administrator privileges"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                let output = Pipe()
                let errors = Pipe()
                process.standardOutput = output
                process.standardError = errors

                do {
                    try process.run()
                    let stdout = output.fileHandleForReading.readDataToEndOfFile()
                    let stderr = errors.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        let outputText = String(data: stderr.isEmpty ? stdout : stderr, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let message = outputText.flatMap { $0.isEmpty ? nil : $0 }
                            ?? "Administrator authorization was cancelled or the setting could not be changed."
                        continuation.resume(throwing: SysctlError.commandFailed(message))
                        return
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private enum SysctlError: LocalizedError {
        case invalidValue
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidValue:
                return "Choose a non-negative GPU memory ceiling."
            case .commandFailed(let message):
                return message
            }
        }
    }
}

private struct LegalInformationView: View {
    private var terms: AttributedString { Self.bundledText(named: "TERMS") }
    private var license: AttributedString { Self.bundledText(named: "LICENSE") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Use & Disclaimer").font(.title2.bold())
                Text(terms)
                    .font(.callout)
                    .textSelection(.enabled)
                Divider()
                Text("MIT License").font(.title2.bold())
                Text(license)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(minWidth: 540, minHeight: 580)
    }

    private static func bundledText(named name: String) -> AttributedString {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return AttributedString("The \(name).md file is included with the source and disk image.")
        }
        return (try? AttributedString(markdown: contents)) ?? AttributedString(contents)
    }
}
