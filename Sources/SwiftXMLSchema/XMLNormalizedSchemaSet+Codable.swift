import Foundation
import SwiftXMLCoder

// MARK: - XMLNormalizedContentNode: custom Codable
//
// The enum has associated values, so synthesised Codable cannot be used.
// Encoded as a discriminated union:
//
//   { "kind": "element", "value": { ...XMLNormalizedElementUse fields... } }
//   { "kind": "choice",  "value": { ...XMLNormalizedChoiceGroup fields...  } }
//   { "kind": "wildcard","value": { ...XMLSchemaWildcard fields...          } }
//
// The "kind" + "value" envelope is unambiguous across all consumer languages
// (TypeScript, Kotlin, Go, Rust, Python) without relying on language-specific
// sum-type conventions.

extension XMLNormalizedContentNode {
    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    private enum Kind: String, Codable {
        case element
        case choice
        case wildcard
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .element(let element):
            try container.encode(Kind.element, forKey: .kind)
            try container.encode(element, forKey: .value)
        case .choice(let choice):
            try container.encode(Kind.choice, forKey: .kind)
            try container.encode(choice, forKey: .value)
        case .wildcard(let wildcard):
            try container.encode(Kind.wildcard, forKey: .kind)
            try container.encode(wildcard, forKey: .value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .element:
            self = .element(try container.decode(XMLNormalizedElementUse.self, forKey: .value))
        case .choice:
            self = .choice(try container.decode(XMLNormalizedChoiceGroup.self, forKey: .value))
        case .wildcard:
            self = .wildcard(try container.decode(XMLSchemaWildcard.self, forKey: .value))
        }
    }
}

// MARK: - XMLNormalizedSchemaSet: custom Codable
//
// The stored O(1) indices are derived from `schemas` and must NOT be serialised
// — they are rebuilt by `init(schemas:)` on decode.
//
// Wire format:
//   {
//     "schemaVersion": 1,
//     "schemas": [ ...XMLNormalizedSchema... ]
//   }
//
// `schemaVersion` is incremented on incompatible format changes.

extension XMLNormalizedSchemaSet {
    public static let currentSchemaVersion = 1

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case schemas
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(schemas, forKey: .schemas)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try? container.decode(Int.self, forKey: .schemaVersion)
        let schemas = try container.decode([XMLNormalizedSchema].self, forKey: .schemas)
        self.init(schemas: schemas)
    }
}

// MARK: - Fingerprinting

#if canImport(CryptoKit)
import CryptoKit

extension XMLNormalizedSchemaSet {
    /// A stable SHA-256 fingerprint of the normalised schema set.
    ///
    /// Computed over the canonical JSON encoding with keys sorted
    /// deterministically. Use it to detect schema changes and invalidate
    /// downstream caches (generated code, schema-model.json artifacts).
    ///
    /// Available on Apple platforms (macOS 10.15+, iOS 13+) where `CryptoKit`
    /// is shipped as a system framework.
    public var fingerprint: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
#endif
