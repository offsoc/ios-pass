//
// View+ItemContextMenus.swift
// Proton Pass - Created on 18/03/2023.
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
import ProtonCore_UIFoundations
import SwiftUI

enum ItemContextMenu {
    case login(onCopyUsername: () -> Void,
               onCopyPassword: () -> Void,
               onEdit: () -> Void,
               onTrash: () -> Void)

    case alias(onCopyAlias: () -> Void,
               onEdit: () -> Void,
               onTrash: () -> Void)

    case creditCard(onEdit: () -> Void,
                    onTrash: () -> Void)

    case note(onEdit: () -> Void,
              onTrash: () -> Void)

    case trashedItem(onRestore: () -> Void,
                     onPermanentlyDelete: () -> Void)

    var sections: [ItemContextMenuOptionSection] {
        switch self {
        case let .login(onCopyUsername, onCopyPassword, onEdit, onTrash):
            return [
                .init(options: [
                    .init(title: "Copy username".localized,
                          icon: IconProvider.user,
                          action: onCopyUsername),
                    .init(title: "Copy password".localized,
                          icon: IconProvider.key,
                          action: onCopyPassword)
                ]),
                .init(options: [.editOption(action: onEdit)]),
                .init(options: [.trashOption(action: onTrash)])
            ]

        case let .alias(onCopyAlias, onEdit, onTrash):
            return [
                .init(options: [.init(title: "Copy alias address".localized,
                                      icon: IconProvider.alias,
                                      action: onCopyAlias)]),
                .init(options: [.editOption(action: onEdit)]),
                .init(options: [.trashOption(action: onTrash)])
            ]

        case let .creditCard(onEdit, onTrash):
            return [
                .init(options: [.editOption(action: onEdit)]),
                .init(options: [.trashOption(action: onTrash)])
            ]

        case let .note(onEdit, onTrash):
            return [
                .init(options: [.editOption(action: onEdit)]),
                .init(options: [.trashOption(action: onTrash)])
            ]

        case let .trashedItem(onRestore, onPermanentlyDelete):
            return [
                .init(options: [.init(title: "Restore".localized,
                                      icon: IconProvider.clockRotateLeft,
                                      action: onRestore)]),
                .init(options: [.init(title: "Delete permanently".localized,
                                      icon: IconProvider.trashCross,
                                      action: onPermanentlyDelete,
                                      isDestructive: true)])
            ]
        }
    }
}

struct ItemContextMenuOption: Identifiable {
    var id = UUID()
    let title: String
    let icon: Image
    let action: () -> Void
    var isDestructive = false

    static func editOption(action: @escaping () -> Void) -> ItemContextMenuOption {
        .init(title: "Edit".localized, icon: IconProvider.pencil, action: action)
    }

    static func trashOption(action: @escaping () -> Void) -> ItemContextMenuOption {
        .init(title: "Move to trash".localized,
              icon: IconProvider.trash,
              action: action,
              isDestructive: true)
    }
}

struct ItemContextMenuOptionSection: Identifiable {
    var id = UUID()
    let options: [ItemContextMenuOption]
}

private extension View {
    func itemContextMenu(_ menu: ItemContextMenu) -> some View {
        contextMenu {
            ForEach(menu.sections) { section in
                Section {
                    ForEach(section.options) { option in
                        Button(role: option.isDestructive ? .destructive : nil,
                               action: option.action,
                               label: {
                                   Label(title: {
                                       Text(option.title)
                                   }, icon: {
                                       option.icon
                                   })
                               })
                    }
                }
            }
        }
    }
}

struct PermenentlyDeleteItemModifier: ViewModifier {
    @Binding var isShowingAlert: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Delete permanently?",
                   isPresented: $isShowingAlert,
                   actions: {
                       Button(role: .destructive, action: onDelete, label: { Text("Delete") })
                       Button(role: .cancel, label: { Text("Cancel") })
                   },
                   message: { Text("You are going to delete the item irreversibly, are you sure?") })
    }
}

extension View {
    func itemContextMenu(item: ItemTypeIdentifiable,
                         isTrashed: Bool,
                         onPermanentlyDelete: @escaping () -> Void,
                         handler: ItemContextMenuHandler) -> some View {
        if isTrashed {
            return itemContextMenu(.trashedItem(onRestore: { handler.restore(item) },
                                                onPermanentlyDelete: onPermanentlyDelete))
        } else {
            switch item.type {
            case .login:
                return itemContextMenu(.login(onCopyUsername: { handler.copyUsername(item) },
                                              onCopyPassword: { handler.copyPassword(item) },
                                              onEdit: { handler.edit(item) },
                                              onTrash: { handler.trash(item) }))
            case .alias:
                return itemContextMenu(.alias(onCopyAlias: { handler.copyAlias(item) },
                                              onEdit: { handler.edit(item) },
                                              onTrash: { handler.trash(item) }))

            case .creditCard:
                return itemContextMenu(.creditCard(onEdit: { handler.edit(item) },
                                                   onTrash: { handler.trash(item) }))

            case .note:
                return itemContextMenu(.note(onEdit: { handler.edit(item) },
                                             onTrash: { handler.trash(item) }))
            }
        }
    }
}
