// swift-tools-version: 5.10
// Package.swift ≈ build.gradle / pubspec.yaml: declares targets and how they link.
import PackageDescription

let package = Package(
    name: "SwipeSwitcher",
    platforms: [.macOS("15.0")], // 15+ for `Atomic` (Synchronization module)
    targets: [
        // C header describing Apple's private MultitouchSupport API (no public Swift API exists).
        .target(name: "CMultitouch"),
        .executableTarget(
            name: "SwipeSwitcher",
            dependencies: ["CMultitouch"],
            linkerSettings: [.unsafeFlags([
                "-F/System/Library/PrivateFrameworks", "-framework", "MultitouchSupport",
            ])]
        ),
        .testTarget(name: "SwipeSwitcherTests", dependencies: ["SwipeSwitcher"]),
    ]
)
