// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

// MARK: - Normalisation

@Suite struct HavenRelationNormalizerTests {

    @Test func emailNormalisationHandlesTheShapesExportsActuallyProduce() {
        #expect(HavenRelationNormalizer.normalizeEmail("Ola.Nordmann@Example.NO") == "ola.nordmann@example.no")
        #expect(HavenRelationNormalizer.normalizeEmail("mailto:kari@example.no") == "kari@example.no")
        #expect(HavenRelationNormalizer.normalizeEmail("Ola Nordmann <ola@example.no>") == "ola@example.no")
        #expect(HavenRelationNormalizer.normalizeEmail("  vegar@example.no ; ") == "vegar@example.no")
    }

    @Test func emailNormalisationRefusesThingsThatAreNotAddresses() {
        #expect(HavenRelationNormalizer.normalizeEmail("Ola Nordmann") == nil)
        #expect(HavenRelationNormalizer.normalizeEmail("ola@") == nil)
        #expect(HavenRelationNormalizer.normalizeEmail("@example.no") == nil)
        #expect(HavenRelationNormalizer.normalizeEmail("ola@example") == nil)
        #expect(HavenRelationNormalizer.normalizeEmail("ola@ example.no") == nil)
        #expect(HavenRelationNormalizer.normalizeEmail("+4790000000") == nil)
    }

    /// Plus-tags and dots are different mailboxes for most providers. Merging
    /// them would silently fuse two real people, so we keep them apart.
    @Test func emailNormalisationDoesNotStripPlusTagsOrDots() {
        #expect(HavenRelationNormalizer.normalizeEmail("ola+haven@example.no") == "ola+haven@example.no")
        #expect(HavenRelationNormalizer.normalizeEmail("o.la@example.no") == "o.la@example.no")
    }

    @Test func norwegianPhoneNumbersGetTheirCountryCode() {
        #expect(HavenRelationNormalizer.normalizePhone("90 00 00 00") == "+4790000000")
        #expect(HavenRelationNormalizer.normalizePhone("900 00 000") == "+4790000000")
        #expect(HavenRelationNormalizer.normalizePhone("+47 900 00 000") == "+4790000000")
        #expect(HavenRelationNormalizer.normalizePhone("004790000000") == "+4790000000")
        #expect(HavenRelationNormalizer.normalizePhone("(+47) 90-00-00-00") == "+4790000000")
    }

    @Test func phoneNormalisationRefusesRatherThanGuesses() {
        #expect(HavenRelationNormalizer.normalizePhone("ola@example.no") == nil)
        #expect(HavenRelationNormalizer.normalizePhone("Oslo") == nil)
        #expect(HavenRelationNormalizer.normalizePhone("123") == nil)
        #expect(HavenRelationNormalizer.normalizePhone("") == nil)
    }

    @Test func swedishNumbersUseTheRegionThatWasAskedFor() {
        #expect(HavenRelationNormalizer.normalizePhone("701234567", region: "SE") == "+46701234567")
    }

    @Test func endpointClassificationPicksTheRightKind() throws {
        let email = try #require(HavenRelationNormalizer.endpoint(from: "kari@example.no"))
        #expect(email.kind == .email)
        let phone = try #require(HavenRelationNormalizer.endpoint(from: "90000000"))
        #expect(phone.kind == .phone)
        let url = try #require(HavenRelationNormalizer.endpoint(from: "https://example.no/kari"))
        #expect(url.kind == .url)
        let handle = try #require(HavenRelationNormalizer.endpoint(from: "@kari"))
        #expect(handle.kind == .handle)
        #expect(HavenRelationNormalizer.endpoint(from: "bare litt tekst") == nil)
    }

    /// Re-importing the same spreadsheet must not produce twins.
    @Test func recordIdentityIsDerivedFromTheStrongestIdentifier() throws {
        let endpoint = try #require(HavenRelationNormalizer.endpoint(from: "vegar@example.no"))
        let first = HavenRelationNormalizer.recordID(
            endpoints: [endpoint],
            displayName: "Vegar Hansen",
            organization: "Kommunen"
        )
        let second = HavenRelationNormalizer.recordID(
            endpoints: [endpoint],
            displayName: "Vegar H.",
            organization: nil
        )
        #expect(first == second)

        let other = try #require(HavenRelationNormalizer.endpoint(from: "vegar@annet.no"))
        let third = HavenRelationNormalizer.recordID(
            endpoints: [other],
            displayName: "Vegar Hansen",
            organization: "Kommunen"
        )
        #expect(first != third)
    }

    @Test func disclosureTokensAreShortStableAndNotTheAddress() throws {
        let endpoint = try #require(HavenRelationNormalizer.endpoint(from: "kari@example.no"))
        #expect(endpoint.disclosureToken.count == 16)
        #expect(!endpoint.disclosureToken.contains("kari"))
        let again = try #require(HavenRelationNormalizer.endpoint(from: "KARI@Example.no"))
        #expect(endpoint.disclosureToken == again.disclosureToken)
    }
}

// MARK: - Merge

@Suite struct HavenRelationMergerTests {

    private func record(
        name: String,
        email: String? = nil,
        phone: String? = nil,
        organization: String? = nil,
        inviteState: HavenInviteState = .none
    ) -> HavenRelationRecord {
        var endpoints: [HavenRelationEndpoint] = []
        if let email, let endpoint = HavenRelationNormalizer.endpoint(from: email, preferredKind: .email) {
            endpoints.append(endpoint)
        }
        if let phone, let endpoint = HavenRelationNormalizer.endpoint(from: phone, preferredKind: .phone) {
            endpoints.append(endpoint)
        }
        return HavenRelationRecord(
            id: HavenRelationNormalizer.recordID(endpoints: endpoints, displayName: name, organization: organization),
            displayName: name,
            organization: organization,
            endpoints: endpoints,
            inviteState: inviteState
        )
    }

