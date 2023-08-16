//
// DeleteVaultAlertHandler.swift
// Proton Pass - Created on 27/03/2023.
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

import Client
import Core
import UIKit

protocol DeleteVaultAlertHandlerDelegate: AnyObject {
    func confirmDelete(vault: Vault)
}

final class DeleteVaultAlertHandler: DeinitPrintable {
    deinit { print(deinitMessage) }

    private let rootViewController: UIViewController
    private let vault: Vault
    private let delegate: DeleteVaultAlertHandlerDelegate

    init(rootViewController: UIViewController,
         vault: Vault,
         delegate: DeleteVaultAlertHandlerDelegate) {
        self.rootViewController = rootViewController
        self.vault = vault
        self.delegate = delegate
    }

    func showAlert() {
        let alert = UIAlertController(title: "Delete vault?",
                                      // swiftlint:disable:next line_length
                                      message: "This will permanently delete the vault \"\(vault.name)\" and all its contents. Enter the vault name to confirm deletion.",
                                      preferredStyle: .alert)
        alert.addTextField { [vault] textField in
            textField.placeholder = "Vault name"
            let action = UIAction { [vault] _ in
                alert.actions.first?.isEnabled = textField.text == vault.name
            }
            textField.addAction(action, for: .editingChanged)
        }

        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [vault, delegate] _ in
            if alert.textFields?.first?.text == vault.name {
                delegate.confirmDelete(vault: vault)
            }
        }
        deleteAction.isEnabled = false
        alert.addAction(deleteAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)

        rootViewController.present(alert, animated: true)
    }
}
