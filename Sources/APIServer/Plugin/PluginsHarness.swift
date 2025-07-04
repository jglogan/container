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

import ContainerXPC
import ContainerizationError
import Foundation
import Logging

struct PluginsHarness {
    private let log: Logging.Logger
    private let service: PluginsService

    init(service: PluginsService, log: Logging.Logger) {
        self.log = log
        self.service = service
    }

    @Sendable
    func load(_ message: XPCMessage) async throws -> XPCMessage {
        let name = message.string(key: .pluginName)
        guard let name else {
            throw ContainerizationError(.invalidArgument, message: "no plugin name found")
        }

        try await service.load(name: name)
        let reply = message.reply()
        return reply
    }

    @Sendable
    func get(_ message: XPCMessage) async throws -> XPCMessage {
        let name = message.string(key: .pluginName)
        guard let name else {
            throw ContainerizationError(.invalidArgument, message: "no plugin name found")
        }

        let plugin = try await service.get(name: name)
        let data = try JSONEncoder().encode(plugin)

        let reply = message.reply()
        reply.set(key: .plugin, value: data)
        return reply
    }

    @Sendable
    func restart(_ message: XPCMessage) async throws -> XPCMessage {
        let name = message.string(key: .pluginName)
        guard let name else {
            throw ContainerizationError(.invalidArgument, message: "no plugin name found")
        }

        try await service.restart(name: name)
        let reply = message.reply()
        return reply
    }

    @Sendable
    func unload(_ message: XPCMessage) async throws -> XPCMessage {
        let name = message.string(key: .pluginName)
        guard let name else {
            throw ContainerizationError(.invalidArgument, message: "no plugin name found")
        }

        try await service.unload(name: name)
        let reply = message.reply()
        return reply
    }

    @Sendable
    func list(_ message: XPCMessage) async throws -> XPCMessage {
        let plugins = try await service.list()

        let data = try JSONEncoder().encode(plugins)

        let reply = message.reply()
        reply.set(key: .plugins, value: data)
        return reply
    }
}