    @Test func aSharedAddressMeansTheSamePerson() {
        let left = record(name: "Vegar Hansen", email: "vegar@example.no")
        let right = record(name: "V. Hansen", email: "vegar@example.no", phone: "90000000")
        #expect(HavenRelationMerger.sharesStrongIdentifier(left, right))
    }

    /// A name is not an identifier. Two people can be called the same thing.
    @Test func aSharedNameAloneDoesNotMeanTheSamePerson() {
        let left = record(name: "Anne Hansen", email: "anne@a.no")
        let right = record(name: "Anne Hansen", email: "anne@b.no")
        #expect(!HavenRelationMerger.sharesStrongIdentifier(left, right))
        #expect(HavenRelationMerger.looksLikeSamePerson(left, right))
    }

    @Test func differentOrganisationsBreakTheNameLookalike() {
        let left = record(name: "Anne Hansen", email: "anne@a.no", organization: "Kommunen")
        let right = record(name: "Anne Hansen", email: "anne@b.no", organization: "Fylket")
        #expect(!HavenRelationMerger.looksLikeSamePerson(left, right))
    }

    @Test func mergingUnionsEndpointsWithoutDuplicating() {
        var left = record(name: "Vegar Hansen", email: "vegar@example.no")
        left.endpoints[0].confirmed = true
        let right = record(name: "Vegar Hansen", email: "VEGAR@example.no", phone: "90000000")
        let merged = HavenRelationMerger.merge(existing: left, incoming: right)
        #expect(merged.endpoints.count == 2)
        // A later unconfirmed import must not downgrade a confirmed address.
        #expect(merged.endpoints.first { $0.kind == .email }?.confirmed == true)
    }

    /// Blocking someone has to survive them turning up in the next spreadsheet.
    @Test func blockedSurvivesAReimport() {
        let blocked = record(name: "Vegar Hansen", email: "vegar@example.no", inviteState: .blocked)
        let incoming = record(name: "Vegar Hansen", email: "vegar@example.no", inviteState: .none)
        let merged = HavenRelationMerger.merge(existing: blocked, incoming: incoming)
        #expect(merged.inviteState == .blocked)
    }

    @Test func joinedIsNotUndoneByAnImport() {
        let joined = record(name: "Vegar Hansen", email: "vegar@example.no", inviteState: .joined)
        let incoming = record(name: "Vegar Hansen", email: "vegar@example.no", inviteState: .none)
        #expect(HavenRelationMerger.merge(existing: joined, incoming: incoming).inviteState == .joined)
    }

    @Test func inviteReadinessExplainsItselfWhenItSaysNo() {
        let noChannel = record(name: "Uten kanal")
        #expect(!noChannel.inviteReadiness.canInvite)
        #expect(noChannel.inviteReadiness.reason.contains("Uten kanal"))

        let ready = record(name: "Klar Person", email: "klar@example.no")
        #expect(ready.inviteReadiness.canInvite)
    }
}

// MARK: - Search

@Suite struct HavenRelationMatcherTests {

    private var pool: [HavenRelationRecord] {
        func make(_ name: String, _ email: String, org: String? = nil, tags: [String] = []) -> HavenRelationRecord {
            let endpoint = HavenRelationNormalizer.endpoint(from: email, preferredKind: .email)
            return HavenRelationRecord(
                id: HavenRelationNormalizer.recordID(
                    endpoints: endpoint.map { [$0] } ?? [],
                    displayName: name,
                    organization: org
                ),
                displayName: name,
                organization: org,
                endpoints: endpoint.map { [$0] } ?? [],
                contextTags: tags
            )
        }
        return [
            make("Vegar Hansen", "vegar@kommunen.no", org: "Kommunen", tags: ["arendalsuka"]),
            make("Vegard Olsen", "vegard@fylket.no", org: "Fylket"),
            make("Kari Nordmann", "kari@example.no", org: "Digipomps"),
            make("Ola Nordmann", "ola@example.no")
        ]
    }

    @Test func anExactAddressBeatsEverythingElse() throws {
        let matches = HavenRelationMatcher.search(query: "kari@example.no", in: pool)
        let first = try #require(matches.first)
        #expect(first.record.displayName == "Kari Nordmann")
        #expect(first.score == 1.0)
    }

    @Test func aPartialFirstNameStillFindsThePerson() throws {
        let matches = HavenRelationMatcher.search(query: "vegar", in: pool)
        #expect(!matches.isEmpty)
        #expect(matches.first?.record.displayName == "Vegar Hansen")
    }

    @Test func organisationNarrowsAmbiguousNames() throws {
        let matches = HavenRelationMatcher.search(query: "vegard fylket", in: pool)
        let first = try #require(matches.first)
        #expect(first.record.displayName == "Vegard Olsen")
    }

    @Test func aSharedSurnameReturnsBothRatherThanPickingOne() {
        let matches = HavenRelationMatcher.search(query: "nordmann", in: pool)
        #expect(matches.count == 2)
    }

    @Test func nonsenseReturnsNothingRatherThanAWeakGuess() {
        #expect(HavenRelationMatcher.search(query: "zzzzqqq", in: pool).isEmpty)
    }

    @Test func everyMatchCarriesAReason() {
        for match in HavenRelationMatcher.search(query: "vegar", in: pool) {
            #expect(!match.reason.isEmpty)
        }
    }
}

