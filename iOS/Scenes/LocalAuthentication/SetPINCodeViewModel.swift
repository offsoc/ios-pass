//
// SetPINCodeViewModel.swift
// Proton Pass - Created on 19/07/2023.
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

import Combine
import Core
import Factory

final class SetPINCodeViewModel: ObservableObject, DeinitPrintable {
    deinit { print(deinitMessage) }

    enum State {
        case definition, confirmation
    }

    enum ValidationError: Error {
        case notMatched
    }

    @Published private(set) var state: SetPINCodeViewModel.State = .definition
    @Published private(set) var error: ValidationError?
    @Published var definedPIN = ""
    @Published var confirmedPIN = ""

    private let preferences = resolve(\SharedToolingContainer.preferences)
    private var cancellables = Set<AnyCancellable>()
    var onSet: (String) -> Void

    var theme: Theme { preferences.theme }

    var actionNotAllowed: Bool {
        // Always disallow when error occurs
        guard error == nil else { return true }
        switch state {
        case .definition:
            return isInvalid(pin: definedPIN)
        case .confirmation:
            return isInvalid(pin: confirmedPIN)
        }
    }

    init(onSet: @escaping (String) -> Void) {
        self.onSet = onSet

        // Remove error as soon as users edit something
        Publishers
            .CombineLatest($definedPIN, $confirmedPIN)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.error = nil
            }
            .store(in: &cancellables)
    }
}

extension SetPINCodeViewModel {
    func action() {
        switch state {
        case .definition:
            state = .confirmation

        case .confirmation:
            if confirmedPIN == definedPIN {
                onSet(definedPIN)
            } else {
                error = .notMatched
            }
        }
    }
}

private extension SetPINCodeViewModel {
    func isInvalid(pin: String) -> Bool {
        let minLength = Constants.PINCode.minLength
        let maxLength = Constants.PINCode.maxLength
        return pin.isEmpty || !(minLength...maxLength).contains(pin.count)
    }
}

extension SetPINCodeViewModel.State {
    var title: String {
        switch self {
        case .definition:
            return "Set PIN code".localized
        case .confirmation:
            return "Repeat PIN code".localized
        }
    }

    var description: String {
        switch self {
        case .definition:
            return "Unlock the app with this code".localized
        case .confirmation:
            return "Type your PIN again to confirm".localized
        }
    }

    var placeholder: String {
        switch self {
        case .definition:
            return "Enter PIN code".localized
        case .confirmation:
            return "Repeat PIN code".localized
        }
    }

    var actionTitle: String {
        switch self {
        case .definition:
            return "Continue".localized
        case .confirmation:
            return "Set PIN code".localized
        }
    }
}

extension SetPINCodeViewModel.ValidationError {
    var description: String {
        switch self {
        case .notMatched:
            return "PINs not matched".localized
        }
    }
}
