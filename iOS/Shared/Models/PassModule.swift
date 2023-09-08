//
// PassModule.swift
// Proton Pass - Created on 09/07/2023.
// Copyright (c) 2023 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import Foundation

enum PassModule: String, CaseIterable {
    case hostApp, autoFillExtension, keyboardExtension
}

extension PassModule {
    var logTitle: String {
        switch self {
        case .hostApp:
            return "Application logs".localized
        case .autoFillExtension:
            return "AutoFill extension logs".localized
        case .keyboardExtension:
            return "Keyboard extension logs"
        }
    }

    var logFileName: String {
        switch self {
        case .hostApp: return "pass_host_application.log"
        case .autoFillExtension: return "pass_autofill_extension.log"
        case .keyboardExtension: return "pass_keyboard_extension.log"
        }
    }

    var exportLogFileName: String {
        let hash = Bundle.main.gitCommitHash ?? "?"
        switch self {
        case .hostApp: return "pass_host_application_\(hash).log"
        case .autoFillExtension: return "pass_autofill_extension\(hash).log"
        case .keyboardExtension: return "pass_keyboard_extension\(hash).log"
        }
    }
}
