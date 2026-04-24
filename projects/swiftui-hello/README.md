# swiftui-hello

Minimal SwiftUI iOS app that calls a Lean function through a small C bridge.
The Swift side renders a `Text("Lean says: \(lean_ios_add_one(41))")` inside a
`WindowGroup`, and the Lean side is statically linked as
`libExampleApp.a` via Lake.

## Build

```
make sim-app          # build for the iOS simulator
make run-sim-app      # build, boot a simulator, and launch the app
make -f Makefile.device device-app  # build for a physical device
```
