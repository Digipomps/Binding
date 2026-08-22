// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  HavenContactDocumentKit.swift
//  Binding
//
//  Reads the files people actually have: CSV/TSV exports (Norwegian Excel
//  semicolons and Latin-1 included), vCard, and XLSX. Then works out which
//  columns hold names, phones and addresses, using both the header text and
//  the shape of the values, so a header-less or oddly-labelled file still
//  lands correctly.
//
//  Platform-neutral except for the XLSX inflate, which is guarded behind
//  `canImport(Compression)` and fails with a precise message elsewhere.
//

import Foundation
#if canImport(Compression)
import Compression
#endif

// MARK: - Format detection

nonisolated public enum HavenContactDocumentFormat: String, Codable, Sendable {
    case csv
    case tsv
    case vcard
    case xlsx
    case numbers
    case json
    case unknown

    public var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .tsv: return "TSV"
        case .vcard: return "vCard"
        case .xlsx: return "Excel (.xlsx)"
        case .numbers: return "Numbers (.numbers)"
        case .json: return "JSON"
        case .unknown: return "ukjent format"
        }
    }
}

nonisolated public enum HavenContactDocumentDetector {

    /// Sniffs bytes first and the filename second. Bytes win because people
    /// rename files and mail clients invent MIME types.
    public static func detect(filename: String?, mimeType: String?, data: Data) -> HavenContactDocumentFormat {
        if data.count >= 4 {
            let magic = [UInt8](data.prefix(4))
            // Both .xlsx and .numbers are ZIP containers; the entry names decide.
            if magic[0] == 0x50, magic[1] == 0x4B, magic[2] == 0x03, magic[3] == 0x04 {
                let names = (try? HavenZipArchive(data: data).entryNames) ?? []
                if names.contains(where: { $0.hasPrefix("xl/") }) { return .xlsx }
                if names.contains(where: { $0.hasPrefix("Index/") || $0.hasPrefix("Metadata/") }) { return .numbers }
                return .unknown
            }
        }

        if let text = decodeText(data)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            let upper = text.prefix(256).uppercased()
            if upper.contains("BEGIN:VCARD") { return .vcard }
            if text.hasPrefix("[") || text.hasPrefix("{") { return .json }
        }

        let ext = (filename as NSString?)?.pathExtension.lowercased() ?? ""
        switch ext {
        case "csv": return .csv
        case "tsv", "tab": return .tsv
        case "vcf", "vcard": return .vcard
        case "xlsx", "xlsm": return .xlsx
        case "numbers": return .numbers
        case "json": return .json
        case "txt": return .csv
        default: break
        }

        if let mime = mimeType?.lowercased() {
            if mime.contains("csv") { return .csv }
            if mime.contains("tab-separated") { return .tsv }
            if mime.contains("vcard") { return .vcard }
            if mime.contains("spreadsheetml") { return .xlsx }
            if mime.contains("json") { return .json }
        }

        // Last resort: if it decodes as text and has a consistent delimiter,
        // treat it as delimited rather than refusing outright.
        if let text = decodeText(data), HavenDelimitedTableParser.sniffDelimiter(in: text) != nil {
            return .csv
        }
        return .unknown
    }

    /// Tries the encodings Norwegian contact exports actually use, in order of
    /// likelihood, and reports which one won so the UI can say so.
    public static func decodeText(_ data: Data) -> String? {
        decodeTextWithEncoding(data)?.text
    }

    public static func decodeTextWithEncoding(_ data: Data) -> (text: String, encodingName: String)? {
        var payload = data
        // Strip byte order marks so they never end up inside the first header.
        if payload.starts(with: [0xEF, 0xBB, 0xBF]) {
            payload = payload.dropFirst(3)
        } else if payload.starts(with: [0xFF, 0xFE]) || payload.starts(with: [0xFE, 0xFF]) {
            if let text = String(data: payload, encoding: .utf16) {
                return (text, "UTF-16")
            }
        }
        if let text = String(data: payload, encoding: .utf8) {
            return (text, "UTF-8")
        }
        if let text = String(data: payload, encoding: .utf16) {
            return (text, "UTF-16")
        }
        if let text = String(data: payload, encoding: .isoLatin1) {
            return (text, "ISO-8859-1")
        }
        if let text = String(data: payload, encoding: .windowsCP1252) {
            return (text, "Windows-1252")
        }
        if let text = String(data: payload, encoding: .macOSRoman) {
            return (text, "Mac OS Roman")
        }
        return nil
    }
}

