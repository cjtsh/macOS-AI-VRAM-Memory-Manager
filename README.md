# macOS AI VRAM Memory Manager

A small, native menu bar utility that makes Apple silicon's shared memory easier to understand while running local AI models.

## What it shows

- Live system memory use and available memory
- A conservative low-headroom indicator based on available memory
- The default Metal GPU's recommended working-set size
- The GPU wired-memory ceiling `iogpu.wired_limit_mb`, when the running macOS exposes it
- Controls to request a preset or custom GPU ceiling, or restore system-managed behavior

## What it does not claim

Apple silicon uses unified memory: CPU and GPU share physical RAM. A GPU allocation limit is a ceiling, not dedicated VRAM, a reservation, or a performance boost. Metal's recommended working-set size is a runtime recommendation; it does not guarantee a model will fit. Model weights, context/KV cache, runtime overhead, and other apps all consume memory.

By default the app only reports information. On macOS versions that expose `iogpu.wired_limit_mb`, you can explicitly apply a system-wide GPU wired-memory ceiling for the current session or reset it to system-managed. Applying a change requires the macOS administrator authorization prompt. The change is not persistent and returns to system-managed after restart. The app never applies a value just because you selected it.

This GPU setting is undocumented by Apple and may change or disappear in a macOS update. The ceiling does not reserve RAM or increase GPU speed. Larger values reduce memory headroom for macOS and other apps and can cause heavy swapping, slowdowns, hangs, forced restarts, or data loss. The app caps its slider at 95% of physical memory and warns above 90%; these are application guardrails, not Apple recommendations. The available-memory figure is an estimate from active, wired, and compressed VM pages; it is not a substitute for macOS Activity Monitor's memory pressure graph.

## Download and run

Download the latest DMG from [GitHub Releases](https://github.com/cjtsh/macOS-AI-VRAM-Memory-Manager/releases), open it, and drag **Mac AI Memory Manager.app** into Applications. Opening the app shows its dashboard window and adds a memory icon to the menu bar. The release workflow signs and notarizes releases when the repository has the Apple Developer signing secrets configured. The app includes its terms and MIT license in the app's **Terms & License** view, and the DMG includes separate copies of both documents.

Each successful GitHub Actions build also publishes a downloadable DMG artifact on that workflow run. To publish a versioned release, push a tag such as `v1.2.1`.

### Developer ID signing and notarization

To make releases launch without Gatekeeper warnings, add these repository Actions secrets under **Settings → Secrets and variables → Actions**:

- `DEVELOPER_ID_APPLICATION_P12`: base64 text for your exported Developer ID Application `.p12` certificate (`base64 -i DeveloperID.p12 | pbcopy` on macOS)
- `DEVELOPER_ID_APPLICATION_PASSWORD`: password used to export that `.p12`
- `BUILD_KEYCHAIN_PASSWORD`: a new temporary keychain password for CI
- `DEVELOPER_ID_APPLICATION_IDENTITY`: exact identity string from `security find-identity -v -p codesigning`
- `APPLE_ID`: Apple Developer account email
- `APPLE_TEAM_ID`: 10-character Apple Developer Team ID
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization

The build signs the app, submits it to Apple for notarization, staples the app and DMG, then uploads the notarized DMG to the GitHub Release. Keep certificate and account passwords in GitHub Secrets; never commit them to the repository.

## License and disclaimer

This project uses the standard, unversioned MIT License. There is no “MIT License version 3.0.” The license and full disclaimer are in [LICENSE](LICENSE) and [TERMS.md](TERMS.md). The software is free and provided “as is,” without warranty or a promise of support. Use it at your own risk. Read the disclaimer before relying on displayed estimates or applying a system setting.

## Build from source

Requires macOS 14 or later and Swift 6.

```sh
bash scripts/package-app.sh && bash scripts/package-dmg.sh
```

## License

MIT. See [LICENSE](LICENSE).
