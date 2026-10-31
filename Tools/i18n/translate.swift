// Translates German UI strings and help pages with the on-device Translation framework of macOS.
// Format specifiers (%@, %lld, %%) and `code` spans are protected so they survive translation.
//
//   swiftc -parse-as-library Tools/i18n/translate.swift -o /tmp/translate
//   /tmp/translate strings <en.json> <out.json> fr es …   en.json: {"<de key>": "<English>"} → {"fr": {"<de key>": "…"}}
//   /tmp/translate help <Help/en> <Help> fr es …          → Help/<lang>/<topic>.md (translated from English)
import Foundation
import Translation

let specifier = try! NSRegularExpression(pattern: #"%(\d+\$)?(lld|ld|d|@|lf|f|%)|`[^`]*`|\*\*|https?://\S+"#)

/// Replaces placeholders with numbered tokens ([0], [1], …) the translator leaves alone.
func protect(_ s: String) -> (String, [String]) {
    var parts: [String] = []
    var out = ""
    var last = s.startIndex
    for m in specifier.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
        let r = Range(m.range, in: s)!
        out += s[last..<r.lowerBound] + "[\(parts.count)]"
        parts.append(String(s[r]))
        last = r.upperBound
    }
    out += s[last...]
    return (out, parts)
}

func restore(_ s: String, _ parts: [String]) -> String? {
    var out = s
    for (i, p) in parts.enumerated() {
        guard let r = out.range(of: "[\(i)]") else { return nil }
        out.replaceSubrange(r, with: p)
    }
    return out
}

/// Source language of the texts; English by default (the reviewed English strings translate more reliably).
nonisolated(unsafe) var sourceLanguage = "en"

func translate(_ texts: [String], to lang: String) async throws -> [String] {
    let session = TranslationSession(installedSource: Locale.Language(identifier: sourceLanguage), target: Locale.Language(identifier: lang))
    var out: [String] = []
    out.reserveCapacity(texts.count)
    let prepared = texts.map(protect)
    let requests = prepared.enumerated().map { TranslationSession.Request(sourceText: $0.element.0, clientIdentifier: "\($0.offset)") }
    var byID: [Int: String] = [:]
    for try await r in session.translate(batch: requests) {
        if let id = Int(r.clientIdentifier ?? "") { byID[id] = r.targetText }
    }
    for (i, (_, parts)) in prepared.enumerated() {
        let t = byID[i] ?? texts[i]
        // If a placeholder got lost, keep the source text rather than shipping a broken format string.
        out.append(restore(t, parts) ?? texts[i])
    }
    return out
}

@main
struct Translate {
    static func main() async throws {
        let args = CommandLine.arguments
        let mode = args[1]
        let langs = Array(args[4...])
        if mode == "strings" {
            // Input: {"<German key>": "<English text>"}; output keeps the German keys.
            let map = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
            let keys = map.keys.sorted()
            let texts = keys.map { map[$0]! }
            var result: [String: [String: String]] = [:]
            for lang in langs {
                let t = try await translate(texts, to: lang)
                result[lang] = Dictionary(uniqueKeysWithValues: zip(keys, t))
                let partial = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                try partial.write(to: URL(fileURLWithPath: args[3]))
                FileHandle.standardError.write("\(lang): \(t.count)\n".data(using: .utf8)!)
            }
            let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: args[3]))
        } else {
            let src = URL(fileURLWithPath: args[2])
            let files = try FileManager.default.contentsOfDirectory(atPath: src.path).filter { $0.hasSuffix(".md") }.sorted()
            for lang in langs {
                let dir = URL(fileURLWithPath: args[3]).appending(path: lang)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                for file in files {
                    let text = try String(contentsOf: src.appending(path: file), encoding: .utf8)
                    try await translateMarkdown(text, to: lang).write(to: dir.appending(path: file), atomically: true, encoding: .utf8)
                }
                FileHandle.standardError.write("help \(lang): \(files.count)\n".data(using: .utf8)!)
            }
        }
    }

    /// Keeps Markdown structure: prefixes (#, -, >) and table pipes stay, only the text between is translated.
    static func translateMarkdown(_ text: String, to lang: String) async throws -> String {
        var segments: [String] = []
        var layout: [(prefix: String, cells: [Int]?, index: Int?)] = []
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { layout.append(("", nil, nil)); continue }
            if t.hasPrefix("|") {
                let cells = t.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if cells.allSatisfy({ $0.allSatisfy { "-: ".contains($0) } }) { layout.append((t, nil, nil)); continue }
                var idx: [Int] = []
                for c in cells { idx.append(segments.count); segments.append(c) }
                layout.append(("|", idx, nil))
                continue
            }
            var prefix = ""
            var body = t
            for p in ["### ", "## ", "# ", "- ", "> "] where t.hasPrefix(p) { prefix = p; body = String(t.dropFirst(p.count)); break }
            layout.append((prefix, nil, segments.count))
            segments.append(body)
        }
        let translated = try await translate(segments, to: lang)
        return layout.map { entry -> String in
            if let cells = entry.cells { return "| " + cells.map { translated[$0] }.joined(separator: " | ") + " |" }
            if let i = entry.index { return entry.prefix + translated[i] }
            return entry.prefix
        }.joined(separator: "\n")
    }
}