// MARK: - Tabular document

nonisolated public struct HavenTabularDocument: Equatable, Sendable {
    public var headers: [String]
    public var rows: [[String]]
    public var sheetName: String?
    /// True when we concluded the first line was data, not a header row, and
    /// synthesised column names instead.
    public var headersWereSynthesised: Bool
    public var notes: [String]

    public init(
        headers: [String],
        rows: [[String]],
        sheetName: String? = nil,
        headersWereSynthesised: Bool = false,
        notes: [String] = []
    ) {
        self.headers = headers
        self.rows = rows
        self.sheetName = sheetName
        self.headersWereSynthesised = headersWereSynthesised
        self.notes = notes
    }

    public func column(_ index: Int, in row: [String]) -> String {
        guard index >= 0, index < row.count else { return "" }
        return row[index]
    }
}

nonisolated public enum HavenContactDocumentError: Error, CustomStringConvertible {
    case unreadableText
    case unsupportedFormat(HavenContactDocumentFormat)
    case numbersPackage
    case emptyDocument
    case zip(String)
    case compressionUnavailable

    public var description: String {
        switch self {
        case .unreadableText:
            return "Filen kunne ikke leses som tekst i noen av tegnsettene jeg prøvde (UTF-8, UTF-16, ISO-8859-1, Windows-1252)."
        case .unsupportedFormat(let format):
            return "Jeg kan ikke lese \(format.displayName) ennå."
        case .numbersPackage:
            return "Dette er en Numbers-pakke. Numbers lagrer i et lukket format (IWA) som jeg ikke kan lese direkte. Åpne filen i Numbers og velg Arkiv → Eksporter til → CSV eller Excel, så leser jeg den med én gang."
        case .emptyDocument:
            return "Filen inneholder ingen rader jeg kan bruke."
        case .zip(let detail):
            return "Zip-arkivet kunne ikke leses: \(detail)"
        case .compressionUnavailable:
            return "Denne plattformen mangler Compression-rammeverket, så .xlsx kan ikke pakkes ut her. Eksporter til CSV i stedet."
        }
    }
}

// MARK: - Delimited tables

