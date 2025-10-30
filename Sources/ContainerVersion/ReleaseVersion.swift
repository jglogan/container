//===----------------------------------------------------------------------===//
// Copyright © 2025 Apple Inc. and the container project authors.
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

import CVersion
import Foundation

public struct ReleaseVersion {
    public static func singleLine(appName: String) -> String {
        var versionDetails: [String: String] = ["build": "release"]
        #if DEBUG
        versionDetails["build"] = "debug"
        #endif
        versionDetails["commit"] = gitCommit().map { String($0.prefix(7)) } ?? "unspecified"
        let extras: String = versionDetails.map { "\($0): \($1)" }.sorted().joined(separator: ", ")

        return "\(appName) version \(version()) (\(extras))"
    }

    public static func version() -> String {
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let appBundle = Bundle.appBundle(memberURL: execURL)
        let bundleVersion = appBundle?.infoDictionary?["CFBundleShortVersionString"] as? String
        return bundleVersion ?? get_release_version().map { String(cString: $0) } ?? "0.0.0"
    }

    public static func gitCommit() -> String? {
        get_git_commit().map { String(cString: $0) }
    }
}
