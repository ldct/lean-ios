import SwiftUI

@main
struct LeanIOSExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    let leanValue: UInt32 = {
        let v = lean_ios_add_one(41)
        NSLog("lean_ios_add_one(41) = %u", v)
        return v
    }()

    var body: some View {
        Text("Lean says: \(leanValue)")
            .font(.system(size: 28, weight: .semibold))
    }
}
