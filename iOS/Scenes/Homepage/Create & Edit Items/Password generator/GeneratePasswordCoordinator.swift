//
// GeneratePasswordCoordinator.swift
// Proton Pass - Created on 09/05/2023.
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

import Core
import Macro
import SwiftUI
import UIKit

enum GeneratePasswordViewMode {
    /// View is shown as part of create login process
    case createLogin
    /// View is shown indepently without any context
    case random
}

enum PasswordType: Int, CaseIterable {
    case random = 0, memorable
}

enum WordSeparator: Int, CaseIterable {
    case hyphens = 0, spaces, periods, commas, underscores, numbers, numbersAndSymbols
}

protocol GeneratePasswordCoordinatorDelegate: AnyObject {
    func generatePasswordCoordinatorWantsToPresent(viewController: UIViewController)
}

final class GeneratePasswordCoordinator: DeinitPrintable {
    deinit { print(deinitMessage) }

    private weak var generatePasswordViewModelDelegate: GeneratePasswordViewModelDelegate?
    private let mode: GeneratePasswordViewMode
    private let wordProvider: WordProviderProtocol
    weak var delegate: GeneratePasswordCoordinatorDelegate?

    private var generatePasswordViewModel: GeneratePasswordViewModel?
    private var sheetPresentationController: UISheetPresentationController?

    init(generatePasswordViewModelDelegate: GeneratePasswordViewModelDelegate?,
         mode: GeneratePasswordViewMode,
         wordProvider: WordProviderProtocol) {
        self.generatePasswordViewModelDelegate = generatePasswordViewModelDelegate
        self.mode = mode
        self.wordProvider = wordProvider
    }

    func start() {
        guard let delegate else {
            assertionFailure("GeneratePasswordCoordinatorDelegate is not set")
            return
        }

        let viewModel = GeneratePasswordViewModel(mode: mode, wordProvider: wordProvider)
        viewModel.delegate = generatePasswordViewModelDelegate
        viewModel.uiDelegate = self
        let view = GeneratePasswordView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)
        viewController.sheetPresentationController?.prefersGrabberVisible = true

        generatePasswordViewModel = viewModel
        sheetPresentationController = viewController.sheetPresentationController
        updateSheetHeight(isShowingAdvancedOptions: viewModel.isShowingAdvancedOptions)

        delegate.generatePasswordCoordinatorWantsToPresent(viewController: viewController)
    }
}

// MARK: - Private APIs

extension GeneratePasswordCoordinator {
    func updateSheetHeight(isShowingAdvancedOptions: Bool) {
        guard let sheetPresentationController else {
            assertionFailure("sheetPresentationController is null. Coordinator is not yet started.")
            return
        }

        let detent: UISheetPresentationController.Detent
        let detentIdentifier: UISheetPresentationController.Detent.Identifier

        if #available(iOS 16, *) {
            let makeCustomDetent: (Int) -> UISheetPresentationController.Detent = { height in
                UISheetPresentationController.Detent.custom { _ in
                    CGFloat(height)
                }
            }
            detent = makeCustomDetent(isShowingAdvancedOptions ? 500 : 400)
            detentIdentifier = detent.identifier
        } else {
            if isShowingAdvancedOptions {
                detent = .large()
                detentIdentifier = .large
            } else {
                detent = .medium()
                detentIdentifier = .medium
            }
        }

        sheetPresentationController.animateChanges {
            sheetPresentationController.detents = [detent]
            sheetPresentationController.selectedDetentIdentifier = detentIdentifier
        }
    }
}

// MARK: - GeneratePasswordViewModelUiDelegate

extension GeneratePasswordCoordinator: GeneratePasswordViewModelUiDelegate {
    func generatePasswordViewModelWantsToUpdateSheetHeight(isShowingAdvancedOptions: Bool) {
        updateSheetHeight(isShowingAdvancedOptions: isShowingAdvancedOptions)
    }
}

extension GeneratePasswordViewMode {
    var confirmTitle: String {
        switch self {
        case .createLogin:
            #localized("Confirm")
        case .random:
            #localized("Copy and close")
        }
    }
}

extension PasswordType {
    var title: String {
        switch self {
        case .random:
            #localized("Random Password")
        case .memorable:
            #localized("Memorable Password")
        }
    }
}

extension WordSeparator {
    var title: String {
        switch self {
        case .hyphens:
            #localized("Hyphens")
        case .spaces:
            #localized("Spaces")
        case .periods:
            #localized("Periods")
        case .commas:
            #localized("Commas")
        case .underscores:
            #localized("Underscores")
        case .numbers:
            #localized("Numbers")
        case .numbersAndSymbols:
            #localized("Numbers and Symbols")
        }
    }

    var value: String {
        switch self {
        case .hyphens:
            return "-"
        case .spaces:
            return " "
        case .periods:
            return "."
        case .commas:
            return ","
        case .underscores:
            return "_"
        case .numbers:
            if let randomCharacter = AllowedCharacter.digit.rawValue.randomElement() {
                return String(randomCharacter)
            } else {
                assertionFailure("Something's wrong")
                return "0"
            }
        case .numbersAndSymbols:
            let allowedCharacters = AllowedCharacter.digit.rawValue + AllowedCharacter.special.rawValue
            if let randomCharacter = allowedCharacters.randomElement() {
                return String(randomCharacter)
            } else {
                assertionFailure("Something's wrong")
                return "&"
            }
        }
    }
}