// MARK: - Delimited files

@Suite struct HavenDelimitedTableParserTests {

    @Test func norwegianExcelSemicolonsAreDetected() throws {
        let text = "Navn;E-post;Mobil\nVegar Hansen;vegar@example.no;90000000\nKari Nordmann;kari@example.no;90000001\n"
        let document = try HavenDelimitedTableParser.parse(text: text)
        #expect(document.headers == ["Navn", "E-post", "Mobil"])
        #expect(document.rows.count == 2)
        #expect(document.rows[0][1] == "vegar@example.no")
    }

    @Test func quotedFieldsKeepTheirDelimitersAndNewlines() throws {
        let text = "Navn,Notat\n\"Hansen, Vegar\",\"Første linje\nAndre linje\"\n"
        let document = try HavenDelimitedTableParser.parse(text: text)
        #expect(document.rows.count == 1)
        #expect(document.rows[0][0] == "Hansen, Vegar")
        #expect(document.rows[0][1].contains("Andre linje"))
    }

    @Test func doubledQuotesBecomeOneQuote() throws {
        let text = "Navn,Notat\nVegar,\"Han sa \"\"hei\"\"\"\n"
        let document = try HavenDelimitedTableParser.parse(text: text)
        #expect(document.rows[0][1] == "Han sa \"hei\"")
    }

    /// A file whose first row is already data must not lose that row.
    @Test func aHeaderlessFileKeepsItsFirstRow() throws {
        let text = "Vegar Hansen;vegar@example.no\nKari Nordmann;kari@example.no\n"
        let document = try HavenDelimitedTableParser.parse(text: text)
        #expect(document.headersWereSynthesised)
        #expect(document.rows.count == 2)
    }

    @Test func raggedRowsArePaddedRatherThanDropped() throws {
        let text = "A;B;C\n1;2;3\n4;5\n"
        let document = try HavenDelimitedTableParser.parse(text: text)
        #expect(document.rows.count == 2)
        #expect(document.rows[1].count == 3)
        #expect(document.rows[1][2] == "")
    }

    @Test func latin1FilesStillDecode() throws {
        let text = "Navn;By\nBjørn Ø. Åsen;Tromsø\n"
        let data = try #require(text.data(using: .isoLatin1))
        let decoded = try #require(HavenContactDocumentDetector.decodeTextWithEncoding(data))
        #expect(decoded.text.contains("Bjørn"))
    }

    @Test func aByteOrderMarkNeverEndsUpInsideTheFirstHeader() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("Navn;E-post\nVegar;vegar@example.no\n".utf8))
        let decoded = try #require(HavenContactDocumentDetector.decodeTextWithEncoding(data))
        let document = try HavenDelimitedTableParser.parse(text: decoded.text)
        #expect(document.headers.first == "Navn")
    }
}

// MARK: - vCard

@Suite struct HavenVCardParserTests {

    @Test func aPlainCardParses() throws {
        let text = """
        BEGIN:VCARD
        VERSION:3.0
        N:Hansen;Vegar;;;
        FN:Vegar Hansen
        ORG:Kommunen;Kultur
        TITLE:Rådgiver
        EMAIL;TYPE=WORK:vegar@kommunen.no
        TEL;TYPE=CELL:+47 900 00 000
        CATEGORIES:arendalsuka,kultur
        NOTE:Møtt på konferansen
        END:VCARD
        """
        let cards = HavenVCardParser.parse(text: text)
        let card = try #require(cards.first)
        #expect(card.fullName == "Vegar Hansen")
        #expect(card.givenName == "Vegar")
        #expect(card.familyName == "Hansen")
        #expect(card.organization == "Kommunen")
        #expect(card.jobTitle == "Rådgiver")
        #expect(card.categories == ["arendalsuka", "kultur"])
        #expect(card.endpoints.count == 2)
    }

    @Test func multipleCardsInOneFileAllArrive() {
        let text = """
        BEGIN:VCARD
        FN:Én
        EMAIL:en@example.no
        END:VCARD
        BEGIN:VCARD
        FN:To
        EMAIL:to@example.no
        END:VCARD
        """
        #expect(HavenVCardParser.parse(text: text).count == 2)
    }

    @Test func foldedLinesAreRejoined() throws {
        let text = "BEGIN:VCARD\r\nFN:Vegar\r\nNOTE:Dette er en lang\r\n  fortsettelse\r\nEND:VCARD\r\n"
        let card = try #require(HavenVCardParser.parse(text: text).first)
        #expect(card.notes?.contains("fortsettelse") == true)
    }

    @Test func aCardWithNoNameButAnAddressIsStillWorthKeeping() throws {
        let text = "BEGIN:VCARD\nEMAIL:anonym@example.no\nEND:VCARD"
        let card = try #require(HavenVCardParser.parse(text: text).first)
        #expect(card.endpoints.count == 1)
    }

    @Test func vCardRecordsCarryTheirProvenance() throws {
        let cards = HavenVCardParser.parse(text: "BEGIN:VCARD\nFN:Vegar Hansen\nEMAIL:vegar@example.no\nEND:VCARD")
        let result = HavenContactColumnInference.buildRecords(
            cards: cards,
            source: HavenRelationSource(kind: .fileImport, label: "kontakter.vcf", batchID: "b1")
        )
        let record = try #require(result.records.first)
        #expect(record.sources.first?.batchID == "b1")
        #expect(record.sources.first?.locator == "vCard 1")
    }
}

// MARK: - Column inference

@Suite struct HavenContactColumnInferenceTests {