nonisolated public enum HavenDelimitedTableParser {

    /// Counts candidate delimiters outside quoted sections across the first
    /// lines and picks the one with the most consistent per-line count.
    /// Consistency matters more than raw frequency: a notes column full of
    /// commas would otherwise beat the real semicolon separator.
    public static func sniffDelimiter(in text: String) -> Character? {
        let candidates: [Character] = [";", ",", "\t", "|"]
        let sample = Array(splitLines(text).prefix(20)).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !sample.isEmpty else { return nil }

        var best: (delimiter: Character, score: Double)?
        for delimiter in candidates {
            let counts = sample.map { countOutsideQuotes($0, delimiter: delimiter) }
            guard let first = counts.first, first > 0 else { continue }
            let consistent = counts.filter { $0 == first }.count
            let consistency = Double(consistent) / Double(counts.count)
            guard consistency >= 0.6 else { continue }
            let score = consistency * 10.0 + Double(first)
            if best == nil || score > best!.score {
                best = (delimiter, score)
            }
        }
        return best?.delimiter
    }

    private static func countOutsideQuotes(_ line: String, delimiter: Character) -> Int {
        var inQuotes = false
        var count = 0
        for character in line {
            if character == "\"" { inQuotes.toggle() }
            else if character == delimiter, !inQuotes { count += 1 }
        }
        return count
    }

    private static func splitLines(_ text: String) -> [String] {
        text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" })
            .map(String.init)
    }

    /// RFC 4180 with the usual real-world tolerances: any of the four common
    /// delimiters, embedded newlines inside quotes, doubled quotes, and ragged
    /// rows padded rather than dropped.
    public static func parse(text: String, delimiter: Character? = nil) throws -> HavenTabularDocument {
        let separator = delimiter ?? sniffDelimiter(in: text) ?? ","
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        var iterator = text.startIndex

        while iterator < text.endIndex {
            let character = text[iterator]
            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: iterator)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        iterator = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                case separator:
                    row.append(field)
                    field = ""
                case "\r":
                    // Swallow; the \n that follows ends the row.
                    break
                case "\n":
                    row.append(field)
                    field = ""
                    rows.append(row)
                    row = []
                default:
                    field.append(character)
                }
            }
            iterator = text.index(after: iterator)
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        rows = rows.filter { candidate in
            candidate.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        guard !rows.isEmpty else { throw HavenContactDocumentError.emptyDocument }

        let width = rows.map(\.count).max() ?? 0
        let padded = rows.map { candidate -> [String] in
            var values = candidate.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            while values.count < width { values.append("") }
            return values
        }

        return finish(rows: padded, sheetName: nil, notes: ["Skilletegn: \(describe(separator))"])
    }

    private static func describe(_ delimiter: Character) -> String {
        switch delimiter {
        case "\t": return "tabulator"
        case ";": return "semikolon"
        case ",": return "komma"
        case "|": return "loddrett strek"
        default: return String(delimiter)
        }
    }

    /// Decides whether row 0 is a header, and synthesises names when it is not.
    public static func finish(rows: [[String]], sheetName: String?, notes: [String]) -> HavenTabularDocument {
        guard let first = rows.first else {
            return HavenTabularDocument(headers: [], rows: [], sheetName: sheetName, notes: notes)
        }
        var notes = notes
        let looksLikeHeader = isHeaderRow(first)
        if looksLikeHeader {
            let headers = first.enumerated().map { index, value -> String in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "Kolonne \(index + 1)" : trimmed
            }
            return HavenTabularDocument(
                headers: headers,
                rows: Array(rows.dropFirst()),
                sheetName: sheetName,
                headersWereSynthesised: false,
                notes: notes
            )
        }
        notes.append("Første rad så ut som data, ikke overskrifter — jeg leser alle radene som innhold.")
        let headers = (0..<first.count).map { "Kolonne \($0 + 1)" }
        return HavenTabularDocument(
            headers: headers,
            rows: rows,
            sheetName: sheetName,
            headersWereSynthesised: true,
            notes: notes
        )
    }

    /// A header row is short text with no reachable identifiers in it. The
    /// moment a cell parses as an email or a phone number, it is data.
    public static func isHeaderRow(_ row: [String]) -> Bool {
        let filled = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !filled.isEmpty else { return false }
        for value in filled {
            if HavenRelationNormalizer.looksLikeEmail(value) { return false }
            if HavenRelationNormalizer.looksLikePhone(value) { return false }
            if value.count > 64 { return false }
        }
        // Headers are rarely pure numbers.
        let numeric = filled.filter { Double($0.replacingOccurrences(of: ",", with: ".")) != nil }
        if Double(numeric.count) / Double(filled.count) > 0.5 { return false }
        return true
    }
}

// MARK: - vCard

