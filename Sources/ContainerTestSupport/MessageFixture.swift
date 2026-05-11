//===----------------------------------------------------------------------===//
// Copyright © 2026 Apple Inc. and the container project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

#if os(macOS)
import ContainerXPC
import Foundation
import SystemPackage

/// A serialisable snapshot of an `XPCMessage`'s wire content.
///
/// Fixture files are committed to the repository and **never auto-updated**.
/// They represent the wire format at the named protocol version. A test that
/// compares a live message against a fixture will fail if the format diverges,
/// requiring a deliberate fixture update and version bump.
///
/// ## Workflow
///
/// 1. Write a test that calls ``verifyMatchesFixture(_:named:version:sourceFile:)``.
/// 2. Run it once — the fixture file is written next to your test in a
///    `Fixtures/` subdirectory and the test passes.
/// 3. Review the generated JSON, then commit it alongside the test.
/// 4. Future runs compare the live message against the stored fixture; any
///    divergence fails the test.
/// 5. To update an existing fixture (e.g. after a deliberate wire-format
///    change), delete the JSON file and re-run step 2.
public struct MessageFixture: Codable, Sendable {
    public let protocolVersion: String
    public let route: String
    public let strings: [String: String]
    public let bools: [String: Bool]
    public let int64s: [String: Int64]
    /// Binary XPC data values encoded as Base64 strings.
    public let data: [String: String]
}

// MARK: - Capture

extension MessageFixture {
    /// Build a fixture by inspecting every key-value pair in `message`.
    public static func capture(
        from message: XPCMessage,
        protocolVersion: ProtocolVersion
    ) -> MessageFixture {
        var strings: [String: String] = [:]
        var bools: [String: Bool] = [:]
        var int64s: [String: Int64] = [:]
        var dataFields: [String: String] = [:]

        xpc_dictionary_apply(message.underlying) { rawKey, value in
            let key = String(cString: rawKey)
            // The route key is captured separately via message.string(key:).
            if key == XPCMessage.routeKey { return true }
            switch xpc_get_type(value) {
            case XPC_TYPE_STRING:
                if let ptr = xpc_string_get_string_ptr(value) {
                    strings[key] = String(cString: ptr)
                }
            case XPC_TYPE_BOOL:
                bools[key] = xpc_bool_get_value(value)
            case XPC_TYPE_INT64:
                int64s[key] = xpc_int64_get_value(value)
            case XPC_TYPE_DATA:
                if let ptr = xpc_data_get_bytes_ptr(value) {
                    let bytes = Data(bytes: ptr, count: xpc_data_get_length(value))
                    dataFields[key] = bytes.base64EncodedString()
                }
            default:
                break
            }
            return true
        }

        return MessageFixture(
            protocolVersion: protocolVersion.description,
            route: message.string(key: XPCMessage.routeKey) ?? "",
            strings: strings,
            bools: bools,
            int64s: int64s,
            data: dataFields
        )
    }
}

// MARK: - Reconstruction

extension MessageFixture {
    /// Reconstruct an `XPCMessage` from this fixture.
    public func makeMessage() throws -> XPCMessage {
        let msg = XPCMessage(route: route)
        for (k, v) in strings { msg.set(key: k, value: v) }
        for (k, v) in bools { msg.set(key: k, value: v) }
        for (k, v) in int64s { msg.set(key: k, value: v) }
        for (k, v) in data {
            guard let bytes = Data(base64Encoded: v) else {
                throw MessageFixtureError.invalidBase64(key: k)
            }
            msg.set(key: k, value: bytes)
        }
        return msg
    }
}

// MARK: - Verification

/// Verifies that `message` matches the stored fixture `"\(name).json"`.
///
/// The fixture file is looked up in a `Fixtures/` directory that sits
/// alongside the calling test file (resolved via `sourceFile`). On the first
/// call, when no fixture exists yet, the file is created and the function
/// returns normally so the test passes. Commit the generated file; subsequent
/// runs will compare against it.
///
/// Throws `MessageFixtureMismatch` if the live message diverges from the
/// stored fixture.
public func verifyMatchesFixture(
    _ message: XPCMessage,
    named name: String,
    version: ProtocolVersion,
    sourceFile: StaticString = #filePath
) throws {
    let fixtureDir = fixturesDirectory(relativeTo: sourceFile)
    let fixturePath = fixtureDir.appending("\(name).json")

    let current = MessageFixture.capture(from: message, protocolVersion: version)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    if !FileManager.default.fileExists(atPath: fixturePath.string) {
        try FileManager.default.createDirectory(
            atPath: fixtureDir.string,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try encoder.encode(current).write(to: URL(filePath: fixturePath.string))
        return
    }

    let stored = try JSONDecoder().decode(
        MessageFixture.self,
        from: Data(contentsOf: URL(filePath: fixturePath.string))
    )

    var mismatches: [String] = []
    if stored.protocolVersion != current.protocolVersion {
        mismatches.append("protocolVersion: stored=\(stored.protocolVersion) current=\(current.protocolVersion)")
    }
    if stored.route != current.route {
        mismatches.append("route: stored=\(stored.route) current=\(current.route)")
    }
    if stored.strings != current.strings {
        mismatches.append("strings: stored=\(stored.strings) current=\(current.strings)")
    }
    if stored.bools != current.bools {
        mismatches.append("bools: stored=\(stored.bools) current=\(current.bools)")
    }
    if stored.int64s != current.int64s {
        mismatches.append("int64s: stored=\(stored.int64s) current=\(current.int64s)")
    }
    if stored.data != current.data {
        mismatches.append("data keys/values differ")
    }

    if !mismatches.isEmpty {
        throw MessageFixtureMismatch(name: name, mismatches: mismatches)
    }
}

private func fixturesDirectory(relativeTo sourceFile: StaticString) -> FilePath {
    FilePath(String(describing: sourceFile))
        .removingLastComponent()
        .appending("Fixtures")
}

// MARK: - Errors

public struct MessageFixtureMismatch: Error, CustomStringConvertible {
    public let name: String
    public let mismatches: [String]

    public var description: String {
        "Fixture '\(name)' mismatch:\n" + mismatches.map { "  • \($0)" }.joined(separator: "\n")
    }
}

public enum MessageFixtureError: Error {
    case invalidBase64(key: String)
}

#endif
