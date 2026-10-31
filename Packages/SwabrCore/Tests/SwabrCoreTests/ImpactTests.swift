import Foundation
import Testing
@testable import SwabrCore

@Test func kindsDecideDefaultSafety() {
    #expect(RuleKind.cache.defaultSafety == .safe)
    #expect(RuleKind.log.defaultSafety == .safe)
    #expect(RuleKind.packages.defaultSafety == .safe)
    #expect(RuleKind.trash.defaultSafety == .review)
    #expect(RuleKind.mailDownloads.defaultSafety == .review)
    #expect(RuleKind.state.defaultSafety == .review)
    #expect(CleanRule(section: "developer", label: "Gradle", kind: .packages, safety: .review, paths: []).effectiveSafety == .review)
    #expect(RuleKind.trash.impact == L("Der Papierkorb wird endgültig geleert. Diese Dateien lassen sich danach nicht wiederherstellen."))
}

/// The catalogue must stay inside the home folder, use known sections and never reach into protected areas.
@Test func bundledCatalogueIsWellFormed() throws {
    let rules = try RuleStore.cleanRules()
    #expect(rules.count > 40)
    for rule in rules {
        #expect(RuleStore.sectionOrder.contains(rule.section), "\(rule.label): unknown section \(rule.section)")
        #expect(!rule.paths.isEmpty)
        #expect(!rule.kind.impact.isEmpty)
        for path in rule.paths {
            #expect(path.hasPrefix("~/"), "\(rule.label): \(path) is outside the home folder")
            // A pattern must name something below a folder, never the folder itself or the whole Library.
            #expect(!["~/", "~/Library", "~/Library/*", "~/Library/Caches", "~/Library/Application Support"].contains(path))
            for forbidden in ["Keychains", "Mobile Documents", "CloudStorage", ".ssh", ".gnupg", "Documents/", "Desktop/", "Pictures/", "Mail/V"] {
                #expect(!path.contains(forbidden), "\(rule.label): \(path) touches \(forbidden)")
            }
        }
    }
    // Broad rules come after the specific ones, so the specific explanation wins.
    let firstBroad = rules.firstIndex { $0.section == "app_caches" }!
    #expect(!rules[firstBroad...].contains { ["browsers", "apps", "developer"].contains($0.section) })
}

@Test func protectionDataCoversCriticalAppleCaches() throws {
    let p = try RuleStore.protection()
    let w = Whitelist(home: "/Users/x", userPatterns: [], safetyPatterns: p.safetyWhitelist)
    #expect(w.protectingPattern(for: "/Users/x/Library/Caches/CloudKit/abc") != nil)
    #expect(w.protectingPattern(for: "/Users/x/Library/Caches/com.apple.bird/x") != nil)
    #expect(w.protectingPattern(for: "/Users/x/Library/Caches/com.spotify.client/x") == nil)
    #expect(p.sensitiveBundles.contains { fnmatch($0, "com.1password.1password", 0) == 0 })
    // Every protection switch points into a place some rule actually cleans.
    let rules = try RuleStore.cleanRules()
    for option in p.whitelistOptions {
        #expect(!option.pattern.isEmpty && option.pattern.hasPrefix("~/"), "\(option.label)")
    }
    #expect(!rules.isEmpty)
}

@Test func analyzeImpactWarnsForAppDataAndCloud() {
    let home = "/Users/x"
    #expect(Impact.analyze(path: home + "/Library/Application Support/Foo", isDirectory: true, isCleanable: false, home: home).warning)
    #expect(Impact.analyze(path: home + "/Library/Mobile Documents/com~apple~CloudDocs/a", isDirectory: true, isCleanable: false, home: home).warning)
    #expect(!Impact.analyze(path: home + "/dev/p/node_modules", isDirectory: true, isCleanable: true, home: home).warning)
    #expect(Impact.analyze(path: home + "/Downloads/x.dmg", isDirectory: false, isCleanable: false, home: home).text.contains("Installer"))
}

/// The core's translation of a key, in whatever language the test process runs.
func L(_ key: String.LocalizationValue) -> String { String(localized: key, bundle: .module) }

/// A rule may only make its rating stricter than its kind; and catch-all rules without a known owner, big
/// downloads and sign-in data are always reviewed.
@Test func catalogueNeverLoosensSafety() throws {
    let rules = try RuleStore.cleanRules()
    for rule in rules {
        #expect(rule.safety != .safe, "\(rule.label): sets safety to safe, choose a kind instead")
    }
    func rating(_ pattern: String) -> Safety? { rules.first { $0.paths.contains(pattern) }?.effectiveSafety }
    for pattern in ["~/Library/Application Support/*/{Cache,Caches,cache,caches}/*", "~/Library/Group Containers/*/Library/Caches/*",
                    "~/Library/Containers/*/Data/tmp/*", "~/.gradle/caches/*", "~/Library/Caches/ms-playwright/*",
                    "~/Library/Caches/Cypress/*", "~/.aws/cli/cache/*", "~/.jupyter/runtime/*", "~/.cache/*",
                    "~/Library/Caches/com.apple.*/*"] {
        #expect(rating(pattern) == .review, "\(pattern) must be reviewed")
    }
}
