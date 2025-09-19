import ArgumentParser
import ContainerPlugin
import Foundation
import Logging

extension Application {
    struct SystemPrep: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "prep",
            abstract: "Perform pre-installation tasks"
        )

        @Option(
            name: .shortAndLong,
            help: "Path to the root directory for application data",
            transform: { URL(filePath: $0) })
        var appRoot = ApplicationRoot.defaultURL

        @Option(
            name: .long,
            help: "Path to the root directory for application executables and plugins",
            transform: { URL(filePath: $0) })
        public var installRoot = InstallRoot.defaultURL

        func run() throws {
            LoggingSystem.bootstrap { label in
                PlainTextStderrLogHandler(label: label)
            }

            let log = Logger(label: "TODO")
            let pluginLoader = try initializePluginLoader(log: log)
            triggerLocalNetworkPrivacyAlert(pluginLoader: pluginLoader, log: log)
        }

        private func initializePluginLoader(log: Logger) throws -> PluginLoader {
            log.info(
                "initializing plugin loader",
                metadata: [
                    "installRoot": "\(installRoot.path(percentEncoded: false))"
                ])

            let pluginsURL = PluginLoader.userPluginsDir(installRoot: installRoot)
            log.info("detecting user plugins directory", metadata: ["path": "\(pluginsURL.path(percentEncoded: false))"])
            var directoryExists: ObjCBool = false
            _ = FileManager.default.fileExists(atPath: pluginsURL.path, isDirectory: &directoryExists)
            let userPluginsURL = directoryExists.boolValue ? pluginsURL : nil

            // plugins built into the application installed as a macOS app bundle
            let appBundlePluginsURL = Bundle.main.resourceURL?.appending(path: "plugins")

            // plugins built into the application installed as a Unix-like application
            let installRootPluginsURL =
                installRoot
                .appendingPathComponent("libexec")
                .appendingPathComponent("container")
                .appendingPathComponent("plugins")
                .standardized

            let pluginDirectories = [
                userPluginsURL,
                appBundlePluginsURL,
                installRootPluginsURL,
            ].compactMap { $0 }

            let pluginFactories: [PluginFactory] = [
                DefaultPluginFactory(),
                AppBundlePluginFactory(),
            ]

            for pluginDirectory in pluginDirectories {
                log.info("discovered plugin directory", metadata: ["path": "\(pluginDirectory.path(percentEncoded: false))"])
            }

            return try PluginLoader(
                appRoot: appRoot,
                installRoot: installRoot,
                pluginDirectories: pluginDirectories,
                pluginFactories: pluginFactories,
                log: log
            )
        }

        private func triggerLocalNetworkPrivacyAlert(pluginLoader: PluginLoader, log: Logger) {
            let runtimePlugins = pluginLoader.findPlugins().filter { $0.hasType(.runtime) }
            log.info("found plugins \(runtimePlugins.map {$0.name})")
            for plugin in runtimePlugins {
                log.info("triggering local network privacy prompt for \(["\(plugin.binaryURL.path)", "prep"])")
                let label = plugin.getLaunchdLabel()
                let plist = LaunchPlist(
                    label: label,
                    arguments: [
                        plugin.binaryURL.path(percentEncoded: false),
                        "prep",
                    ],
                    environment: [:],
                    limitLoadToSessionType: [.Aqua, .Background, .System],
                    runAtLoad: true,
                    stdout: "/tmp/prep-stdout.txt",
                    stderr: "/tmp/prep-stderr.txt",
                    keepAlive: false,
                    machServices: []
                )

                let plistURL = URL(filePath: "/tmp/prep.plist")
                guard let data = try? plist.encode() else {
                    log.error("failed to create plist for \(["\(plugin.binaryURL.path)", "prep"])")
                    continue
                }
                guard (try? data.write(to: plistURL)) != nil else {
                    log.error("failed to write plist for \(["\(plugin.binaryURL.path)", "prep"])")
                    continue
                }
                guard (try? ServiceManager.register(plistPath: plistURL.path)) != nil else {
                    log.error("failed to register plist for \(["\(plugin.binaryURL.path)", "prep"])")
                    continue
                }

                guard (try? ServiceManager.deregister(fullServiceLabel: label)) != nil else {
                    log.error("failed to deregister plist for \(["\(plugin.binaryURL.path)", "prep"])")
                    continue
                }

                log.info("triggered local network privacy prompt for \(plugin.name)")
            }
        }
    }
}

struct PlainTextStderrLogHandler: LogHandler {
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .info
    private let label: String
    
    init(label: String) {
        self.label = label
    }
    
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
    
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt)
    {
        fputs("\(message)\n", stderr)
    }
}
