// swift-tools-version:5.10
// Northstar Navigator for the Mac, step 1: "find my files" (look only).
// Open this file in Xcode (File › Open), pick "My Mac" and press Run. See docs/navigator-step1.md.
import PackageDescription

let package = Package(
    name: "NavigatorMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "NavigatorMac", path: "Sources/NavigatorMac")
    ]
)
