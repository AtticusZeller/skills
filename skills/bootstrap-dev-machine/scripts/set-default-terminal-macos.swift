#!/usr/bin/swift
import AppKit
import UniformTypeIdentifiers

// macOS has file-type defaults, not a universal terminal override for every app.
// Leave source-code file associations and unsupported URL schemes unchanged.
let checkOnly = CommandLine.arguments.contains("--check")
final class CompletionState: @unchecked Sendable {
    var finished = false
    var error: Error?
}
let bundleID = "com.mitchellh.ghostty"
guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
    fputs("Ghostty is not installed.\n", stderr)
    exit(1)
}
var types = [UTType.unixExecutable]
if let commandType = UTType(filenameExtension: "command"), !types.contains(commandType) {
    types.append(commandType)
}
for type in types {
    if !checkOnly {
        let state = CompletionState()
        NSWorkspace.shared.setDefaultApplication(at: application, toOpen: type) { error in
            state.error = error
            state.finished = true
        }
        let deadline = Date().addingTimeInterval(45)
        while !state.finished && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if !state.finished || state.error != nil {
            fputs("Unable to change \(type.identifier): \(String(describing: state.error)); macOS may require user confirmation.\n", stderr)
            exit(1)
        }
    }
    let current = NSWorkspace.shared.urlForApplication(toOpen: type)
    let currentID = current.flatMap { Bundle(url: $0)?.bundleIdentifier } ?? "unknown"
    print("\(type.identifier): \(currentID)")
    if currentID != bundleID { exit(1) }
}
