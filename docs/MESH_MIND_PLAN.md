# MeshMind — local AI for the hardware you already own

## Product thesis

MeshMind turns a pile of old phones, tablets, laptops, and single-board
computers into one private AI workstation. The iPhone is the control surface;
the other devices contribute models, memory, or compute over the local network.
Nothing needs an account or a cloud round-trip.

## MVP promise

> Discover nearby devices, see what they can contribute, and send one prompt
> to the best available local model.

The first shippable version should make the network feel useful before it is
perfectly optimized. It will support one coordinator (the iOS app), several
worker nodes, a capability handshake, model routing, streamed output, and a
clear offline-only boundary.

## What exists in this prototype

- mDNS discovery and WebSocket mesh transport from the existing LanChat base.
- Bonsoir is pinned to the current 7.1.6 line, whose newer Linux adapter avoids
  the old Avahi version parsing failure observed on this workstation.
- A new MeshMind control surface built for a narrow mobile viewport, using a
  pale metallic/neumorphic hardware-console visual language.
- Local node activation, discovered worker cards, aggregate capacity, and a
  prompt console with a deterministic offline demo response.
- A capability handshake over the existing mesh. Nodes now advertise platform,
  memory, model names, and features; discovered worker cards consume that data.
- A streaming `LocalModelAdapter` contract and router. The current adapter is
  an honest offline fallback, so native GGUF/MLX execution can be plugged in
  without changing the prompt UI or routing API.
- Targeted inference envelopes over the mesh: request, chunk, complete, and
  error events. A worker can register the same local adapter and stream its
  output back to the requesting coordinator.
- A functional Model Bay import action for GGUF files, the format consumed by
  the bundled llama.cpp adapter.
  Imported files are copied into the app-support model directory, surfaced with
  their size, and passed to the native or local command runtime by durable path.
- A `MethodChannel('meshmind.inference')` native-runtime boundary plus a
  native-first adapter. iOS now loads GGUF through llama.cpp/Metal; Android
  remains explicit about its unavailable runtime and falls back to the local
  demo adapter.
- The Model Bay surfaces that runtime status directly: ready when a native
  adapter reports availability, or “fallback router ready” when it does not.
- Runtime status also reports battery percentage and thermal state so routing
  can avoid exhausting an old worker.
- Battery and thermal values now travel in the node capability handshake, and
  the router skips workers below 15% battery or at serious/critical thermal
  state.
- The worker request path retries locally after a worker timeout, preserving a
  usable single-device path when an old device disappears.
- Worker model-load and inference errors also retry locally, so an incompatible
  or partially configured legacy device cannot strand a prompt.
- Eligible workers are scored by memory, battery, and thermal state, then
  selected round-robin across equal requests so one healthy node does not
  become the permanent bottleneck.
- Imported Model Bay files are added to the local node's advertised model list,
  so nearby coordinators can route requests based on the updated capability
  handshake.
- Nodes no longer advertise a fictitious bundled model: a node only becomes a
  routable worker after a real imported model is registered.
- A node only advertises `text-generation` after its native or `llama-cli`
  runtime probe succeeds, so an imported file alone cannot create a dead worker.
- Mesh connections now require a per-session join token learned from the
  Bonjour service record; unauthenticated inbound WebSocket channels are
  closed before they can forward messages.
- Imported model paths now travel into the local adapter boundary. Desktop and
  laptop workers can use an installed `llama-cli` executable to stream real
  GGUF output; Android continues to use the native channel, awaiting a bundled
  llama.cpp runtime.
- Distributed execution is represented in the protocol. Workers can advertise
  an RPC endpoint, tensor memory, and split support; the coordinator creates a
  heterogeneous memory-weighted plan and sends it with the request. A
  distributed entrypoint launches current llama.cpp with `--rpc`,
  `--tensor-split`, and the safe default `layer` split mode. Model names also
  travel with requests so a mesh can host and route several models.
- Desktop nodes with `ggml-rpc-server` available start an optional RPC worker
  and advertise the LAN address. Mobile nodes remain coordinators or local
  workers unless a future mobile-native RPC runtime is bundled.
- iOS now includes a Swift Package wrapper around llama.cpp's Metal-capable
  XCFramework. The Flutter method channel loads the imported GGUF path on a
  background queue and returns native output; the package keeps iOS 14 as the
  minimum deployment target.

The Android target still returns an explicit unavailable status until its
llama.cpp runtime is bundled. The Linux build remains the reproducible local
verification target, and a legacy laptop with `llama-cli` installed can become
a real GGUF worker after importing a model file. The iOS runtime package is
resolved by Xcode from the pinned llama.cpp XCFramework release, so its final
compile/signing check requires macOS with Xcode.
- A visible distinction between the iPhone coordinator and discovered peers.

The demo response remains intentionally labeled in the UI when no model or
runtime is available.

## Delivery plan

### Phase 1 — prove the loop

1. iOS coordinator starts without an account.
2. Devices advertise `{id, name, platform, ram, model, capabilities}` over the
   existing local mesh.
3. Coordinator scores nodes for a request and assigns a worker.
4. Worker streams tokens back; the UI shows which device answered.
5. Requests fail soft when a legacy device disappears.

### Phase 2 — make old hardware useful

- Worker adapters for llama.cpp / GGUF, MLX where available, and a tiny
  CPU-safe fallback model.
- Quantized model catalog with download/import from Files or a LAN share.
- Chunked prompt execution for devices with low RAM.
- Optional split-prefill/decode routing, with sequential fallback first.
- Heterogeneous tensor offload through current llama.cpp RPC: memory-weighted
  layer splitting across CPU/GPU-capable nodes, with a single-worker fallback
  when RPC is unavailable or a worker is unhealthy.

### Phase 3 — trust, polish, and ship

- Pairing code and per-node approval.
- Encrypted LAN transport and a clear “never leave this network” indicator.
- Battery, thermal, and bandwidth budgets.
- Background worker mode where the platform permits it.
- Accessibility, state restoration, exportable diagnostics, and TestFlight.

## Technical decisions

- Flutter remains the cross-platform shell because the existing discovery and
  iOS project already work across phones and desktop workers.
- iOS now declares the MeshMind display name plus Bonjour/local-network usage
  strings required for the coordinator to discover nearby workers.
- The protocol should be versioned JSON envelopes first; binary token and
  tensor streams can be added behind the same connection later.
- The iPhone is a coordinator, not necessarily the strongest worker.
- Routing is capability-based, then latency-aware, then battery-aware.
- A single-device path must always work; a mesh is an optimization, not a
  requirement for basic local inference.

## Risks to validate early

- iOS background execution and local-network permission can interrupt workers.
- “Combine many devices” is not automatically faster: network latency and
  model synchronization can erase gains. MeshMind therefore defaults to layer
  splitting, weights placements by usable tensor memory, and falls back to one
  worker or the coordinator when distributed RPC is unavailable. Tensor
  parallel mode remains opt-in/experimental.
- Older devices may not support the same model format or quantization. The
  capability handshake must be stricter than a generic “AI ready” flag.
- Thermals and battery are product constraints, not implementation details.

## Success criteria for the next milestone

On two devices on the same Wi-Fi, the iPhone shows the second device as a
worker, sends it a prompt, receives a streamed answer, and tells the user
which node handled the request. With two current llama.cpp RPC workers and a
desktop entrypoint, the request includes a memory-weighted split plan and the
entrypoint launches one model across both endpoints. If a worker vanishes or
RPC is unsupported, the prompt retries on one worker or the iPhone.
