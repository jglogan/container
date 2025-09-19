//===----------------------------------------------------------------------===//
// Copyright © 2025 Apple Inc. and the container project authors. All rights reserved.
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

import ArgumentParser
import ContainerLog
import ContainerVersion
import Logging
import OSLog

@main
struct RuntimeLinuxHelper: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "container-runtime-linux",
        abstract: "XPC Service for managing a Linux sandbox",
        version: ReleaseVersion.singleLine(appName: "container-runtime-linux"),
        subcommands: [
            Prep.self,
            Start.self,
        ],
        defaultSubcommand: Start.self
    )

    package static func setupLogger(debug: Bool, metadata: [String: Logging.Logger.Metadata.Value] = [:]) -> Logging.Logger {
        LoggingSystem.bootstrap { label in
            OSLogHandler(
                label: label,
                category: "RuntimeLinuxHelper"
            )
        }

        var log = Logger(label: "com.apple.container")
        if debug {
            log.logLevel = .debug
        }

        for (key, val) in metadata {
            log[metadataKey: key] = val
        }

        return log
    }
}
