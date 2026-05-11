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

import ContainerResource
import ContainerTestSupport
import ContainerXPC
import Foundation
import Synchronization
import Testing

@testable import ContainerAPIClient

// MARK: - Helpers

private func fixtureConfig() throws -> NetworkConfiguration {
    try NetworkConfiguration(id: "fixture-net", mode: .nat, pluginInfo: nil)
}

private func listResponse(resources: [NetworkResource]) throws -> XPCMessage {
    let msg = XPCMessage(route: XPCRoute.networkList.rawValue)
    msg.set(key: XPCKeys.networkResources.rawValue, value: try JSONEncoder().encode(resources))
    return msg
}

private func listResponseLegacy(states: [NetworkState]) throws -> XPCMessage {
    let msg = XPCMessage(route: XPCRoute.networkList.rawValue)
    msg.set(key: XPCKeys.networkStates.rawValue, value: try JSONEncoder().encode(states))
    return msg
}

private func createResponse(config: NetworkConfiguration) throws -> XPCMessage {
    let msg = XPCMessage(route: XPCRoute.networkCreate.rawValue)
    msg.set(key: XPCKeys.networkResource.rawValue, value: try JSONEncoder().encode(NetworkResource(config: config)))
    return msg
}

private func createResponseLegacy(state: NetworkState) throws -> XPCMessage {
    let msg = XPCMessage(route: XPCRoute.networkCreate.rawValue)
    msg.set(key: XPCKeys.networkState.rawValue, value: try JSONEncoder().encode(state))
    return msg
}

// MARK: - Request encoding

struct NetworkClientTests {

    // MARK: Encoding

    @Test func listRequestEncoding() async throws {
        let captured = Mutex<XPCMessage?>(nil)
        let client = NetworkClient { msg, _ in
            captured.withLock { $0 = msg }
            return try listResponse(resources: [])
        }
        _ = try await client.list()
        let msg = try #require(captured.withLock { $0 })
        #expect(msg.string(key: XPCMessage.routeKey) == XPCRoute.networkList.rawValue)
        #expect(msg.string(key: XPCKeys.networkId.rawValue) == nil)
    }

    @Test func createRequestEncoding() async throws {
        let config = try fixtureConfig()
        let captured = Mutex<XPCMessage?>(nil)
        let client = NetworkClient { msg, _ in
            captured.withLock { $0 = msg }
            return try createResponse(config: config)
        }
        _ = try await client.create(configuration: config)
        let msg = try #require(captured.withLock { $0 })
        #expect(msg.string(key: XPCMessage.routeKey) == XPCRoute.networkCreate.rawValue)
        #expect(msg.string(key: XPCKeys.networkId.rawValue) == "fixture-net")
        let data = try #require(msg.dataNoCopy(key: XPCKeys.networkConfig.rawValue))
        let decoded = try JSONDecoder().decode(NetworkConfiguration.self, from: data)
        #expect(decoded.id == config.id)
        #expect(decoded.mode == config.mode)
    }

    @Test func deleteRequestEncoding() async throws {
        let captured = Mutex<XPCMessage?>(nil)
        let client = NetworkClient { msg, _ in
            captured.withLock { $0 = msg }
            return XPCMessage(route: "reply")
        }
        try await client.delete(id: "fixture-net")
        let msg = try #require(captured.withLock { $0 })
        #expect(msg.string(key: XPCMessage.routeKey) == XPCRoute.networkDelete.rawValue)
        #expect(msg.string(key: XPCKeys.networkId.rawValue) == "fixture-net")
    }

    // MARK: Fixture — request wire format

    @Test func listRequestMatchesFixture() async throws {
        let captured = Mutex<XPCMessage?>(nil)
        let client = NetworkClient { msg, _ in
            captured.withLock { $0 = msg }
            return try listResponse(resources: [])
        }
        _ = try await client.list()
        try verifyMatchesFixture(
            try #require(captured.withLock { $0 }),
            named: "network_list_request_v1",
            version: ContainerAPIProtocol.version
        )
    }

    @Test func createRequestMatchesFixture() async throws {
        let config = try fixtureConfig()
        let captured = Mutex<XPCMessage?>(nil)
        let client = NetworkClient { msg, _ in
            captured.withLock { $0 = msg }
            return try createResponse(config: config)
        }
        _ = try await client.create(configuration: config)
        try verifyMatchesFixture(
            try #require(captured.withLock { $0 }),
            named: "network_create_request_v1",
            version: ContainerAPIProtocol.version
        )
    }

    @Test func deleteRequestMatchesFixture() async throws {
        let captured = Mutex<XPCMessage?>(nil)
        let client = NetworkClient { msg, _ in
            captured.withLock { $0 = msg }
            return XPCMessage(route: "reply")
        }
        try await client.delete(id: "fixture-net")
        try verifyMatchesFixture(
            try #require(captured.withLock { $0 }),
            named: "network_delete_request_v1",
            version: ContainerAPIProtocol.version
        )
    }

    // MARK: Response decoding

    @Test func listDecodesNetworkResources() async throws {
        let config = try fixtureConfig()
        let client = NetworkClient { _, _ in try listResponse(resources: [NetworkResource(config: config)]) }
        let results = try await client.list()
        #expect(results.count == 1)
        #expect(results[0].id == "fixture-net")
    }

    @Test func listFallsBackToNetworkStates() async throws {
        let config = try fixtureConfig()
        let client = NetworkClient { _, _ in try listResponseLegacy(states: [.created(config)]) }
        let results = try await client.list()
        #expect(results.count == 1)
        #expect(results[0].id == "fixture-net")
    }

    @Test func listReturnsEmptyWhenNoKeys() async throws {
        let client = NetworkClient { _, _ in XPCMessage(route: "reply") }
        #expect(try await client.list().isEmpty)
    }

    @Test func createDecodesNetworkResource() async throws {
        let config = try fixtureConfig()
        let client = NetworkClient { _, _ in try createResponse(config: config) }
        #expect(try await client.create(configuration: config).id == "fixture-net")
    }

    @Test func createFallsBackToNetworkState() async throws {
        let config = try fixtureConfig()
        let client = NetworkClient { _, _ in try createResponseLegacy(state: .created(config)) }
        #expect(try await client.create(configuration: config).id == "fixture-net")
    }
}
