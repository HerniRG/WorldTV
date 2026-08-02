import Foundation
import Testing
@testable import WorldTV

struct XMLTVParserTests {
    @Test
    func parsesProgrammesWithTitles() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme channel="BBCOne.uk" start="20240101000000 +0000" stop="20240101010000 +0000">
            <title lang="en">News at Ten</title>
            <desc lang="en">BBC News at Ten</desc>
            <category lang="en">News</category>
          </programme>
          <programme channel="BBCOne.uk" start="20240101010000 +0000" stop="20240101020000 +0000">
            <title lang="en">Top of the Pops</title>
            <sub-title lang="en">Music Chart Show</sub-title>
          </programme>
        </tv>
        """.data(using: .utf8)!

        let programs = XMLTVParser.parse(data: xml)

        #expect(programs.count == 2)
        #expect(programs[0].channelID == "BBCOne.uk")
        #expect(programs[0].title == "News at Ten")
        #expect(programs[0].desc == "BBC News at Ten")
        #expect(programs[0].category == "News")
        #expect(programs[0].startTime?.timeIntervalSince1970 == 1704067200)
        #expect(programs[0].endTime?.timeIntervalSince1970 == 1704070800)
        #expect(programs[1].subtitle == "Music Chart Show")
    }

    @Test
    func ignoresProgrammesWithoutTitle() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme channel="BBCOne.uk" start="20240101000000 +0000" stop="20240101010000 +0000">
            <desc lang="en">No title</desc>
          </programme>
          <programme channel="BBCOne.uk" start="20240101010000 +0000" stop="20240101020000 +0000">
            <title lang="en">With Title</title>
          </programme>
        </tv>
        """.data(using: .utf8)!

        let programs = XMLTVParser.parse(data: xml)

        #expect(programs.count == 1)
        #expect(programs.first?.title == "With Title")
    }

    @Test
    func parsesIconAndLanguage() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme channel="CNN.us" start="20240101000000 +0000" stop="20240101010000 +0000">
            <title lang="en">CNN Tonight</title>
            <language lang="en">en</language>
            <icon src="https://example.com/cnn.png"/>
          </programme>
        </tv>
        """.data(using: .utf8)!

        let programs = XMLTVParser.parse(data: xml)

        #expect(programs.count == 1)
        #expect(programs.first?.language == "en")
        #expect(programs.first?.iconSrc == "https://example.com/cnn.png")
    }

    @Test
    func passesFeedIDThrough() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme channel="CNN.us" start="20240101000000 +0000" stop="20240101010000 +0000">
            <title lang="en">CNN Tonight</title>
          </programme>
        </tv>
        """.data(using: .utf8)!

        let programs = XMLTVParser.parse(data: xml, feedID: "hd-feed")

        #expect(programs.first?.feedID == "hd-feed")
    }

    @Test
    func parsesDateWithoutTimezone() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <programme channel="CNN.us" start="20240101000000" stop="20240101010000">
            <title lang="en">CNN Tonight</title>
          </programme>
        </tv>
        """.data(using: .utf8)!

        let programs = XMLTVParser.parse(data: xml)

        #expect(programs.count == 1)
        #expect(programs.first?.startTime != nil)
        #expect(programs.first?.endTime != nil)
    }
}

struct GuideMapperTests {
    @Test
    func mapsGuideWithSources() throws {
        let catalog = IPTVOrgMapper().map(IPTVOrgFixtures.catalogPayload)

        #expect(catalog.guides.count == 1)
        let guide = try #require(catalog.guides.first)
        #expect(guide.channelID == "News.es")
        #expect(guide.site == "example.com")
        #expect(guide.lang == "eng")
        #expect(guide.sources.count == 1)
        #expect(guide.sources.first?.format == "XML")
        #expect(guide.sources.first?.url?.absoluteString == "https://example.com/guide.xml")
    }

    @Test
    func indexesGuidesByChannelID() {
        let catalog = IPTVOrgMapper().map(IPTVOrgFixtures.catalogPayload)

        #expect(catalog.index.guidesByChannelID["News.es"]?.count == 1)
        #expect(catalog.index.guidesByChannelID["Blocked.es"]?.isEmpty ?? true)
    }
}

struct ProgramTests {
    @Test
    func isCurrentReturnsTrueForActiveProgram() {
        let now = Date()
        let program = Program(
            id: "test.1",
            channelID: "CNN.us",
            feedID: nil,
            startTime: now.addingTimeInterval(-600),
            endTime: now.addingTimeInterval(600),
            title: "Live Now",
            subtitle: nil,
            description: nil,
            category: nil,
            language: nil,
            iconURL: nil
        )

        #expect(program.isCurrent == true)
    }

    @Test
    func isCurrentReturnsFalseForPastProgram() {
        let now = Date()
        let program = Program(
            id: "test.1",
            channelID: "CNN.us",
            feedID: nil,
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(-1800),
            title: "Earlier Today",
            subtitle: nil,
            description: nil,
            category: nil,
            language: nil,
            iconURL: nil
        )

        #expect(program.isCurrent == false)
    }

    @Test
    func progressCalculatesElapsedTime() {
        let start = Date()
        let program = Program(
            id: "test.1",
            channelID: "CNN.us",
            feedID: nil,
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            title: "One Hour Show",
            subtitle: nil,
            description: nil,
            category: nil,
            language: nil,
            iconURL: nil
        )

        let progress = program.progress(at: start.addingTimeInterval(1800))
        #expect(abs(progress - 0.5) < 0.001)
    }
}
