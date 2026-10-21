# macOS AI VRAM Memory Manager

A small, native menu bar utility that makes Apple silicon's shared memory easier to understand while running local AI models.

## What it shows

- Live system memory use and available memory
- A conservative low-headroom indicator based on available memory
- The default Metal GPU's recommended working-set size
- `iogpu.wired_mem_limit`, when the running macOS exposes it

## What it does not claim

Apple silicon uses unified memory: CPU and GPU share physical RAM. A GPU allocation limit is a ceiling, not dedicated VRAM, a reservation, or a performance boost. Metal's recommended working-set size is a runtime recommendation; it does not guarantee a model will fit. Model weights, context/KV cache, runtime overhead, and other apps all consume memory.

This app is read-only. It does not run privileged commands, alter kernel settings, install launch daemons, or change system configuration. The available-memory figure is an estimate from active, wired, and compressed VM pages; it is not a substitute for macOS Activity Monitor's memory pressure graph.

## Download and run

Download the latest DMG from [GitHub Releases](https://github.com/cjtsh/macOS-AI-VRAM-Memory-Manager/releases), open it, and drag **Mac AI Memory Manager.app** into Applications. Open it; the memory-chip icon appears in the menu bar. The release workflow can sign and notarize the app when the repository has the Apple Developer signing secrets configured; without them, it produces an unsigned DMG that Gatekeeper may block.

Each successful GitHub Actions build also publishes a downloadable DMG artifact on that workflow run. To publish a versioned release, push a tag such as `v1.0.0`.

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

## Build from source

Requires macOS 14 or later and Swift 6.

```sh
bash scripts/package-app.sh && bash scripts/package-dmg.sh
```

## License

MIT. See [LICENSE](LICENSE).
