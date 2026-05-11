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
import Testing

struct NetworkProtocolStabilityTests {

    // MARK: - Version

    @Test func protocolVersion() {
        #expect(ContainerAPIProtocol.version.major == 1)
    }

    // MARK: - XPCKeys — network

    @Test func networkKeyRawValues() {
        #expect(XPCKeys.networkId.rawValue == "networkId")
        #expect(XPCKeys.networkConfig.rawValue == "networkConfig")
        #expect(XPCKeys.networkState.rawValue == "networkState")
        #expect(XPCKeys.networkStates.rawValue == "networkStates")
        #expect(XPCKeys.networkResource.rawValue == "networkResource")
        #expect(XPCKeys.networkResources.rawValue == "networkResources")
    }

    // MARK: - XPCRoute — network

    @Test func networkRouteRawValues() {
        #expect(XPCRoute.networkCreate.rawValue == "networkCreate")
        #expect(XPCRoute.networkDelete.rawValue == "networkDelete")
        #expect(XPCRoute.networkList.rawValue == "networkList")
    }
}
