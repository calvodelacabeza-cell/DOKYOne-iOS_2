import Foundation

struct DokyManifest: Decodable {
    let format: String
    let schema_version: Int
    let program_id: String
    let revision: Int
    let program_sha256: String
    let song_count: Int
}

struct HymnBlock: Decodable, Identifiable {
    let label: String
    let text: String
    var id: String { label + ":" + text }
}

struct Hymn: Decodable, Identifiable {
    let source_id: Int?
    let type: String
    let number: String?
    let title: String
    let blocks: [HymnBlock]
    var id: String { "\(source_id ?? -1)-\(title)" }
    var kindLabel: String { type.lowercased() == "himno" ? "Himno \(number ?? "")" : "Coro" }
}

struct ServiceProgram: Decodable, Identifiable {
    let format: String
    let schema_version: Int
    let program_id: String
    let revision: Int
    let name: String
    let date: String
    let leader: String
    let church: String?
    let songs: [Hymn]
    var id: String { program_id }
}

struct VerifiedPackage {
    let manifest: DokyManifest
    let program: ServiceProgram
    let bytes: Data
}
