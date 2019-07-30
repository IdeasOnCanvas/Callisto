//
//  FastlaneParser.swift
//  clangParser
//
//  Created by Patrick Kladek on 19.04.17.
//  Copyright © 2017 Patrick Kladek. All rights reserved.
//

import Cocoa


enum ParserError: Error {
    case regularExpressionError
    case fastlaneRunError
}

class FastlaneParser {

    private let content: String
    private let ignoredKeywords: [String]
    private(set) var buildWarningMessages: [CompilerMessage] = []
    private(set) var buildErrorMessages: [CompilerMessage] = []
    private(set) var unitTestMessages: [UnitTestMessage] = []

    init(content: String, ignoredKeywords: [String]) {
        self.content = content
        self.ignoredKeywords = ignoredKeywords
    }

    convenience init?(url: URL, ignoredKeywords: [String]) {
        guard let content = try? String(contentsOf: url) else { return nil }
        self.init(content: content, ignoredKeywords: ignoredKeywords)
    }

    func parse() -> Result<Int, ParserError> {
        let trimmedContent = self.trimColors(in: self.content)
        let lines = trimmedContent.components(separatedBy: .newlines)

        self.buildErrorMessages.append(contentsOf: self.parseBuildErrors(lines))
        self.buildWarningMessages.append(contentsOf: self.parseAnalyzerWarnings(lines))
        self.unitTestMessages.append(contentsOf: self.parseUnitTestWarnings(lines))

        let exitStatus = self.parseExitStatusFromFastlane(trimmedContent)

        switch exitStatus {
        case .success(let code):
            if code == -1 {
                return self.parseExitedWithError(trimmedContent)
            } else {
                return .success(code)
            }
        case .failure:
            return exitStatus
        }
    }
}

fileprivate extension FastlaneParser {

    func parseBuildErrors(_ lines: [String]) -> [CompilerMessage] {
        let errorLines = lines.filter { self.lineIsError($0) }
        return self.compilerMessages(from: errorLines)
    }

    func parseAnalyzerWarnings(_ lines: [String]) -> [CompilerMessage] {
        let warningLines = lines.filter { self.lineIsWarning($0) }
        return self.compilerMessages(from: warningLines)
    }

    func parseUnitTestWarnings(_ lines: [String]) -> [UnitTestMessage] {
        let unitTestLines = lines.filter { self.lineIsUnitTest($0) }

        let filteredLines = Set(unitTestLines.compactMap { line -> UnitTestMessage? in
            for keyword in self.ignoredKeywords {
                guard line.lowercased().contains(keyword) == false else { return nil }
            }

            return UnitTestMessage(message: line)
        })

        return Array(filteredLines)
    }

    func parseExitStatusFromFastlane(_ content: String) -> Result<Int, ParserError> {
        guard let regex = try? NSRegularExpression(pattern: "\\[[0-9]+:[0-9]+:[0-9]+]: Exit status: [0-9]+", options: .caseInsensitive) else {
            print("Regular Expression Failed");
            return .failure(.regularExpressionError)
        }

        let exitStatusLineRange = regex.rangeOfFirstMatch(in: content, options: .reportCompletion, range: NSMakeRange(0, content.count))
        guard let exitStatusLine = content.substring(with: exitStatusLineRange) else {
            // No exit status found means we`re ok
            return .success(-1)
        }

        guard let regexStatus = try? NSRegularExpression(pattern: "\\[[0-9]+:[0-9]+:[0-9]+]: Exit status: ", options: .caseInsensitive) else {
            LogWarning("Regular Expression Failed")
            return .failure(.regularExpressionError)
        }

        let statusCodeString = regexStatus.stringByReplacingMatches(in: exitStatusLine, options: [], range: NSMakeRange(0, exitStatusLine.count), withTemplate: "")
        let statusCode = Int(statusCodeString) ?? -1
        return .success(statusCode)
    }

    func parseExitedWithError(_ content: String) -> Result<Int, ParserError> {
        if content.contains("fastlane finished with errors") {
            LogError("Fastlane finished with errors")
            return .failure(.fastlaneRunError)
        }

        return .success(-1)
    }
}

private extension FastlaneParser {

    func lineIsWarning(_ line: String) -> Bool {
        let pattern = "⚠️"
        return self.check(line: line, withRegex: pattern)
    }

    func lineIsError(_ line: String) -> Bool {
        let pattern = "❌"
        return self.check(line: line, withRegex: pattern)
    }

    func lineIsUnitTest(_ line: String) -> Bool {
        let pattern = "✗"
        return self.check(line: line, withRegex: pattern)
    }

    func trimColors(in input: String) -> String {
        var filteredString = input
        filteredString = filteredString.replacingOccurrences(of: "\r", with: "")
        filteredString = filteredString.replacingOccurrences(of: "\u{1b}", with: "")

        guard let regex = try? NSRegularExpression(pattern: "\\[[0-9]+(m|;)[0-9]*m?", options: .caseInsensitive) else { print("Regular Expression Failed"); return "" }
        let range = NSMakeRange(0, filteredString.count)
        return regex.stringByReplacingMatches(in: filteredString, options: [], range: range, withTemplate: "")
    }

    func compilerMessages(from: [String]) -> [CompilerMessage] {
        let filteredLines = Set(from.compactMap { line -> CompilerMessage? in
            for keyword in self.ignoredKeywords {
                guard line.lowercased().contains(keyword.lowercased()) == false else { return nil }
            }

            return CompilerMessage(message: line)
        })

        return Array(filteredLines)
    }

    func check(line: String, withRegex pattern: String) -> Bool {
        let regex: NSRegularExpression

        do {
            try regex = NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            print("error: could not create Regex")
            return false
        }

        let range = NSMakeRange(0, line.count)
        let matches = regex.matches(in: line, options: .reportCompletion, range: range)
        return matches.count > 0
    }
}
