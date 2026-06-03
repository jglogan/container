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

import ArgumentParser
import ContainerLog
import ContainerNetworkService
import ContainerNetworkServiceClient
import ContainerPlugin
import ContainerResource
import ContainerXPC
import ContainerizationError
import Foundation
import Logging

enum Variant: String {
    case reserved
    case allocationOnly
}

extension NetworkVmnetHelper {
    struct Start: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Starts the network plugin"
        )

        @Flag(name: .long, help: "Enable debug logging")
        var debug = false

        @Option(name: .long, help: "XPC service identifier")
        var serviceIdentifier: String

        @Option(name: .customLong("entity-path"), help: "Path to the network entity directory containing entity.json")
        var entityPath: String

        var logRoot = LogRoot.path

        func run() async throws {
            let commandName = NetworkVmnetHelper._commandName
            let configURL = URL(filePath: entityPath).appending(component: "entity.json")
            let configData = try Data(contentsOf: configURL)
            let configuration = try JSONDecoder().decode(NetworkConfiguration.self, from: configData)

            let id = configuration.id
            let logPath = logRoot.map { $0.appending("\(commandName)-\(id).log") }
            let log = ServiceLogger.bootstrap(category: "NetworkVmnetHelper", metadata: ["id": "\(id)"], debug: debug, logPath: logPath)
            log.info("starting helper", metadata: ["name": "\(commandName)"])
            defer {
                log.info("stopping helper", metadata: ["name": "\(commandName)"])
            }

            do {
                log.info("configuring XPC server")
                let variant = resolveVariant(from: configuration)
                let network = try Self.createNetwork(
                    configuration: configuration,
                    variant: variant,
                    log: log
                )
                try await network.start()
                let server = try await NetworkService(network: network, log: log)
                let xpc = XPCServer(
                    identifier: serviceIdentifier,
                    routes: [
                        NetworkRoutes.state.rawValue: XPCServer.route(server.state),
                        NetworkRoutes.allocate.rawValue: server.allocate,
                        NetworkRoutes.lookup.rawValue: XPCServer.route(server.lookup),
                        NetworkRoutes.disableAllocator.rawValue: XPCServer.route(server.disableAllocator),
                    ],
                    log: log
                )

                log.info("starting XPC server")
                try await xpc.listen()
            } catch {
                log.error(
                    "helper failed",
                    metadata: [
                        "name": "\(commandName)",
                        "error": "\(error)",
                    ])
                NetworkVmnetHelper.exit(withError: error)
            }
        }

        private func resolveVariant(from configuration: NetworkConfiguration) -> Variant {
            if let variantStr = configuration.pluginInfo?.variant,
                let parsed = Variant(rawValue: variantStr)
            {
                return parsed
            }
            if #available(macOS 26, *) {
                return .reserved
            }
            return .allocationOnly
        }

        private static func createNetwork(configuration: NetworkConfiguration, variant: Variant, log: Logger) throws -> Network {
            let pluginInfo = NetworkPluginInfo(
                plugin: configuration.pluginInfo?.plugin ?? NetworkVmnetHelper._commandName,
                variant: variant.rawValue
            )
            switch variant {
            case .allocationOnly:
                return try AllocationOnlyVmnetNetwork(configuration: configuration, pluginInfo: pluginInfo, log: log)
            case .reserved:
                guard #available(macOS 26, *) else {
                    throw ContainerizationError(
                        .invalidArgument,
                        message: "variant ReservedVmnetNetwork is only available on macOS 26+"
                    )
                }
                return try ReservedVmnetNetwork(configuration: configuration, pluginInfo: pluginInfo, log: log)
            }
        }
    }
}
