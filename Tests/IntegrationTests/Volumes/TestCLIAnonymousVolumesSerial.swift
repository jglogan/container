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
import Foundation
import Testing

@Suite(.serialized)
struct TestCLIAnonymousVolumesSerial {
    private let alpine = ContainerFixture.warmupImages[0]

    @Test func testAnonymousVolumeCreationAndPersistence() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup {
                try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
                f.doCleanupAnonymousVolumes()
            }

            let beforeCount = try f.getAnonymousVolumeNames().count
            let result = try f.run(["run", "--rm", "--name", c, "-v", "/data", image, "echo", "test"])
            #expect(result.status == 0)
            try await Task.sleep(for: .seconds(1))

            let lsResult = try f.run(["ls", "-a"])
            #expect(
                !lsResult.output.components(separatedBy: .newlines).contains { $0.contains(c) },
                "container should be removed with --rm")

            let afterCount = try f.getAnonymousVolumeNames().count
            #expect(afterCount == beforeCount + 1, "anonymous volume should persist even with --rm")
        }
    }

    @Test func testAnonymousVolumePersistenceWithoutRm() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup {
                try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
                f.doCleanupAnonymousVolumes()
            }

            try f.doLongRun(name: c, image: image, args: ["-v", "/data"], autoRemove: false)
            try f.waitForContainerRunning(c)
            _ = try f.doExec(c, cmd: ["sh", "-c", "echo 'persistent-data' > /data/test.txt"])

            let volumeNames = try f.getAnonymousVolumeNames()
            #expect(volumeNames.count == 1, "should have exactly one anonymous volume")
            let volumeID = volumeNames[0]

            try f.doStop(c)
            try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
            #expect(try f.volumeExists(volumeID), "anonymous volume should persist without --rm")

            let c2 = "\(f.testID)-c2"
            try f.doLongRun(name: c2, image: image, args: ["-v", "\(volumeID):/data"], autoRemove: false)
            try f.waitForContainerRunning(c2)
            let output = try f.doExec(c2, cmd: ["cat", "/data/test.txt"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(output == "persistent-data")
            try f.doStop(c2)
            try? f.doRemoveIfExists(c2, force: true, ignoreFailure: true)
            f.doVolumeDeleteIfExists(volumeID)
        }
    }

    @Test func testMultipleAnonymousVolumes() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup {
                try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
                f.doCleanupAnonymousVolumes()
            }

            let beforeCount = try f.getAnonymousVolumeNames().count
            let result = try f.run([
                "run", "--rm", "--name", c,
                "-v", "/data1", "-v", "/data2", "-v", "/data3",
                image, "sh", "-c", "ls -d /data*",
            ])
            #expect(result.status == 0)
            try await Task.sleep(for: .seconds(1))

            let afterCount = try f.getAnonymousVolumeNames().count
            #expect(afterCount == beforeCount + 3, "all 3 anonymous volumes should persist")
        }
    }

    @Test func testAnonymousMountSyntax() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup {
                try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
                f.doCleanupAnonymousVolumes()
            }

            let beforeCount = try f.getAnonymousVolumeNames().count
            let result = try f.run([
                "run", "--rm", "--name", c,
                "--mount", "type=volume,dst=/mydata", image, "ls", "-la", "/mydata",
            ])
            #expect(result.status == 0)
            try await Task.sleep(for: .seconds(1))

            let afterCount = try f.getAnonymousVolumeNames().count
            #expect(afterCount == beforeCount + 1, "anonymous volume should persist")
        }
    }

    @Test func testAnonymousVolumeUUIDFormat() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup {
                try? f.doStop(c)
                try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
                f.doCleanupAnonymousVolumes()
            }

            try f.doLongRun(name: c, image: image, args: ["-v", "/data"], autoRemove: false)
            try f.waitForContainerRunning(c)

            let volumeNames = try f.getAnonymousVolumeNames()
            #expect(volumeNames.count == 1, "should have exactly one anonymous volume")
            let volumeName = volumeNames[0]
            #expect(volumeName.count == 36, "volume name should be 36 characters (UUID format)")
        }
    }

    @Test func testAnonymousVolumeMetadata() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup {
                try? f.doStop(c)
                try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
                f.doCleanupAnonymousVolumes()
            }

            try f.doLongRun(name: c, image: image, args: ["-v", "/data"], autoRemove: false)
            try f.waitForContainerRunning(c)

            let volumeNames = try f.getAnonymousVolumeNames()
            #expect(volumeNames.count == 1)
            let volumeName = volumeNames[0]

            let result = try f.run(["volume", "list", "--format", "json"]).check()
            #expect(result.output.contains("\"creationDate\""))
            #expect(!result.output.contains("\"createdAt\""))

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let volumes = try decoder.decode([VolumeResource].self, from: result.outputData)
            let anonVolume = volumes.first { $0.name == volumeName }
            #expect(anonVolume != nil, "should find anonymous volume in list")
            if let vol = anonVolume {
                #expect(vol.isAnonymous == true)
            }
        }
    }

    @Test func testAnonymousVolumeListDisplay() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let namedVol = "\(f.testID)-namedvol"
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup {
                try? f.doStop(c)
                try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
                f.doVolumeDeleteIfExists(namedVol)
                f.doCleanupAnonymousVolumes()
            }

            try f.doVolumeCreate(namedVol)
            try f.doLongRun(name: c, image: image, args: ["-v", "/data"], autoRemove: false)
            try f.waitForContainerRunning(c)

            let result = try f.run(["volume", "list"]).check()
            #expect(result.output.contains("TYPE"))
            #expect(result.output.contains("named"))
            #expect(result.output.contains("anonymous"))
            #expect(result.output.contains(namedVol))
        }
    }

    @Test func testAnonymousVolumeMixedWithNamedVolume() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let namedVol = "\(f.testID)-namedvol"
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup {
                try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
                f.doVolumeDeleteIfExists(namedVol)
                f.doCleanupAnonymousVolumes()
            }

            try f.doVolumeCreate(namedVol)
            let beforeAnonCount = try f.getAnonymousVolumeNames().count

            let result = try f.run([
                "run", "--rm", "--name", c,
                "-v", "\(namedVol):/named", "-v", "/anon",
                image, "sh", "-c", "ls -d /*",
            ])
            #expect(result.status == 0)
            try await Task.sleep(for: .seconds(1))

            #expect(try f.volumeExists(namedVol), "named volume should persist")
            let afterAnonCount = try f.getAnonymousVolumeNames().count
            #expect(afterAnonCount == beforeAnonCount + 1, "anonymous volume should persist")
        }
    }

    @Test func testAnonymousVolumeManualDeletion() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup { try? f.doRemoveIfExists(c, force: true, ignoreFailure: true) }

            try f.doLongRun(name: c, image: image, args: ["-v", "/data"], autoRemove: false)
            try f.waitForContainerRunning(c)

            let volumeNames = try f.getAnonymousVolumeNames()
            #expect(volumeNames.count == 1)
            let volumeID = volumeNames[0]

            try f.doStop(c)
            try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)

            let result = try f.run(["volume", "rm", volumeID])
            #expect(result.status == 0, "manual deletion of unmounted anonymous volume should succeed")
            #expect(!(try f.volumeExists(volumeID)))
        }
    }

    @Test func testAnonymousVolumeDetachedMode() async throws {
        try await ContainerFixture.with { f in
            f.doCleanupAnonymousVolumes()
            let c = "\(f.testID)-c1"
            try f.doPull(alpine)
            let image = try f.copyWarmupImage(alpine)
            f.addCleanup {
                try? f.doRemoveIfExists(c, force: true, ignoreFailure: true)
                f.doCleanupAnonymousVolumes()
            }

            let beforeCount = try f.getAnonymousVolumeNames().count
            let result = try f.run([
                "run", "-d", "--rm", "--name", c,
                "-v", "/data", image, "sleep", "2",
            ])
            #expect(result.status == 0)
            try await Task.sleep(for: .seconds(3))

            let lsResult = try f.run(["ls", "-a"])
            #expect(
                !lsResult.output.components(separatedBy: .newlines).contains { $0.contains(c) },
                "container should be auto-removed")

            let afterCount = try f.getAnonymousVolumeNames().count
            #expect(afterCount == beforeCount + 1, "anonymous volume should persist")
        }
    }
}