    @Test func norwegianHeadersMapWithoutHelp() throws {
        let text = """
        Fornavn;Etternavn;E-post;Mobil;Firma;Stilling
        Vegar;Hansen;vegar@kommunen.no;90000000;Kommunen;Rådgiver
        Kari;Nordmann;kari@example.no;90000001;Digipomps;Utvikler
        """
        let document = try HavenDelimitedTableParser.parse(text: text)
        let (mapping, _) = HavenContactColumnInference.infer(document: document)
        #expect(mapping.columns(for: .givenName) == [0])
        #expect(mapping.columns(for: .familyName) == [1])
        #expect(mapping.columns(for: .email) == [2])
        #expect(mapping.columns(for: .phone) == [3])
        #expect(mapping.columns(for: .organization) == [4])
        #expect(mapping.columns(for: .jobTitle) == [5])
        #expect(mapping.isUsable)
    }

    @Test func englishHeadersMapToo() throws {
        let text = """
        First Name,Last Name,Email Address,Phone,Company
        Vegar,Hansen,vegar@kommunen.no,+4790000000,Kommunen
        """
        let document = try HavenDelimitedTableParser.parse(text: text)
        let (mapping, _) = HavenContactColumnInference.infer(document: document)
        #expect(mapping.columns(for: .email) == [2])
        #expect(mapping.columns(for: .phone) == [3])
    }

    /// The header is only half the evidence. A file with no useful headers at
    /// all still has to work.
    @Test func valueShapeCarriesAFileWithNoHeaders() throws {
        let text = """
        Vegar Hansen;vegar@kommunen.no;90000000
        Kari Nordmann;kari@example.no;90000001
        Ola Nordmann;ola@example.no;90000002
        """
        let document = try HavenDelimitedTableParser.parse(text: text)
        #expect(document.headersWereSynthesised)
        let (mapping, _) = HavenContactColumnInference.infer(document: document)
        #expect(mapping.columns(for: .email) == [1])
        #expect(mapping.columns(for: .phone) == [2])
        #expect(mapping.isUsable)
    }

    @Test func misleadingHeadersLoseToTheActualValues() throws {
        // The header says "Kolonne A" but every value is an address.
        let text = """
        Kolonne A;Kolonne B
        vegar@kommunen.no;Vegar Hansen
        kari@example.no;Kari Nordmann
        ola@example.no;Ola Nordmann
        """
        let document = try HavenDelimitedTableParser.parse(text: text)
        let (mapping, _) = HavenContactColumnInference.infer(document: document)
        #expect(mapping.columns(for: .email) == [0])
    }

    @Test func everyAssessmentCarriesAReasonAndSamples() throws {
        let text = "Navn;E-post\nVegar Hansen;vegar@example.no\n"
        let document = try HavenDelimitedTableParser.parse(text: text)
        let (_, assessments) = HavenContactColumnInference.infer(document: document)
        #expect(assessments.count == 2)
        for assessment in assessments {
            #expect(!assessment.reason.isEmpty)
        }
        #expect(assessments[1].sampleValues.contains("vegar@example.no"))
    }

    @Test func aFileWithNothingUsableSaysSoInsteadOfInventing() throws {
        let text = "Beløp;Dato\n100;2026-01-01\n200;2026-01-02\n"
        let document = try HavenDelimitedTableParser.parse(text: text)
        let (mapping, _) = HavenContactColumnInference.infer(document: document)
        #expect(!mapping.isUsable)
    }

    @Test func oneCellHoldingTwoAddressesBecomesTwoEndpoints() throws {
        // Comma-delimited, so the semicolons stay inside the one cell.
        let document = try HavenDelimitedTableParser.parse(
            text: "Navn,E-post\nVegar Hansen,\"vegar@a.no; vegar@b.no\"\n",
            delimiter: ","
        )
        var mapping = HavenColumnMapping()
        mapping.assignments = [0: .fullName, 1: .email]
        let result = HavenContactColumnInference.buildRecords(
            document: document,
            mapping: mapping,
            source: HavenRelationSource(kind: .fileImport, label: "t.csv", batchID: "b")
        )
        let record = try #require(result.records.first)
        #expect(record.endpoints.filter { $0.kind == .email }.count == 2)
    }

    @Test func unusableRowsAreReportedNotSilentlyDropped() throws {
        let document = HavenTabularDocument(
            headers: ["Navn", "E-post"],
            rows: [["Vegar Hansen", "vegar@example.no"], ["", ""], ["", "ikke en adresse"]]
        )
        var mapping = HavenColumnMapping()
        mapping.assignments = [0: .fullName, 1: .email]
        let result = HavenContactColumnInference.buildRecords(
            document: document,
            mapping: mapping,
            source: HavenRelationSource(kind: .fileImport, label: "t.csv", batchID: "b")
        )
        #expect(result.records.count == 1)
        #expect(result.skippedRows == 2)
        #expect(!result.problems.isEmpty)
    }

    @Test func recordsBuiltFromATableCarryTheirRowNumber() throws {
        let document = HavenTabularDocument(
            headers: ["Navn", "E-post"],
            rows: [["Vegar Hansen", "vegar@example.no"]]
        )
        var mapping = HavenColumnMapping()
        mapping.assignments = [0: .fullName, 1: .email]
        let result = HavenContactColumnInference.buildRecords(
            document: document,
            mapping: mapping,
            source: HavenRelationSource(kind: .fileImport, label: "t.csv", batchID: "b")
        )
        #expect(result.records.first?.sources.first?.locator == "rad 2")
    }
}

// MARK: - XLSX

