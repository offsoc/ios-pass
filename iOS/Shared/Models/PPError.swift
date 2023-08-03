//
// PPError.swift
// Proton Pass - Created on 08/02/2023.
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

/// Proton Pass errors
enum PPError: Error, CustomDebugStringConvertible {
    /// AutoFill extension
    case credentialProvider(CredentialProviderFailureReason)
    case deallocatedSelf
    case failedToGetOrCreateSymmetricKey
    case itemNotFound(shareID: String, itemID: String)
    case vault(VaultFailureReason)

    var debugDescription: String {
        switch self {
        case let .credentialProvider(reason):
            return reason.debugDescription
        case .deallocatedSelf:
            return "Failed to access deallocated self"
        case .failedToGetOrCreateSymmetricKey:
            return "Failed to get or create symmetric key"
        case let .itemNotFound(shareID, itemID):
            return "Item not found \"\(itemID)\" - Share ID \"\(shareID)\""
        case let .vault(reason):
            return reason.debugDescription
        }
    }
}

// MARK: - VaultFailureReason

extension PPError {
    enum VaultFailureReason: CustomDebugStringConvertible {
        case canNotDeleteLastVault
        case noSelectedVault
        case vaultNotEmpty(String)
        case vaultNotFound(String)

        var debugDescription: String {
            switch self {
            case .canNotDeleteLastVault:
                return "Can not delete last vault"
            case .noSelectedVault:
                return "No selected vault"
            case let .vaultNotEmpty(id):
                return "Vault not empty \"\(id)\""
            case let .vaultNotFound(id):
                return "Vault not found \"\(id)\""
            }
        }
    }
}

// MARK: - CredentialProviderFailureReason

extension PPError {
    enum CredentialProviderFailureReason: Error, CustomDebugStringConvertible {
        case failedToAuthenticate
        case invalidURL(URL?)
        case missingRecordIdentifier
        case notLogInItem
        case userCancelled
        case generic

        var debugDescription: String {
            switch self {
            case .failedToAuthenticate:
                return "Failed to authenticate"
            case let .invalidURL(url):
                return "Invalid URL \"\(String(describing: url?.absoluteString))\""
            case .missingRecordIdentifier:
                return "ASPasswordCredentialIdentity object missing record identifier"
            case .notLogInItem:
                return "Not log in item"
            case .userCancelled:
                return "User cancelled"
            case .generic:
                return "Something went wrong"
            }
        }
    }
}