nonisolated public enum HavenVCardParser {

    public struct Card: Equatable, Sendable {
        public var fullName: String?
        public var givenName: String?
        public var familyName: String?
        public var organization: String?
        public var jobTitle: String?
        public var notes: String?
        public var categories: [String] = []
        /// (value, kind hint, label)
        public var endpoints: [(value: String, kind: HavenEndpointKind, label: String?)] = []

        public init(
            fullName: String? = nil,
            givenName: String? = nil,
            familyName: String? = nil,
            organization: String? = nil,
            jobTitle: String? = nil,
            notes: String? = nil,
            categories: [String] = [],
            endpoints: [(value: String, kind: HavenEndpointKind, label: String?)] = []
        ) {
            self.fullName = fullName
            self.givenName = givenName
            self.familyName = familyName
            self.organization = organization
            self.jobTitle = jobTitle
            self.notes = notes
            self.categories = categories
            self.endpoints = endpoints
        }

        public static func == (lhs: Card, rhs: Card) -> Bool {
            lhs.fullName == rhs.fullName
                && lhs.givenName == rhs.givenName
                && lhs.familyName == rhs.familyName
                && lhs.organization == rhs.organization
                && lhs.jobTitle == rhs.jobTitle
                && lhs.notes == rhs.notes
                && lhs.categories == rhs.categories
                && lhs.endpoints.map { "\($0.value)|\($0.kind.rawValue)|\($0.label ?? "")" }
                    == rhs.endpoints.map { "\($0.value)|\($0.kind.rawValue)|\($0.label ?? "")" }
        }
    }

    public static func parse(text: String) -> [Card] {
        var cards: [Card] = []
        var current: Card?

        for line in unfold(text) {
            let upper = line.uppercased()
            if upper.hasPrefix("BEGIN:VCARD") {
                current = Card(categories: [], endpoints: [])
                continue
            }
            if upper.hasPrefix("END:VCARD") {
                if let card = current, isMeaningful(card) { cards.append(card) }
                current = nil
                continue
            }
            guard current != nil else { continue }
            guard let (name, parameters, rawValue) = splitLine(line) else { continue }
            let value = decodeValue(rawValue, parameters: parameters)
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            switch name {
            case "FN":
                current?.fullName = value
            case "N":
                // Family;Given;Additional;Prefix;Suffix
                let parts = splitStructured(value)
                current?.familyName = parts.count > 0 ? nilIfBlank(parts[0]) : nil
                current?.givenName = parts.count > 1 ? nilIfBlank(parts[1]) : nil
            case "ORG":
                current?.organization = nilIfBlank(splitStructured(value).first ?? value)
            case "TITLE", "ROLE":
                // Read first, then write. Doing both in one statement is an
                // overlapping access to `current`, which Swift rejects.
                let existingTitle: String? = current?.jobTitle ?? nil
                current?.jobTitle = existingTitle ?? nilIfBlank(value)
            case "NOTE":
                let existingNotes: String? = current?.notes ?? nil
                let mergedNotes = [existingNotes, nilIfBlank(value)]
                    .compactMap { $0 }
                    .joined(separator: "\n")
                current?.notes = mergedNotes
            case "CATEGORIES":
                current?.categories.append(contentsOf: value.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty })
            case "EMAIL":
                current?.endpoints.append((value, .email, typeLabel(parameters)))
            case "TEL":
                current?.endpoints.append((value, .phone, typeLabel(parameters)))
            case "URL":
                current?.endpoints.append((value, .url, typeLabel(parameters)))
            case "IMPP", "X-SOCIALPROFILE":
                current?.endpoints.append((value, .handle, typeLabel(parameters)))
            case "ADR":
                let readable = splitStructured(value).filter { !$0.isEmpty }.joined(separator: ", ")
                if !readable.isEmpty {
                    current?.endpoints.append((readable, .postal, typeLabel(parameters)))
                }
            default:
                break
            }
        }
        return cards
    }

    private static func isMeaningful(_ card: Card) -> Bool {
        if card.fullName?.isEmpty == false { return true }
        if card.givenName?.isEmpty == false || card.familyName?.isEmpty == false { return true }
        if card.organization?.isEmpty == false { return true }
        return !card.endpoints.isEmpty
    }

    private static func nilIfBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// RFC 6350 line folding: a line beginning with space or tab continues the
    /// previous one.
    private static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        for raw in text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) {
            let line = String(raw)
            if let first = line.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += String(line.dropFirst())
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append(line)
            }
        }
        // vCard 2.1 soft line breaks: a quoted-printable value continues on the
        // next physical line when the current one ends with "=". Only lines that
        // actually declared the encoding start such a chain, so an ordinary
        // value ending in "=" (a base64 tail, say) is left alone.
        var merged: [String] = []
        var continuing = false
        for line in lines {
            if continuing, let last = merged.last {
                // `last` still carries its soft-break "="; drop it as we join.
                merged[merged.count - 1] = String(last.dropLast()) + line
                continuing = line.hasSuffix("=")
                continue
            }
            merged.append(line)
            continuing = line.uppercased().contains("QUOTED-PRINTABLE") && line.hasSuffix("=")
        }
        return merged.map { line in
            guard line.hasSuffix("="), line.uppercased().contains("QUOTED-PRINTABLE") else { return line }
            return String(line.dropLast())
        }
    }

    private static func splitLine(_ line: String) -> (name: String, parameters: [String], value: String)? {
        guard let colon = firstColonOutsideQuotes(line) else { return nil }
        let left = String(line[line.startIndex..<colon])
        let value = String(line[line.index(after: colon)...])
        var components = left.split(separator: ";").map(String.init)
        guard var name = components.first else { return nil }
        components.removeFirst()
        // Strip a group prefix such as "item1.EMAIL".
        if let dot = name.lastIndex(of: ".") {
            name = String(name[name.index(after: dot)...])
        }
        return (name.uppercased(), components, value)
    }

    private static func firstColonOutsideQuotes(_ line: String) -> String.Index? {
        var inQuotes = false
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if character == "\"" { inQuotes.toggle() }
            else if character == ":", !inQuotes { return index }
            index = line.index(after: index)
        }
        return nil
    }

    private static func typeLabel(_ parameters: [String]) -> String? {
        for parameter in parameters {
            let upper = parameter.uppercased()
            if upper.hasPrefix("TYPE=") {
                let value = String(parameter.dropFirst("TYPE=".count))
                    .replacingOccurrences(of: "\"", with: "")
                let cleaned = value.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.uppercased().hasPrefix("PREF") && !$0.uppercased().hasPrefix("INTERNET") && !$0.uppercased().hasPrefix("VOICE") }
                if let first = cleaned.first, !first.isEmpty { return first.lowercased() }
            } else if !upper.contains("="), !upper.hasPrefix("PREF"), !upper.hasPrefix("CHARSET"), !upper.hasPrefix("ENCODING") {
                return parameter.lowercased()
            }
        }
        return nil
    }

    private static func splitStructured(_ value: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var escaped = false
        for character in value {
            if escaped {
                switch character {
                case "n", "N": current.append("\n")
                default: current.append(character)
                }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == ";" {
                parts.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current.trimmingCharacters(in: .whitespaces))
        return parts
    }

    private static func decodeValue(_ value: String, parameters: [String]) -> String {
        var result = value
        let joined = parameters.joined(separator: ";").uppercased()
        if joined.contains("QUOTED-PRINTABLE") {
            result = decodeQuotedPrintable(result, charset: charset(parameters))
        }
        return result
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func charset(_ parameters: [String]) -> String.Encoding {
        for parameter in parameters where parameter.uppercased().hasPrefix("CHARSET=") {
            let value = String(parameter.dropFirst("CHARSET=".count)).uppercased()
            if value.contains("8859-1") || value.contains("LATIN1") { return .isoLatin1 }
            if value.contains("1252") { return .windowsCP1252 }
        }
        return .utf8
    }

    private static func decodeQuotedPrintable(_ value: String, charset: String.Encoding) -> String {
        var bytes: [UInt8] = []
        var index = value.startIndex
        while index < value.endIndex {
            let character = value[index]
            if character == "=" {
                let next = value.index(index, offsetBy: 1, limitedBy: value.endIndex) ?? value.endIndex
                let end = value.index(index, offsetBy: 3, limitedBy: value.endIndex) ?? value.endIndex
                if next < value.endIndex, end <= value.endIndex, end > next {
                    let hex = String(value[next..<end])
                    if hex.count == 2, let byte = UInt8(hex, radix: 16) {
                        bytes.append(byte)
                        index = end
                        continue
                    }
                }
                index = value.index(after: index)
            } else {
                bytes.append(contentsOf: Array(String(character).utf8))
                index = value.index(after: index)
            }
        }
        return String(data: Data(bytes), encoding: charset)
            ?? String(data: Data(bytes), encoding: .utf8)
            ?? value
    }
}

// MARK: - ZIP

/// Minimal read-only ZIP reader built on the central directory. Enough for
/// .xlsx, and enough to tell a .numbers package apart from one.
nonisolated public struct HavenZipArchive {

    public struct Entry {
        public var name: String
        public var compressionMethod: UInt16
        public var compressedSize: Int
        public var uncompressedSize: Int
        public var localHeaderOffset: Int
    }

    public let entries: [Entry]
    private let data: Data

    public var entryNames: [String] { entries.map(\.name) }

    public init(data: Data) throws {
        // Rebase to a zero-based buffer: every offset below is absolute, and a
        // Data that arrived as a slice would otherwise index off the end.
        let normalized = data.startIndex == 0 ? data : Data(data)
        self.data = normalized
        self.entries = try Self.readCentralDirectory(normalized)
    }

    public func contents(of name: String) throws -> Data? {
        guard let entry = entries.first(where: { $0.name == name }) else { return nil }
        return try contents(of: entry)
    }

    public func contents(of entry: Entry) throws -> Data {
        let base = entry.localHeaderOffset
        guard base + 30 <= data.count else { throw HavenContactDocumentError.zip("lokal header utenfor filen") }
        guard Self.uint32(data, base) == 0x04034B50 else {
            throw HavenContactDocumentError.zip("ugyldig lokal header for \(entry.name)")
        }
        let nameLength = Int(Self.uint16(data, base + 26))
        let extraLength = Int(Self.uint16(data, base + 28))
        let start = base + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard start <= data.count, end <= data.count else {
            throw HavenContactDocumentError.zip("data utenfor filen for \(entry.name)")
        }
        let payload = data.subdata(in: start..<end)

        switch entry.compressionMethod {
        case 0:
            return payload
        case 8:
            guard let inflated = Self.inflate(payload) else {
                throw HavenContactDocumentError.zip("kunne ikke pakke ut \(entry.name)")
            }
            return inflated
        default:
            throw HavenContactDocumentError.zip("komprimeringsmetode \(entry.compressionMethod) støttes ikke")
        }
    }

    private static func readCentralDirectory(_ data: Data) throws -> [Entry] {
        guard data.count > 22 else { throw HavenContactDocumentError.zip("for kort til å være et arkiv") }
        // End of central directory record, possibly followed by a comment.
        let searchStart = max(0, data.count - 22 - 65_535)
        var eocd: Int?
        var index = data.count - 22
        while index >= searchStart {
            if uint32(data, index) == 0x06054B50 { eocd = index; break }
            index -= 1
        }
        guard let eocd else { throw HavenContactDocumentError.zip("fant ikke sluttposten") }

        let count = Int(uint16(data, eocd + 10))
        var offset = Int(uint32(data, eocd + 16))
        if offset == 0xFFFF_FFFF {
            throw HavenContactDocumentError.zip("ZIP64-arkiver støttes ikke")
        }

        var entries: [Entry] = []
        entries.reserveCapacity(count)
        for _ in 0..<count {
            guard offset + 46 <= data.count, uint32(data, offset) == 0x02014B50 else { break }
            let method = uint16(data, offset + 10)
            let compressedSize = Int(uint32(data, offset + 20))
            let uncompressedSize = Int(uint32(data, offset + 24))
            let nameLength = Int(uint16(data, offset + 28))
            let extraLength = Int(uint16(data, offset + 30))
            let commentLength = Int(uint16(data, offset + 32))
            let localOffset = Int(uint32(data, offset + 42))
            let nameStart = offset + 46
            guard nameStart + nameLength <= data.count else { break }
            let name = String(data: data.subdata(in: nameStart..<(nameStart + nameLength)), encoding: .utf8)
                ?? String(data: data.subdata(in: nameStart..<(nameStart + nameLength)), encoding: .isoLatin1)
                ?? ""
            entries.append(Entry(
                name: name,
                compressionMethod: method,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localOffset
            ))
            offset = nameStart + nameLength + extraLength + commentLength
        }
        guard !entries.isEmpty else { throw HavenContactDocumentError.zip("ingen oppføringer") }
        return entries
    }

    static func uint16(_ data: Data, _ offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    static func uint32(_ data: Data, _ offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    /// Raw DEFLATE, which is what ZIP stores. Apple's `COMPRESSION_ZLIB` is
    /// raw deflate despite the name.
    static func inflate(_ data: Data) -> Data? {
#if canImport(Compression)
        guard !data.isEmpty else { return Data() }
        let streamPointer = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPointer.deallocate() }
        guard compression_stream_init(streamPointer, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            return nil
        }
        defer { compression_stream_destroy(streamPointer) }

        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Data? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            streamPointer.pointee.src_ptr = base
            streamPointer.pointee.src_size = data.count

            var output = Data()
            while true {
                streamPointer.pointee.dst_ptr = buffer
                streamPointer.pointee.dst_size = bufferSize
                let status = compression_stream_process(streamPointer, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let produced = bufferSize - streamPointer.pointee.dst_size
                if produced > 0 { output.append(buffer, count: produced) }
                switch status {
                case COMPRESSION_STATUS_END:
                    return output
                case COMPRESSION_STATUS_OK:
                    if produced == 0 { return nil }
                default:
                    return nil
                }
            }
        }
#else
        return nil
#endif
    }
}

// MARK: - XLSX

nonisolated public enum HavenXLSXReader {

    /// Reads one worksheet into a table. Only values are read — formulas are
    /// taken at their cached result, and number formats are not applied, so a
    /// date column arrives as its serial number. Contact sheets rarely care;
    /// the note says so when it happens.
    public static func read(data: Data, sheetIndex: Int = 0) throws -> HavenTabularDocument {
#if !canImport(Compression)
        throw HavenContactDocumentError.compressionUnavailable
#else
        let archive = try HavenZipArchive(data: data)
        let sharedStrings = try readSharedStrings(archive)

        let sheetPaths = archive.entryNames
            .filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }
            .sorted { lhs, rhs in
                sheetOrdinal(lhs) < sheetOrdinal(rhs)
            }
        guard !sheetPaths.isEmpty else { throw HavenContactDocumentError.emptyDocument }
        let index = min(max(0, sheetIndex), sheetPaths.count - 1)
        guard let sheetData = try archive.contents(of: sheetPaths[index]) else {
            throw HavenContactDocumentError.emptyDocument
        }

        let names = (try? readSheetNames(archive)) ?? []
        let sheetName = index < names.count ? names[index] : sheetPaths[index]

        let parser = SheetParser(sharedStrings: sharedStrings)
        let grid = try parser.parse(sheetData)
        guard !grid.isEmpty else { throw HavenContactDocumentError.emptyDocument }

        let width = grid.map(\.count).max() ?? 0
        let rows = grid
            .map { row -> [String] in
                var values = row
                while values.count < width { values.append("") }
                return values
            }
            .filter { row in row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard !rows.isEmpty else { throw HavenContactDocumentError.emptyDocument }

        var notes = ["Ark: \(sheetName)"]
        if sheetPaths.count > 1 {
            notes.append("Filen har \(sheetPaths.count) ark. Jeg leste ark \(index + 1).")
        }
        return HavenDelimitedTableParser.finish(rows: rows, sheetName: sheetName, notes: notes)
#endif
    }

    private static func sheetOrdinal(_ path: String) -> Int {
        let digits = path.split(separator: "/").last?.filter(\.isNumber) ?? ""
        return Int(digits) ?? Int.max
    }

    private static func readSharedStrings(_ archive: HavenZipArchive) throws -> [String] {
        guard let data = try archive.contents(of: "xl/sharedStrings.xml") else { return [] }
        let parser = SharedStringsParser()
        return try parser.parse(data)
    }

    private static func readSheetNames(_ archive: HavenZipArchive) throws -> [String] {
        guard let data = try archive.contents(of: "xl/workbook.xml") else { return [] }
        let parser = WorkbookParser()
        return try parser.parse(data)
    }

    // MARK: XML parsing

    private final class SharedStringsParser: NSObject, XMLParserDelegate {
        private var strings: [String] = []
        private var current = ""
        private var insideSI = false
        private var insideT = false
        private var parseError: Error?

        func parse(_ data: Data) throws -> [String] {
            let parser = XMLParser(data: data)
            parser.delegate = self
            guard parser.parse() else {
                throw HavenContactDocumentError.zip("sharedStrings.xml kunne ikke tolkes")
            }
            if let parseError { throw parseError }
            return strings
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            if elementName == "si" { insideSI = true; current = "" }
            if elementName == "t", insideSI { insideT = true }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if insideT { current += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "t" { insideT = false }
            if elementName == "si" {
                strings.append(current)
                current = ""
                insideSI = false
            }
        }
    }

    private final class WorkbookParser: NSObject, XMLParserDelegate {
        private var names: [String] = []

        func parse(_ data: Data) throws -> [String] {
            let parser = XMLParser(data: data)
            parser.delegate = self
            guard parser.parse() else { return names }
            return names
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            if elementName == "sheet", let name = attributeDict["name"] {
                names.append(name)
            }
        }
    }

    private final class SheetParser: NSObject, XMLParserDelegate {
        private let sharedStrings: [String]
        private var rows: [[String]] = []
        private var currentRow: [String] = []
        private var currentValue = ""
        private var currentType = ""
        private var currentColumn = 0
        private var insideValue = false
        private var insideInlineText = false

        init(sharedStrings: [String]) {
            self.sharedStrings = sharedStrings
        }

        func parse(_ data: Data) throws -> [[String]] {
            let parser = XMLParser(data: data)
            parser.delegate = self
            guard parser.parse() else {
                throw HavenContactDocumentError.zip("regnearket kunne ikke tolkes")
            }
            return rows
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            switch elementName {
            case "row":
                currentRow = []
            case "c":
                currentType = attributeDict["t"] ?? ""
                currentValue = ""
                currentColumn = HavenXLSXReader.columnIndex(from: attributeDict["r"] ?? "") ?? currentRow.count
            case "v":
                insideValue = true
            case "t":
                insideInlineText = true
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if insideValue || insideInlineText { currentValue += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "v":
                insideValue = false
            case "t":
                insideInlineText = false
            case "c":
                let resolved: String
                if currentType == "s", let index = Int(currentValue.trimmingCharacters(in: .whitespaces)),
                   index >= 0, index < sharedStrings.count {
                    resolved = sharedStrings[index]
                } else if currentType == "b" {
                    resolved = currentValue.trimmingCharacters(in: .whitespaces) == "1" ? "TRUE" : "FALSE"
                } else {
                    resolved = currentValue
                }
                while currentRow.count < currentColumn { currentRow.append("") }
                if currentRow.count == currentColumn {
                    currentRow.append(resolved.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    currentRow[currentColumn] = resolved.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                currentValue = ""
                currentType = ""
            case "row":
                rows.append(currentRow)
                currentRow = []
            default:
                break
            }
        }
    }

    /// "B" -> 1, "AA" -> 26. Takes a cell reference like "AB12".
    static func columnIndex(from reference: String) -> Int? {
        let letters = reference.prefix { $0.isLetter }.uppercased()
        guard !letters.isEmpty else { return nil }
        var value = 0
        for character in letters {
            guard let ascii = character.asciiValue, ascii >= 65, ascii <= 90 else { return nil }
            value = value * 26 + Int(ascii - 64)
        }
        return value - 1
    }
}

// MARK: - Unified loading

nonisolated public enum HavenContactDocumentLoader {

    public struct Loaded {
        public var format: HavenContactDocumentFormat
        public var encodingName: String?
        /// Set for tabular formats.
        public var table: HavenTabularDocument?
        /// Set for vCard.
        public var cards: [HavenVCardParser.Card]?
        public var notes: [String]
    }

    public static func load(filename: String?, mimeType: String?, data: Data) throws -> Loaded {
        let format = HavenContactDocumentDetector.detect(filename: filename, mimeType: mimeType, data: data)
        switch format {
        case .numbers:
            throw HavenContactDocumentError.numbersPackage
        case .xlsx:
            let table = try HavenXLSXReader.read(data: data)
            return Loaded(format: format, encodingName: nil, table: table, cards: nil, notes: table.notes)
        case .csv, .tsv, .unknown:
            guard let decoded = HavenContactDocumentDetector.decodeTextWithEncoding(data) else {
                throw HavenContactDocumentError.unreadableText
            }
            let delimiter: Character? = format == .tsv ? "\t" : nil
            let table = try HavenDelimitedTableParser.parse(text: decoded.text, delimiter: delimiter)
            return Loaded(
                format: format == .unknown ? .csv : format,
                encodingName: decoded.encodingName,
                table: table,
                cards: nil,
                notes: table.notes + ["Tegnsett: \(decoded.encodingName)"]
            )
        case .vcard:
            guard let decoded = HavenContactDocumentDetector.decodeTextWithEncoding(data) else {
                throw HavenContactDocumentError.unreadableText
            }
            let cards = HavenVCardParser.parse(text: decoded.text)
            guard !cards.isEmpty else { throw HavenContactDocumentError.emptyDocument }
            return Loaded(
                format: .vcard,
                encodingName: decoded.encodingName,
                table: nil,
                cards: cards,
                notes: ["\(cards.count) vCard-oppføringer", "Tegnsett: \(decoded.encodingName)"]
            )
        case .json:
            throw HavenContactDocumentError.unsupportedFormat(.json)
        }
    }
}