@Suite struct HavenXLSXReaderTests {

    /// Builds a real .xlsx with stored (uncompressed) entries, which is a valid
    /// ZIP and exercises the same central-directory path as a compressed one.
    private func makeWorkbook(sheet: String, sharedStrings: String?, workbook: String) -> Data {
        struct Entry { var name: String; var payload: Data }
        var entries: [Entry] = [
            Entry(name: "xl/workbook.xml", payload: Data(workbook.utf8)),
            Entry(name: "xl/worksheets/sheet1.xml", payload: Data(sheet.utf8))
        ]
        if let sharedStrings {
            entries.append(Entry(name: "xl/sharedStrings.xml", payload: Data(sharedStrings.utf8)))
        }

        func uint16(_ value: Int) -> Data { Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]) }
        func uint32(_ value: Int) -> Data {
            Data([
                UInt8(value & 0xFF),
                UInt8((value >> 8) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                UInt8((value >> 24) & 0xFF)
            ])
        }

        var archive = Data()
        var offsets: [Int] = []
        for entry in entries {
            offsets.append(archive.count)
            let nameData = Data(entry.name.utf8)
            archive.append(uint32(0x04034B50))
            archive.append(uint16(20))          // version needed
            archive.append(uint16(0))           // flags
            archive.append(uint16(0))           // method: stored
            archive.append(uint16(0))           // time
            archive.append(uint16(0))           // date
            archive.append(uint32(0))           // crc32 (not checked by the reader)
            archive.append(uint32(entry.payload.count))
            archive.append(uint32(entry.payload.count))
            archive.append(uint16(nameData.count))
            archive.append(uint16(0))           // extra length
            archive.append(nameData)
            archive.append(entry.payload)
        }

        let centralStart = archive.count
        for (index, entry) in entries.enumerated() {
            let nameData = Data(entry.name.utf8)
            archive.append(uint32(0x02014B50))
            archive.append(uint16(20))          // version made by
            archive.append(uint16(20))          // version needed
            archive.append(uint16(0))           // flags
            archive.append(uint16(0))           // method
            archive.append(uint16(0))           // time
            archive.append(uint16(0))           // date
            archive.append(uint32(0))           // crc32
            archive.append(uint32(entry.payload.count))
            archive.append(uint32(entry.payload.count))
            archive.append(uint16(nameData.count))
            archive.append(uint16(0))           // extra
            archive.append(uint16(0))           // comment
            archive.append(uint16(0))           // disk number
            archive.append(uint16(0))           // internal attrs
            archive.append(uint32(0))           // external attrs
            archive.append(uint32(offsets[index]))
            archive.append(nameData)
        }
        let centralSize = archive.count - centralStart

        archive.append(uint32(0x06054B50))
        archive.append(uint16(0))
        archive.append(uint16(0))
        archive.append(uint16(entries.count))
        archive.append(uint16(entries.count))
        archive.append(uint32(centralSize))
        archive.append(uint32(centralStart))
        archive.append(uint16(0))
        return archive
    }

    private var workbookXML: String {
        "<workbook><sheets><sheet name=\"Kontakter\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>"
    }

    @Test func sharedStringsResolveIntoCells() throws {
        let sharedStrings = """
        <sst count="5" uniqueCount="5">\
        <si><t>Navn</t></si>\
        <si><t>E-post</t></si>\
        <si><t>Vegar Hansen</t></si>\
        <si><t>vegar@example.no</t></si>\
        <si><t>Kari Nordmann</t></si>\
        </sst>
        """
        let sheet = """
        <worksheet><sheetData>\
        <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>\
        <row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2" t="s"><v>3</v></c></row>\
        <row r="3"><c r="A3" t="s"><v>4</v></c><c r="B3" t="inlineStr"><is><t>kari@example.no</t></is></c></row>\
        </sheetData></worksheet>
        """
        let data = makeWorkbook(sheet: sheet, sharedStrings: sharedStrings, workbook: workbookXML)
        #expect(HavenContactDocumentDetector.detect(filename: "kontakter.xlsx", mimeType: nil, data: data) == .xlsx)

        let document = try HavenXLSXReader.read(data: data)
        #expect(document.headers == ["Navn", "E-post"])
        #expect(document.rows.count == 2)
        #expect(document.rows[0][1] == "vegar@example.no")
        #expect(document.rows[1][1] == "kari@example.no")
    }

    @Test func gapsInARowLandInTheRightColumn() throws {
        let sheet = """
        <worksheet><sheetData>\
        <row r="1"><c r="A1" t="inlineStr"><is><t>Navn</t></is></c>\
        <c r="C1" t="inlineStr"><is><t>E-post</t></is></c></row>\
        <row r="2"><c r="A2" t="inlineStr"><is><t>Vegar</t></is></c>\
        <c r="C2" t="inlineStr"><is><t>vegar@example.no</t></is></c></row>\
        </sheetData></worksheet>
        """
        let data = makeWorkbook(sheet: sheet, sharedStrings: nil, workbook: workbookXML)
        let document = try HavenXLSXReader.read(data: data)
        #expect(document.headers.count == 3)
        #expect(document.headers[2] == "E-post")
        #expect(document.rows[0][2] == "vegar@example.no")
    }

    @Test func columnLettersConvertPastZ() {
        #expect(HavenXLSXReader.columnIndex(from: "A1") == 0)
        #expect(HavenXLSXReader.columnIndex(from: "B2") == 1)
        #expect(HavenXLSXReader.columnIndex(from: "Z9") == 25)
        #expect(HavenXLSXReader.columnIndex(from: "AA1") == 26)
        #expect(HavenXLSXReader.columnIndex(from: "AB1") == 27)
    }

    @Test func theWholePipelineRunsFromBytesToRecords() throws {
        let sheet = """
        <worksheet><sheetData>\
        <row r="1"><c r="A1" t="inlineStr"><is><t>Navn</t></is></c>\
        <c r="B1" t="inlineStr"><is><t>E-post</t></is></c>\
        <c r="C1" t="inlineStr"><is><t>Mobil</t></is></c></row>\
        <row r="2"><c r="A2" t="inlineStr"><is><t>Vegar Hansen</t></is></c>\
        <c r="B2" t="inlineStr"><is><t>vegar@example.no</t></is></c>\
        <c r="C2" t="inlineStr"><is><t>90000000</t></is></c></row>\
        </sheetData></worksheet>
        """
        let data = makeWorkbook(sheet: sheet, sharedStrings: nil, workbook: workbookXML)
        let loaded = try HavenContactDocumentLoader.load(filename: "kontakter.xlsx", mimeType: nil, data: data)
        let table = try #require(loaded.table)
        let (mapping, _) = HavenContactColumnInference.infer(document: table)
        let result = HavenContactColumnInference.buildRecords(
            document: table,
            mapping: mapping,
            source: HavenRelationSource(kind: .fileImport, label: "kontakter.xlsx", batchID: "b1")
        )
        let record = try #require(result.records.first)
        #expect(record.displayName == "Vegar Hansen")
        #expect(record.endpoints.contains { $0.normalized == "vegar@example.no" })
        #expect(record.endpoints.contains { $0.normalized == "+4790000000" })
        #expect(record.inviteReadiness.canInvite)
    }
}

