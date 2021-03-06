//
//  main.swift
//  clangParser
//
//  Created by Patrick Kladek on 19.04.17.
//  Copyright © 2017 Patrick Kladek. All rights reserved.
//

import Foundation
import Cocoa


func main() {
    let defaults = UserDefaults.standard

    switch defaults.action {
    case .help:
        LogMessage("Version \(AppInfo.version)")
        LogMessage("Usage: \(UserDefaults.Action.possibleValues)")
        exit(0)

    case .summarise:
        let action = SummariseAction(defaults: defaults)
        action.run()

    case .upload:
        let action = UploadAction(defaults: defaults)
        action.run()

    case .slack:
        let action = PostSlackAction(defaults: defaults)
        action.run()

    case .unknown:
        quit()
    }
}

main()

