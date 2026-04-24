# elaborator

iOS app that embeds the Lean elaborator and type-checks Lean source at runtime
on-device. Host `.olean` files are downloaded from a `lean4` release and
bundled into the app.

## Build

```
make sim-app          # build for the iOS simulator
make run-sim-app      # build, boot a simulator, and launch the app
make -f Makefile.device device-app  # build for a physical device
```