// MARK: - Format detection

@Suite struct HavenContactDocumentDetectorTests {

    @Test func vCardIsRecognisedByItsContentNotItsName() {
        let data = Data("BEGIN:VCARD\nFN:Vegar\nEND:VCARD".utf8)
        #expect(HavenContactDocumentDetector.detect(filename: "noe.txt", mimeType: nil, data: data) == .vcard)
    }

    @Test func aNumbersPackageIsRecognisedAndExplainedRatherThanFailingBlankly() {
        // A ZIP whose entries look like an iWork package.
        var archive = Data([0x50, 0x4B, 0x03, 0x04])
        archive.append(Data(repeating: 0, count: 64))
        let format = HavenContactDocumentDetector.detect(filename: "kontakter.numbers", mimeType: nil, data: archive)
        // The central directory is missing, so byte sniffing gives up and the
        // extension decides — which is exactly the case we must explain well.
        #expect(format == .numbers || format == .unknown)
        #expect(HavenContactDocumentError.numbersPackage.description.contains("Eksporter"))
    }

    @Test func aPlainCsvIsRecognisedWithoutAnExtension() {
        let data = Data("Navn;E-post\nVegar;vegar@example.no\n".utf8)
        #expect(HavenContactDocumentDetector.detect(filename: nil, mimeType: nil, data: data) == .csv)
    }
}

// MARK: - Project roles and inferred interests

/// A participant roster carries two different things that both look like a
/// role: what the person does for a living, and what they signed up to do in
/// this particular project. Conflating them loses the one you sort on.
@Suite struct HavenProjectRoleTests {

    @Test func theAssignmentInTheProjectIsNotTheJobTitle() throws {
        let document = HavenTabularDocument(
            headers: ["Navn", "Firma", "Stilling", "Oppgave i nettverket"],
            rows: [["Sjur Dagestad", "Innoco", "Professor emeritus", "Prosjektleder og redaktør"]]
        )
        let (mapping, _) = HavenContactColumnInference.infer(document: document)
        #expect(mapping.columns(for: .organization) == [1])
        #expect(mapping.columns(for: .jobTitle) == [2])
        #expect(mapping.columns(for: .projectRole) == [3])
    }

    /// The role is what you filter on when deciding who to invite, so it has
    /// to be a tag. Burying it in the note would make it unsearchable.
    @Test func theProjectRoleBecomesATagAndNotOnlyANote() throws {
        let document = HavenTabularDocument(
            headers: ["Navn", "Oppgave i nettverket"],
            rows: [["Sjur Dagestad", "Prosjektleder og redaktør"]]
        )
        var mapping = HavenColumnMapping()
        mapping.assignments = [0: .fullName, 1: .projectRole]
        let result = HavenContactColumnInference.buildRecords(
            document: document,
            mapping: mapping,
            source: HavenRelationSource(kind: .fileImport, label: "deltakere.xlsx", batchID: "b")
        )
        let record = try #require(result.records.first)
        #expect(record.contextTags.contains("Prosjektleder og redaktør"))
        #expect(record.notes?.contains("Prosjektleder og redaktør") == true)
    }

    @Test func severalAssignmentsInOneCellBecomeSeveralTags() throws {
        let document = HavenTabularDocument(
            headers: ["Navn", "Oppgave i nettverket"],
            rows: [["Kari Nordmann", "Redaktør; Gruppeleder"]]
        )
        var mapping = HavenColumnMapping()
        mapping.assignments = [0: .fullName, 1: .projectRole]
        let result = HavenContactColumnInference.buildRecords(
            document: document,
            mapping: mapping,
            source: HavenRelationSource(kind: .fileImport, label: "t.xlsx", batchID: "b")
        )
        let record = try #require(result.records.first)
        #expect(record.contextTags.contains("Redaktør"))
        #expect(record.contextTags.contains("Gruppeleder"))
    }
}

