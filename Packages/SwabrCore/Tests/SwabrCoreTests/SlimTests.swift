import Foundation
import Testing
@testable import SwabrCore

/// A fat file with one x86_64 and one arm64 slice; the arm slice starts with a thin arm64 header (magic, CPU type, subtype).
func makeFatFile(_ path: String, arm64e: Bool = false) throws {
    func be32(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
    let intel = [UInt8](repeating: 0x11, count: 4096)
    let arm = [0xCF, 0xFA, 0xED, 0xFE, 0x0C, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00] + [UInt8](repeating: 0x22, count: 4084)
    var d = [0xCA, 0xFE, 0xBA, 0xBE] + be32(2)
    d += be32(0x0100_0007) + be32(3) + be32(4096) + be32(4096) + be32(12)
    d += be32(0x0100_000C) + be32(arm64e ? 2 : 0) + be32(8192) + be32(4096) + be32(14)
    d += [UInt8](repeating: 0, count: 4096 - d.count) + intel + arm
    try Data(d).write(to: URL(fileURLWithPath: path))
}

@Test func fatHeaderIsParsedAndThinnedToArm() throws {
    let h = try FakeHome()
    let f = h.path + "/tool"
    try makeFatFile(f)
    let all = try #require(AppSlimmer.slices(f))
    let arm = try #require(AppSlimmer.armSlice(all))
    #expect(arm.offset == 8192 && arm.size == 4096)
    #expect(AppSlimmer.removableIntelBytes(f) == 4096)
    // Without lipo the arm64 slice is cut out as a thin file.
    #expect(AppSlimmer.removeIntel(f, lipo: nil))
    #expect(AppSlimmer.slices(f) == nil && AppSlimmer.hasArm64(f))
    #expect((try FileManager.default.attributesOfItem(atPath: f)[.size] as? Int) == 4096)
}

@Test func arm64eFilesAreLeftAlone() throws {
    let h = try FakeHome()
    let f = h.path + "/tool"
    try makeFatFile(f, arm64e: true)
    #expect(AppSlimmer.removableIntelBytes(f) == nil)
}

@Test func codeResourcesDistinguishNestedCodeFromPlainFiles() throws {
    let h = try FakeHome()
    let root = h.path + "/A.app/Contents"
    try FileManager.default.createDirectory(atPath: root + "/_CodeSignature", withIntermediateDirectories: true)
    let seal: [String: Any] = ["files2": [
        "Frameworks/X.framework": ["cdhash": Data([1, 2]), "requirement": "r"],
        "Helpers/tool": ["hash2": Data([3])],
    ]]
    try PropertyListSerialization.data(fromPropertyList: seal, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: root + "/_CodeSignature/CodeResources"))
    var cache: [String: [String: Any]] = [:]
    let bundle = h.path + "/A.app"
    #expect(!AppSlimmer.sealedByHash(root + "/Frameworks/X.framework", bundle: bundle, cache: &cache))
    #expect(AppSlimmer.sealedByHash(root + "/Helpers/tool", bundle: bundle, cache: &cache))
    #expect(!AppSlimmer.sealedByHash(root + "/MacOS/A", bundle: bundle, cache: &cache))
}
