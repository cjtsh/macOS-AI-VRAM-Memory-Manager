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
    @Published private(set) var wiredLimit: UInt64?
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
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("iogpu.wired_mem_limit", &value, &size, nil, 0) == 0 {
            wiredLimit = value
        } else {
            wiredLimit = nil
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Memory Manager").font(.title2.bold())
                    Text("Unified memory, made understandable").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.title2).foregroundStyle(.purple)
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
                metric("GPU wired memory limit", value: monitor.wiredLimit.map { $0 == 0 ? "System managed" : format($0 * 1_048_576) } ?? "Not exposed by this macOS")
            }
            .padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))

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