/// A working group the person chose is evidence. A guess read off their job
/// title is a hypothesis. The graph must not weigh them the same.
@Suite struct HavenInferredInterestWeightTests {

    private func record(tags: String) throws -> HavenRelationRecord {
        let document = HavenTabularDocument(
            headers: ["Navn", "Interesser"],
            rows: [["Kari Nordmann", tags]]
        )
        var mapping = HavenColumnMapping()
        mapping.assignments = [0: .fullName, 1: .tags]
        let result = HavenContactColumnInference.buildRecords(
            document: document,
            mapping: mapping,
            source: HavenRelationSource(kind: .fileImport, label: "t.xlsx", batchID: "b")
        )
        return try #require(result.records.first)
    }

    private func weights(_ values: [ValueType]) -> [(name: String, weight: Double)] {
        values.compactMap { value in
            guard case .object(let entry) = value,
                  case .float(let weight)? = entry["weight"],
                  case .object(let inner)? = entry["value"],
                  case .string(let name)? = inner["name"] else { return nil }
            return (name: name, weight: Double(weight))
        }
    }

    @Test func aDeclaredInterestWeighsMoreThanAnInferredOne() throws {
        let record = try record(tags: "KI og tillit; antatt:ledelse og forretningsutvikling")
        let interests = weights(BindingRelationsCell.interestWeights(for: record))

        let declared = try #require(interests.first { $0.name == "KI og tillit" })
        let inferred = try #require(interests.first { $0.name == "ledelse og forretningsutvikling" })
        #expect(declared.weight > inferred.weight)
    }

    /// The prefix is bookkeeping for the importer, not something a person
    /// should ever read back out of their own graph.
    @Test func theInferredMarkerDoesNotLeakIntoTheInterestName() throws {
        let record = try record(tags: "antatt:forskning og akademia")
        let interests = weights(BindingRelationsCell.interestWeights(for: record))
        #expect(interests.map(\.name) == ["forskning og akademia"])
    }

    /// The list is capped. Before, insertion order decided who survived the
    /// cut, so a guess could push out a fact the person had actually stated.
    @Test func aGuessNeverDisplacesAFactWhenTheListIsCapped() throws {
        let guesses = (1...11).map { "antatt:gjetning \($0)" }
        let facts = (1...3).map { "faktum \($0)" }
        let record = try record(tags: (guesses + facts).joined(separator: "; "))

        let interests = weights(BindingRelationsCell.interestWeights(for: record))
        for fact in facts {
            #expect(interests.contains { $0.name == fact }, "\(fact) ble kastet ut av en gjetning")
        }
    }
}

// MARK: - The relation in my entity

/// The device record becomes an entity record that can travel: roles per
/// context, declared and inferred interests apart, channels as tokens, and
/// the entity's own memory — evidence, interactions, verification — intact.
@Suite struct HavenRelationEntityMapperTests {

    private func vegar() throws -> HavenRelationRecord {
        let document = HavenTabularDocument(
            headers: ["Navn", "Firma", "Stilling", "Gruppe", "Oppgave i nettverket", "Interesser", "E-post"],
            rows: [["Vegar Hansen", "Kommunen", "Rådgiver", "KI og tillit", "Gruppeleder",
                    "Bok: Rammebetingelser for innovasjon; antatt:ledelse", "vegar@kommunen.no"]]
        )
        let (mapping, _) = HavenContactColumnInference.infer(document: document)
        let result = HavenContactColumnInference.buildRecords(
            document: document,
            mapping: mapping,
            source: HavenRelationSource(kind: .fileImport, label: "deltakere.xlsx", batchID: "b-bok"),
            context: "Bok: Rammebetingelser for innovasjon"
        )
        return try #require(result.records.first)
    }

    @Test func aGroupColumnBecomesARoleInTheNamedContext() throws {
        let record = try vegar()
        let role = try #require(record.roles.first)
        #expect(role.context == "Bok: Rammebetingelser for innovasjon")
        #expect(role.group == "KI og tillit")
        #expect(role.role == "Gruppeleder")
        #expect(record.contextTags.contains("KI og tillit"), "the group is also a declared interest")
    }

    @Test func theEntityRecordSplitsDeclaredFromInferredAndKeepsTheAddressOut() throws {
        let record = try vegar()
        let entity = HavenRelationEntityMapper.entityRecord(from: record, existing: nil, perspectiveRef: "e-abc")

        #expect(entity.relationID == record.id)
        #expect(entity.interests.declared.contains("KI og tillit"))
        #expect(entity.interests.declared.contains("Bok: Rammebetingelser for innovasjon"))
        #expect(entity.interests.inferred == ["ledelse"])
        #expect(entity.origin.kind == .fileImport)
        #expect(entity.origin.sourceLabel == "deltakere.xlsx")
        #expect(entity.origin.context == "Bok: Rammebetingelser for innovasjon")
        #expect(entity.subject.perspectiveRef == "e-abc")

        let email = try #require(entity.channels.first { $0.kind == .email })
        #expect(!email.ref.contains("@"))
        #expect(email.ref == record.endpoints.first?.disclosureToken)
        #expect(throws: Never.self) { try EntityRelationRecordV1.validate(entity) }
    }

