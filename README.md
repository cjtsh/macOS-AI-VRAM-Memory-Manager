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

## Build and run

Requires macOS 14 or later and Swift 6.

```sh
swift run
```

The app appears as a memory-chip icon in the menu bar. Select it to open the live panel.

## License

MIT. See [LICENSE](LICENSE).
