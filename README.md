# lean-ios

Personal fork of [paulcadman/lean-ios](https://github.com/paulcadman/lean-ios)
— the shared Lean-4-for-iOS infrastructure plus my own projects built on top.

## Projects

<table>
  <tr>
    <td width="50%">
      <div align="center">
        <b><a href="projects/swiftui-hello">swiftui-hello</a></b>
        <br>
        <img src="assets/app-example.png" width="240"/>
        <br>
        <sub>Minimal SwiftUI iOS app calling a Lean function via a C bridge.</sub>
      </div>
    </td>
    <td width="50%">
      <div align="center">
        <b><a href="projects/elaborator">elaborator</a></b>
        <br>
        <img src="assets/ios-lean-example.png" width="240"/>
        <br>
        <sub>On-device Lean elaborator / type-checker.</sub>
      </div>
    </td>
  </tr>
</table>

## Shared infrastructure

- [`lean4/`](lean4/) — modified Lean 4 source tree so the runtime and stage0
  standard library can be compiled with the iOS toolchain and linked into
  native iOS apps.
- [`sdl-bindings/`](sdl-bindings/) — Lean bindings for SDL3 / SDL3_ttf (kept
  for future use; no project currently depends on them).
- [`app-common/`](app-common/) — common Makefiles and C framework for building
  iOS SDL3 apps.
- `scripts/`, top-level `Makefile` — cross-compile the Lean runtime + stage0
  stdlib for `arm64-apple-ios*-simulator` / device.

## Dependencies

1. Clone with submodules:

   ```
   git clone --recursive https://github.com/ldct/lean-ios.git
   ```

   Or, if already cloned:

   ```
   git submodule update --init --recursive
   ```

2. Install [Xcode](https://developer.apple.com/xcode/) (full Xcode.app — the
   Command Line Tools alone do not include the iOS simulator SDK).

3. Install the build dependencies via [Homebrew](https://brew.sh/):

   ```
   brew install cmake zstd
   ```

## Building

From the repo root:

```
make             # cross-compile Lean runtime + stage0 stdlib for iOS simulator
```

Then in a project directory (e.g. `projects/swiftui-hello`):

```
make sim-app       # build the .app bundle
make run-sim-app   # build, boot a simulator, install, launch
```

If the default simulator device (`iPhone 16` in the Makefile) isn't present on
your installed simulator runtime, override it:

```
SIMULATOR_DEVICE="iPhone 17" make run-sim-app
```

## Building for physical device

Each project has a `Makefile.device` target that codesigns and installs the app
on a connected iOS device. Invoke it with `make -f Makefile.device
run-device-app` and set the following environment variables:

- `DEVICE_ID` — the device UDID or name (as shown by `xcrun devicectl list devices`).
- `DEVICE_CODESIGN_IDENTITY` — the codesigning identity to use (e.g. `Apple
  Development: Your Name (TEAMID)`, as shown by `security find-identity -v -p
  codesigning`).
- `DEVICE_PROVISION_PROFILE` — path to a `.mobileprovision` file whose bundle
  identifier matches the project's `APP_BUNDLE_ID`.

## Architecture

See [docs/architecture.md](docs/architecture.md) for an overview of the
project structure and build dependencies (inherited from upstream).
