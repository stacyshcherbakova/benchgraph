import Testing
import Foundation
@testable import BenchGraphKit

/// The in-app help catalog and its binding to the published guide.
///
/// Each topic's `id` is the slug of a page under `docs/guide/`. Checking that
/// binding here is what keeps "one guide, two lengths" (spec D6) honest: a
/// renamed or deleted page breaks a test rather than becoming a 404 that only a
/// user discovers.
@Suite struct HelpTopicTests {

    /// Repo root, resolved from this file: Tests/BenchGraphKitTests/x.swift → ../../
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test func catalogIsPopulated() {
        #expect(!BenchGraphDocs.topics.isEmpty)
        for topic in BenchGraphDocs.topics {
            #expect(!topic.title.isEmpty)
            #expect(!topic.summary.isEmpty)
            #expect(topic.steps.count >= 4, "\(topic.id) should give the user real steps")
            #expect(!topic.steps.contains { $0.isEmpty })
        }
    }

    @Test func slugsAreUnique() {
        let ids = BenchGraphDocs.topics.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func lookupFindsEveryTopicAndRejectsUnknownSlugs() {
        for topic in BenchGraphDocs.topics {
            #expect(BenchGraphDocs.topic(topic.id) == topic)
        }
        #expect(BenchGraphDocs.topic("no-such-page") == nil)
    }

    /// MkDocs publishes with `use_directory_urls` at its default of true, so the
    /// page URL is a trailing-slash directory, not a `.md` file.
    @Test func guideURLsUseTheDirectoryForm() {
        let url = BenchGraphDocs.url(forGuide: "getting-started")
        #expect(url.absoluteString == "https://stacyshcherbakova.github.io/benchgraph/guide/getting-started/")
        #expect(!url.absoluteString.contains(".md"))
    }

    @Test func siteURLMatchesTheDocsConfig() throws {
        let config = repoRoot.appendingPathComponent("mkdocs.yml")
        guard let yaml = try? String(contentsOf: config, encoding: .utf8) else { return }
        let line = yaml.split(separator: "\n").first { $0.hasPrefix("site_url:") }
        let declared = try #require(line?.replacingOccurrences(of: "site_url:", with: "")
            .trimmingCharacters(in: .whitespaces))
        #expect(BenchGraphDocs.siteURL.absoluteString == declared)
    }

    /// Every in-app topic must have a published page behind it, titled the same.
    @Test func everyTopicHasAGuidePageWithAMatchingTitle() throws {
        let guideDir = repoRoot.appendingPathComponent("docs/guide")
        guard FileManager.default.fileExists(atPath: guideDir.path) else { return }

        for topic in BenchGraphDocs.topics {
            let page = guideDir.appendingPathComponent("\(topic.id).md")
            #expect(FileManager.default.fileExists(atPath: page.path),
                    "no docs/guide/\(topic.id).md behind the in-app '\(topic.title)' card")

            guard let text = try? String(contentsOf: page, encoding: .utf8) else { continue }
            let h1 = text.split(separator: "\n").first { $0.hasPrefix("# ") }?
                .dropFirst(2).trimmingCharacters(in: .whitespaces)
            #expect(h1 == topic.title,
                    "docs/guide/\(topic.id).md is titled \(h1 ?? "nothing"), the app says \(topic.title)")
        }
    }

    /// The guide directory must not accumulate pages the app never links to.
    @Test func everyGuidePageIsReachableFromTheApp() throws {
        let guideDir = repoRoot.appendingPathComponent("docs/guide")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: guideDir.path) else { return }
        let slugs = Set(BenchGraphDocs.topics.map(\.id))
        for file in files where file.hasSuffix(".md") {
            let slug = String(file.dropLast(3))
            #expect(slugs.contains(slug), "docs/guide/\(file) is not linked from any help card")
        }
    }
}
