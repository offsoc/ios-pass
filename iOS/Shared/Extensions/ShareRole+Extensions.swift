//
// ShareRole+Extensions.swift
// Proton Pass - Created on 27/07/2023.
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

import Entities

extension ShareRole {
    var title: String {
        switch self {
        case .read:
            return "Can View"
        case .write:
            return "Can Edit"
        case .admin:
            return "Can Manage"
        }
    }

    var description: String {
        switch self {
        case .read:
            return "Can view items in this vault"
        case .write:
            return "Can create, edit, delete and export items in this vault"
        case .admin:
            return "Can grant and revoke access to this vault"
        }
    }

    var summary: String {
        switch self {
        case .read:
            return "only view items in this vault."
        case .write:
            return "create, edit, delete and export items in this vault."
        case .admin:
            return "grant and revoke access to this vault."
        }
    }
}
