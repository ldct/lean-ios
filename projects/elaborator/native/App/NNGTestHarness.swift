import Foundation

/// Headless sweep harness for NNG-style sample files.
///
/// When the app is launched with `NNG_TEST_DIR` (a directory of `.lean`
/// files) and `NNG_TEST_OUT` (a writable output path) in its environment —
/// e.g. via `SIMCTL_CHILD_NNG_TEST_DIR=… xcrun simctl launch …` — every
/// sample is elaborated twice (cold header import, then warm re-check)
/// through the same bridge call the UI uses, and a JSON report with
/// per-run wall time and resident memory is written to `NNG_TEST_OUT`.
/// The UI stays usable; the sweep runs on a background queue.
enum NNGTestHarness {
  static func runIfRequested() {
    let env = ProcessInfo.processInfo.environment
    guard let dir = env["NNG_TEST_DIR"], let out = env["NNG_TEST_OUT"] else { return }
    DispatchQueue.global(qos: .userInitiated).async {
      run(dir: dir, out: out)
    }
  }

  private static func check(_ source: String) -> String? {
    guard let cRoot = Bundle.main.bundlePath.cString(using: .utf8),
      let cSrc = source.cString(using: .utf8),
      let raw = lean_ios_check_source(cRoot, cSrc),
      let (decoded, _) = String.decodeCString(
        UnsafeRawPointer(raw).assumingMemoryBound(to: UTF8.CodeUnit.self),
        as: UTF8.self
      )
    else { return nil }
    return decoded
  }

  /// Physical memory footprint in MB (what Xcode's memory gauge shows).
  private static func footprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard kr == KERN_SUCCESS else { return -1 }
    return Double(info.phys_footprint) / 1_048_576.0
  }

  private static func run(dir: String, out: String) {
    let fm = FileManager.default
    let files = ((try? fm.contentsOfDirectory(atPath: dir)) ?? [])
      .filter { $0.hasSuffix(".lean") }
      .sorted()
    var results: [[String: Any]] = []
    var allComplete = !files.isEmpty
    for f in files {
      let path = (dir as NSString).appendingPathComponent(f)
      guard let src = try? String(contentsOfFile: path, encoding: .utf8) else {
        results.append(["file": f, "error": "unreadable"])
        allComplete = false
        continue
      }
      let input = src + "\n  done\n"
      var entry: [String: Any] = ["file": f]
      for (label, key) in [("cold", "cold_ms"), ("warm", "warm_ms")] {
        let t0 = Date()
        let raw = check(input)
        entry[key] = Int(Date().timeIntervalSince(t0) * 1000)
        let complete = raw?.contains("\"complete\":true") ?? false
        entry["complete_\(label)"] = complete
        if !complete {
          entry["raw_\(label)"] = raw ?? "<bridge failure>"
          allComplete = false
        }
      }
      entry["footprint_mb"] = Int(footprintMB())
      results.append(entry)
      NSLog("NNGTestHarness: %@ %@", f, (entry["complete_cold"] as? Bool) == true ? "PASS" : "FAIL")
    }
    let report: [String: Any] = [
      "pass": allComplete,
      "count": files.count,
      "results": results,
    ]
    if let json = try? JSONSerialization.data(
      withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    {
      try? json.write(to: URL(fileURLWithPath: out))
    }
    NSLog("NNGTestHarness: done, pass=%@, report at %@", allComplete ? "true" : "false", out)
  }
}
