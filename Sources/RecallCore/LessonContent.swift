import CryptoKit
import Foundation

public struct LessonBlock: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case text, equation, diagram }
    public var id: String
    public var kind: Kind
    public var text: String?
    public var assetID: String?
    public var caption: String?
    public var display: Bool?
    public init(
        id: String, kind: Kind, text: String? = nil, assetID: String? = nil, caption: String? = nil,
        display: Bool? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.assetID = assetID
        self.caption = caption
        self.display = display
    }
}

public struct DerivationStep: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var blocks: [LessonBlock]
    public init(id: String, title: String, blocks: [LessonBlock]) {
        self.id = id
        self.title = title
        self.blocks = blocks
    }
}

public struct LessonSection: Codable, Equatable, Identifiable, Sendable {
    public enum Role: String, Codable, Sendable {
        case intuition, derivation, example, pitfall, history, explanation
    }
    public var id: String
    public var role: Role
    public var title: String
    public var blocks: [LessonBlock]
    public var steps: [DerivationStep]?
    public var sourceURLs: [String]?
    public init(
        id: String, role: Role, title: String, blocks: [LessonBlock], steps: [DerivationStep]? = nil,
        sourceURLs: [String]? = nil
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.blocks = blocks
        self.steps = steps
        self.sourceURLs = sourceURLs
    }
}

/// Small, precompiled vector figures travel inside JSON. The phone never executes TeX.
public struct DiagramAsset: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var mediaType: String
    public var data: Data
    public var altText: String
    public var darkData: Data?
    public var digest: String {
        guard let darkData else { return ContentDigest.of(data) }
        var bytes = Data("recur-pdf-pair-v1\0".utf8)
        var length = UInt64(data.count).bigEndian
        withUnsafeBytes(of: &length) { bytes.append(contentsOf: $0) }
        bytes.append(data)
        bytes.append(darkData)
        return ContentDigest.of(bytes)
    }
    public init(
        id: String, mediaType: String = "application/pdf", data: Data, altText: String, darkData: Data? = nil
    ) {
        self.id = id
        self.mediaType = mediaType
        self.data = data
        self.altText = altText
        self.darkData = darkData
    }
    public func validate() throws {
        let validDarkData =
            darkData.map {
                $0.count <= 2_000_000 && $0.starts(with: Data("%PDF-".utf8))
            } ?? true
        guard mediaType == "application/pdf", data.count <= 2_000_000,
            data.starts(with: Data("%PDF-".utf8)), id == "sha256:" + digest,
            !altText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            validDarkData
        else {
            throw RecallError.invalid(
                "A diagram needs a valid PDF, a matching content ID, and a text description.")
        }
    }
}

public enum ContentDigest {
    public static func of(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public enum CardChange: String, Codable, Sendable { case wording, explanation, correction }

public struct SchedulerSettings: Codable, Equatable, Sendable {
    public var algorithm: String
    public var implementation: String
    public var retention: Double
    public var weights: [Double]
    public var learningSteps: [String]
    public var relearningSteps: [String]
    public var maximumInterval: Double = 36500
    public var enableFuzz: Bool = false
    public var enableShortTerm: Bool = true
}

public struct ReviewContent: Codable, Equatable, Sendable {
    public var card: Flashcard
    public var concept: Concept
    public var scheduler: SchedulerSettings
    public var digest: String { get throws { ContentDigest.of(try Codec.encode(self)) } }
}
