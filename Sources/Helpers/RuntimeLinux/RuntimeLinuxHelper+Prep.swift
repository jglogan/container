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
import SocketForwarder

extension RuntimeLinuxHelper {
    struct Prep: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "prep",
            abstract: "Prepare system to run containers"
        )

        func run() async throws {
            let log = RuntimeLinuxHelper.setupLogger(debug: false)
            log.info("triggering local network privacy prompt")
            LocalNetworkPrivacy.triggerLocalNetworkPrivacyAlert()
        }
    }
}
