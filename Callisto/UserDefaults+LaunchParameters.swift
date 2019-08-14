//
//  UserDefaults+LaunchParameters.swift
//  Callisto
//
//  Created by Patrick Kladek on 02.08.19.
//  Copyright © 2019 IdeasOnCanvas. All rights reserved.
//

import Foundation


extension UserDefaults {

    enum Action: String, CaseIterable {
        case help
        case summarize
        case upload
        case unknown

        static var possibleValues: String {
            return "[\(Action.allCases.filter { $0 != .unknown }.map { $0.rawValue }.joined(separator: "|"))]"
        }
    }

    var action: Action {
        if CommandLine.arguments.contains("-help") {
            return .help
        }

        switch CommandLine.arguments.optionalValue(at: 1) {
        case "summarize":
            return .summarize
        case "upload":
            return .upload
        default:
            LogError("No action specified. Possible values are: \(Action.possibleValues)")
            exit(ExitCodes.invalidAction.rawValue)
        }
    }

    var fastlaneOutputURL: URL {
        return self.url(forKey: "fastlane") ?? { quit(.invalidFastlaneFile) }()
    }

    var branch: String {
        return self.string(forKey: "branch") ?? { quit(.invalidBranch) }()
    }

    var githubAccount: GithubAccount {
        let username = self.string(forKey: "githubUsername") ?? { quit(.invalidGithubUsername) }()
        let token = self.string(forKey: "githubToken") ?? { quit(.invalidGithubCredentials) }()
        return GithubAccount(username: username, token: token)
    }

    var githubRepository: GithubRepository {
        let organisation = self.string(forKey: "githubOrganisation") ?? { quit(.invalidGithubOrganisation) }()
        let repository = self.string(forKey: "githubRepository") ?? { quit(.invalidGithubRepository) }()
        return GithubRepository(organisation: organisation, repository: repository)
    }

    var slackURL: URL {
        let slackPath = self.string(forKey: "slack") ?? { quit(.invalidSlackWebhook) }()
        return URL(string: slackPath) ?? { quit(.invalidSlackWebhook) }()
    }

    var ignoredKeywords: [String] {
        return self.string(forKey: "ignore")?.components(separatedBy: ", ") ?? []
    }
}

private extension Array {

    func optionalValue(at index: Int) -> Element? {
        if self.count - 1 < index {
            return nil
        }

        return self[index]
    }
}