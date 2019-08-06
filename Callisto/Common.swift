//
//  Common.swift
//  Callisto
//
//  Created by Patrick Kladek on 12.01.18.
//  Copyright © 2018 IdeasOnCanvas. All rights reserved.
//

import Foundation
import Darwin // needed for exit()


enum ExitCodes: Int32 {
    case success = 0
    case invalidFile = -1
    case invalidBranch = -2
    case invalidGithubUsername = -3
    case invalidGithubCredentials = -4
    case invalidGithubOrganisation = -5
    case invalidGithubRepository = -6
    case invalidSlackWebhook = -7
    case internalError = -8
    case parsingFailed = -10
    case reloadBranchFailed = -11
    case jsonConversationFailed = -12
    case fastlaneFinishedWithErrors = -13
    case invalidAction = -14
    case savingFailed = -15
}

extension ExitCodes: CustomStringConvertible {

    var description: String {
        switch self {
        case .fastlaneFinishedWithErrors:
            return ""
        case .invalidFile:
            return "invalid file. Usage -fastfile \"/path/to/file\""
        case .invalidBranch:
            return "invalid Branch"
        case .invalidGithubUsername:
            return "invalid Github username. Usage: -githubUsername \"username\""
        case .invalidGithubCredentials:
            return "invalid Github credentials. Usage either: -githubToken \"token\""
        case .invalidGithubOrganisation:
            return "invalid Github Organisation. Usage -githubOrganisation \"organisation\""
        case .invalidGithubRepository:
            return "invalid Github Repository. Usage -githubRepository \"repository\""
        case .invalidSlackWebhook:
            return "invalid Slack Webhook URL. Usage -slack \"slackURL\""
        case .internalError:
            return "Unknown Error occurred. Here is the stack trace:\n\(Thread.callStackSymbols.joined(separator: "\n"))"
        case .parsingFailed:
            return "Unable to parse file"
        case .reloadBranchFailed:
            return "Failed to load Branch from Github"
        case .jsonConversationFailed:
            return "Failed to convert json"
        case .invalidAction:
            return "No action specified"
        case .savingFailed:
            return "Unable to save file"
        case .success:
            return ""
        }
    }
}

struct AppInfo {
    static let version = "1.1"
}

func time() -> String {
    return DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
}

func LogError(_ message: String) {
    print("\(time()) [\u{001B}[0;31m ERROR \u{001B}[0;0m] \(message)")
}

func LogWarning(_ message: String) {
    print("\(time()) [\u{001B}[0;33mWARNING\u{001B}[0;0m] \(message)")
}

func LogMessage(_ message: String) {
    print("\(time()) [\u{001B}[0;32mMESSAGE\u{001B}[0;0m] \(message)")
}

func quit(_ code: ExitCodes = .internalError) -> Never {
    if code != .success {
        LogError(code.description)
    }
    exit(code.rawValue)
}
