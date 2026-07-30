import Foundation
import Testing
@testable import Gin

/// Validates the shipped content files themselves.
///
/// These read the real JSON off disk rather than a fixture, on purpose: the
/// failure this is guarding against is a typo in a pack file, and a fixture
/// would happily pass while the actual shipped content was broken.
struct ContentPackTests {

    /// Resolves the Resources/Packs directory relative to this source file, so
    /// the test needs no bundle plumbing or test host.
    private static func packURL(_ id: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // GinTests
            .deletingLastPathComponent()   // Gin (repo root)
            .appendingPathComponent("Gin/Resources/Packs/\(id).json")
    }

    private func loadPack(_ id: String) throws -> Pack {
        let data = try Data(contentsOf: Self.packURL(id))
        return try JSONDecoder().decode(Pack.self, from: data)
    }

    @Test("Every declared pack decodes")
    func allPacksDecode() throws {
        for id in ContentLoader.packIdentifiers {
            let pack = try loadPack(id)
            #expect(pack.id == id, "Pack file '\(id).json' declares id '\(pack.id)'")
        }
    }

    @Test("Item ids are unique within a pack")
    func itemIDsAreUnique() throws {
        for id in ContentLoader.packIdentifiers {
            let pack = try loadPack(id)
            let unique = Set(pack.items.map(\.id))
            #expect(unique.count == pack.items.count,
                    "Pack '\(id)' has duplicate item ids")
        }
    }

    @Test("Every item has a name and a voice clip")
    func itemsAreSpeakable() throws {
        // The app is audio-first: an item with no voice clip is an item a child
        // can never be told the name of.
        for id in ContentLoader.packIdentifiers {
            let pack = try loadPack(id)
            for item in pack.items {
                #expect(!item.name.isEmpty, "\(id)/\(item.id) has an empty name")
                #expect(!item.voiceClip.isEmpty, "\(id)/\(item.id) has no voiceClip")
            }
        }
    }

    @Test("A pack holds enough items for its hardest level")
    func packsHaveEnoughItems() throws {
        // A level asks for a pool; a pack that can't fill it silently shows the
        // child a smaller set than intended.
        for id in ContentLoader.packIdentifiers {
            let pack = try loadPack(id)
            let params = LevelParams.params(for: pack.minLevel)
            #expect(pack.items.count >= params.choiceCount,
                    "Pack '\(id)' has fewer items than its level offers choices")
        }
    }

    @Test("Level gating behaves")
    func levelGating() throws {
        let animals = try loadPack("animals")
        #expect(animals.isAvailable(at: .little))
        #expect(animals.isAvailable(at: .big))

        // A Big-level pack must not leak down to a two-year-old.
        var mathLike = animals
        mathLike.minLevel = .big
        #expect(!mathLike.isAvailable(at: .little))
        #expect(mathLike.isAvailable(at: .big))
    }

    @Test("Little level offers three choices, older levels four")
    func choiceCountsByLevel() {
        #expect(LevelParams.params(for: .little).choiceCount == 3)
        #expect(LevelParams.params(for: .middle).choiceCount == 4)
        #expect(LevelParams.params(for: .big).choiceCount == 4)
    }

    @Test("The item pool grows with level")
    func poolGrowsWithLevel() {
        let little = LevelParams.params(for: .little).itemPoolSize
        let middle = LevelParams.params(for: .middle).itemPoolSize
        let big    = LevelParams.params(for: .big).itemPoolSize
        #expect(little < middle)
        #expect(middle < big)
    }
}
