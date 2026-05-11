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

import ContainerAPIClient
import ContainerAPIService
import ContainerResource
import ContainerXPC
import Logging
import Testing

// MARK: - Mock

/// A test double for `NetworksServiceProtocol` that captures the arguments
/// passed to each method.
///
/// End-to-end harness tests that feed an `XPCMessage` through `NetworksHarness`
/// and inspect the reply require `XPCMessage.reply()` to succeed on a
/// standalone dictionary. Until that is addressed, this mock documents the
/// expected test-double shape and provides a compile-time check that the
/// protocol surface is correct.
actor MockNetworksService: NetworksServiceProtocol {
    private(set) var listCallCount = 0
    private(set) var lastCreatedConfig: NetworkConfiguration?
    private(set) var lastDeletedId: String?

    private let listResult: [NetworkState]

    init(listResult: [NetworkState] = []) {
        self.listResult = listResult
    }

    func list() async throws -> [NetworkState] {
        listCallCount += 1
        return listResult
    }

    func create(configuration: NetworkConfiguration) async throws -> NetworkState {
        lastCreatedConfig = configuration
        return .created(configuration)
    }

    func delete(id: String) async throws {
        lastDeletedId = id
    }
}

// MARK: - Tests

struct NetworksHarnessTests {

    /// `NetworksHarness` accepts any `NetworksServiceProtocol` conformer —
    /// compile-time guarantee that the protocol and harness are correctly shaped.
    @Test func harnessAcceptsMockService() throws {
        let mock = MockNetworksService()
        _ = NetworksHarness(service: mock, log: Logger(label: "test"))
    }
}
