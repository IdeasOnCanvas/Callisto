//
//  UploadAction.swift
//  Callisto
//
//  Created by Patrick Kladek on 02.08.19.
//  Copyright © 2019 IdeasOnCanvas. All rights reserved.
//

import Foundation


/// Responsible to read the build summaries and post them to github
final class UploadAction: NSObject {

    let defaults: UserDefaults
    let githubController: GitHubCommunicationController

    // MARK: - Properties

    // MARK: - Lifecycle
	
    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.githubController = GitHubCommunicationController(account: defaults.githubAccount,
                                                              repository: defaults.githubRepository)
	}

    // MARK: - UploadAction

    func run() -> Never {
        let inputFiles = CommandLine.parameters(forKey: "files").map { URL(fileURLWithPath: $0) }
//        let slackURL = self.defaults.slackURL
//        let ignoredKeywords = self.defaults.ignoredKeywords

        guard inputFiles.count > 0 else {
            quit(.invalidBuildInformationFile)
        }

        let infos = inputFiles.map { BuildInformation.read(url: $0) }.compactMap { result -> BuildInformation? in
            switch result {
            case .success(let info):
                return info
            case .failure(let error):
                LogError("\(error)")
                return nil
            }
        }

        let coreInfos = self.commonInfos(infos)
        let stripped = self.stripInfos(coreInfos, from: infos)
        self.logBuildInfo([coreInfos].compactMap { $0 })
        self.logBuildInfo(stripped)

        let currentBranch = self.loadCurrentBranch()
        print(currentBranch)

//        print(MarkdownTable(info: infos[0]).markdownString )
        print(self.markdownText(from: infos[0]))
        print(self.markdownText(from: infos[1]))

        quit(.success)
    }
}

// MARK: - Private

private extension UploadAction {

    func loadCurrentBranch() -> Branch {
        switch self.loadCurrentBranch(name: defaults.branch) {
        case .success(let branch):
            return branch
        case .failure(let error):
            LogError(error.localizedDescription)
            quit(.reloadBranchFailed)
        }
    }

    func commonInfos(_ infos: [BuildInformation]) -> BuildInformation? {
        guard infos.count > 1 else { return nil }

        let commonErrors = infos[0].errors.filter { infos[1].errors.contains($0) }
        let commonWarnings = infos[0].warnings.filter { infos[1].warnings.contains($0) }
        let commonUnitTests = infos[0].unitTests.filter { infos[1].unitTests.contains($0) }

        return BuildInformation(platform: "Core",
                                errors: commonErrors,
                                warnings: commonWarnings,
                                unitTests: commonUnitTests)
    }

    func stripInfos(_ strip: BuildInformation?, from: [BuildInformation]) -> [BuildInformation] {
        guard let strip = strip else { return from }

        return from.map { info -> BuildInformation in
            BuildInformation(platform: info.platform,
                             errors: info.errors.deleting(strip.errors),
                             warnings: info.warnings.deleting(strip.warnings),
                             unitTests: info.unitTests.deleting(strip.unitTests))
        }
    }

    func loadCurrentBranch(name: String) -> Result<Branch, Error> {
        do {
            let dict: [String: Any]
            try dict = self.githubController.pullRequest(forBranch: name)
            guard let branchPath = dict["html_url"] as? String, let title = dict["title"] as? String else { throw GithubError.pullRequestNoURL }

            return .success(Branch(title: title, name: name, url: URL(string: branchPath)))
        } catch {
            LogError("Something happend when collecting information about Pull Requests")
            return .failure(error)
        }
    }

    func logBuildInfo(_ infos: [BuildInformation]) {
        for info in infos {
            LogMessage("*** \(info.platform) ***")
            for error in info.errors {
                LogError(error.description)
            }

            for warning in info.warnings {
                LogWarning(warning.description)
            }

            for unitTest in info.unitTests {
                LogWarning(unitTest.description)
            }
        }
    }

    func markdownText(from info: BuildInformation) -> String {
        var string = "### \(info.platform)"

        if info.errors.hasElements {
            string += "\n\n"
            string += info.errors.map { ":error: `\($0.file):\($0.line)`\n\($0.message)" }.joined(separator: "\n")
        }

        if info.warnings.hasElements {
            string += "\n\n"
            string += info.warnings.map { ":warning: `\($0.file):\($0.line)`\n\($0.message)" }.joined(separator: "\n")
        }

        if info.unitTests.hasElements {
            string += "\n\n"
            string += info.unitTests.map { ":large_blue_circle: `\($0.method)`\n\($0.explanation)" }.joined(separator: "\n")
        }
        return string
    }
}

private extension Array where Element: Equatable {

    mutating func delete(_ object: Element) {
        guard let index = self.firstIndex(of: object) else { return }

        self.remove(at: index)
    }

    func deleting(_ object: Element) -> Array<Element> {
        var array = self
        array.delete(object)
        return array
    }

    mutating func delete(_ objects: [Element]) {
        for object in objects {
            self.delete(object)
        }
    }

    func deleting(_ objects: [Element]) -> Array<Element> {
        var array = self
        array.delete(objects)
        return array
    }
}

private extension CommandLine {

    static func parameters(forKey key: String) -> [String] {
        var inputFiles: [String] = []
        for i in 0...CommandLine.arguments.count - 1 {
            if CommandLine.arguments[i] == "-\(key)" {
                for j in (i + 1)...(CommandLine.arguments.count - i - 1) {
                    let argument = CommandLine.arguments[j]
                    if argument.first == "-" { break }
                    inputFiles.append(argument)
                }
            }
        }
        return inputFiles
    }
}

private extension Collection {

    var hasElements: Bool {
        return self.isEmpty == false
    }
}