    @Test func aResyncKeepsWhatOnlyTheEntityKnows() throws {
        let record = try vegar()
        var first = HavenRelationEntityMapper.entityRecord(from: record, existing: nil, perspectiveRef: nil)
        first.channels.append(EntityRelationChannel(kind: .havenCorrespondence, ref: "peer-vegar", confirmed: true))
        first.evidence.append(EntityRelationEvidence(
            id: "ev-vc-1", kind: .vcPresented, direction: .inbound, at: Date(), ref: "vc-123", verified: true
        ))
        first.standing.trust = .verified
        first.interactions.count = 3

        let second = HavenRelationEntityMapper.entityRecord(from: record, existing: first, perspectiveRef: nil)
        #expect(second.channels.contains { $0.kind == .havenCorrespondence && $0.confirmed })
        #expect(second.evidence.count == 1)
        #expect(second.standing.trust == .verified)
        #expect(second.interactions.count == 3)
        #expect(second.revision == first.revision + 1)
        #expect(second.createdAt == first.createdAt)
    }

    @Test func blockingOnTheDeviceOutranksVerificationInTheEntity() throws {
        var record = try vegar()
        var existing = HavenRelationEntityMapper.entityRecord(from: record, existing: nil, perspectiveRef: nil)
        existing.standing.trust = .verified
        record.inviteState = .blocked
        #expect(HavenRelationEntityMapper.entityRecord(from: record, existing: existing, perspectiveRef: nil).standing.trust == .blocked)

        record.inviteState = .sent
        #expect(HavenRelationEntityMapper.entityRecord(from: record, existing: nil, perspectiveRef: nil).standing.trust == .invited)
        record.inviteState = .joined
        #expect(HavenRelationEntityMapper.entityRecord(from: record, existing: nil, perspectiveRef: nil).standing.trust == .joined)
    }

    @Test func someoneWithAnEntityGetsAChatChannelThePlannerPrefers() throws {
        var record = try vegar()
        record.entityRef = "entity-vegar"
        let entity = HavenRelationEntityMapper.entityRecord(from: record, existing: nil, perspectiveRef: nil)
        #expect(entity.channels.contains { $0.kind == .havenChat && $0.ref == "entity-vegar" })
        #expect(EntityRelationReachPlanner.plan(for: entity).recommended?.action == .openChat)
    }
}

@Suite struct HavenButlerInviteTargetTests {

    @Test func theNameSurvivesAndTheVerbDoesNot() {
        #expect(BindingPersonalChatHubCell.inviteTargetName(in: "Inviter Vegar") == "Vegar")
        #expect(BindingPersonalChatHubCell.inviteTargetName(in: "Kan du invitere Vegar Hansen inn i chatten?") == "Vegar Hansen")
        #expect(BindingPersonalChatHubCell.inviteTargetName(in: "invite Victoria to the chat, please") == "Victoria")
        #expect(BindingPersonalChatHubCell.inviteTargetName(in: "inviter") == "")
    }
}

// MARK: - The book project, end to end

/// Runs the real participant list through the same inference and record
/// assembly the app uses. The file holds 189 real people and is gitignored,
/// so the test looks for it on this machine and steps aside when it is not
/// there. It is the proof that «få inn alle medlemmene i bokprosjektet»
/// produces relations you can sort by working group and role.
@Suite struct HavenBookProjectImportTests {

    private static var fileURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // BindingTests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent(".sprout/import/HAVEN_import_bokprosjekt.xlsx")
    }

    @Test func everyParticipantBecomesARelationWithGroupAndRole() throws {
        guard let data = try? Data(contentsOf: Self.fileURL) else {
            // Not on this machine. Nothing to prove, nothing to fail.
            return
        }
        let document = try HavenXLSXReader.read(data: data)
        let (mapping, _) = HavenContactColumnInference.infer(document: document)
        #expect(mapping.columns(for: .fullName).isEmpty == false)
        #expect(mapping.columns(for: .group).isEmpty == false, "«Gruppe» must map to the group field, not to tags")
        #expect(mapping.columns(for: .projectRole).isEmpty == false)
        #expect(mapping.columns(for: .tags).isEmpty == false, "«Interesser» stays a tag column")
        #expect(mapping.columns(for: .email).isEmpty == false)

        let context = "Bok: Rammebetingelser for innovasjon"
        let result = HavenContactColumnInference.buildRecords(
            document: document,
            mapping: mapping,
            source: HavenRelationSource(kind: .fileImport, label: "HAVEN_import_bokprosjekt.xlsx", batchID: "bok-2026"),
            context: context
        )
        #expect(result.records.count == 189, "problems: \(result.problems.prefix(5))")
        #expect(result.skippedRows == 0)

        let withGroup = result.records.filter { $0.roles.contains { $0.group != nil } }
        #expect(withGroup.count == 181)
        #expect(result.records.allSatisfy { $0.roles.isEmpty || $0.roles[0].context == context })

        let editor = try #require(result.records.first { $0.displayName == "Sjur Dagestad" })
        #expect(editor.roles.first?.role == "Prosjektleder og redaktør")
        #expect(editor.contextTags.contains("Prosjektleder og redaktør"))
        #expect(editor.contextTags.contains(context))
        #expect(editor.contextTags.contains { $0.hasPrefix("antatt:") })

        // Every one of them can be looked up by working group in the entity.
        let entities = result.records.map { HavenRelationEntityMapper.entityRecord(from: $0, existing: nil, perspectiveRef: nil) }
        let byGroup = Dictionary(grouping: entities.flatMap { entity in entity.roles.compactMap(\.group).map { ($0, entity) } }, by: \.0)
        #expect(byGroup["KI og tillit"]?.count == 20)
        #expect(byGroup["Bærekraft"]?.count == 13)
        for entity in entities {
            #expect(throws: Never.self) { try EntityRelationRecordV1.validate(entity) }
            #expect(!entity.channels.contains { $0.ref.contains("@") }, "no address may reach the entity record")
        }
    }
}
