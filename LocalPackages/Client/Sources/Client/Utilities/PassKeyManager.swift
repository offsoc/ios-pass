//
// PassKeyManager.swift
// Proton Pass - Created on 24/02/2023.
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
import CryptoKit
import Foundation
import ProtonCoreLogin

public struct DecryptedShareKey: Hashable, Sendable {
    public let shareId: String
    public let keyRotation: Int64
    public let keyData: Data
}

public struct DecryptedItemKey: Hashable, Sendable {
    public let shareId: String
    public let itemId: String
    public let keyRotation: Int64
    public let keyData: Data
}

// sourcery: AutoMockable
public protocol PassKeyManagerProtocol: AnyObject {
    var itemKeyDatasource: RemoteItemKeyDatasourceProtocol { get }
    var shareKeyRepository: ShareKeyRepositoryProtocol { get }
    var logger: Logger { get }
    var symmetricKey: SymmetricKey { get }

    /// Get share key of a given key rotation to decrypt share content
    func getShareKey(shareId: String, keyRotation: Int64) async throws -> DecryptedShareKey

    /// Get share key with latest rotation
    func getLatestShareKey(shareId: String) async throws -> DecryptedShareKey

    /// Get the latest key of an item to encrypt item content
    func getLatestItemKey(shareId: String, itemId: String) async throws -> DecryptedItemKey
}

public actor PassKeyManager {
    public let shareKeyRepository: ShareKeyRepositoryProtocol
    public let itemKeyDatasource: RemoteItemKeyDatasourceProtocol
    public let logger: Logger
    public let symmetricKey: SymmetricKey
    private var decryptedShareKeys = Set<DecryptedShareKey>()

    public init(shareKeyRepository: ShareKeyRepositoryProtocol,
                itemKeyDatasource: RemoteItemKeyDatasourceProtocol,
                logManager: LogManagerProtocol,
                symmetricKey: SymmetricKey) {
        self.shareKeyRepository = shareKeyRepository
        self.itemKeyDatasource = itemKeyDatasource
        logger = .init(manager: logManager)
        self.symmetricKey = symmetricKey
    }
}

extension PassKeyManager: PassKeyManagerProtocol {
    public func getShareKey(shareId: String, keyRotation: Int64) async throws -> DecryptedShareKey {
        // ⚠️ Do not add logs to this function because it's supposed to be called all the time
        // when decrypting items. As IO operations caused by the log system take time
        // this will slow down dramatically the decryping process
        if let cachedKey = decryptedShareKeys.first(where: {
            $0.shareId == shareId && $0.keyRotation == keyRotation
        }) {
            return cachedKey
        }

        let allEncryptedShareKeys = try await shareKeyRepository.getKeys(shareId: shareId)
        guard let encryptedShareKey = allEncryptedShareKeys.first(where: { $0.shareId == shareId }) else {
            throw PPClientError.keysNotFound(shareID: shareId)
        }
        return try decryptAndCache(encryptedShareKey)
    }

    public func getLatestShareKey(shareId: String) async throws -> DecryptedShareKey {
        let allEncryptedShareKeys = try await shareKeyRepository.getKeys(shareId: shareId)
        let latestShareKey = try allEncryptedShareKeys.latestKey()
        return try decryptAndCache(latestShareKey)
    }

    public func getLatestItemKey(shareId: String, itemId: String) async throws -> DecryptedItemKey {
        let keyDescription = "shareId \"\(shareId)\", itemId: \"\(itemId)\""
        logger.trace("Getting latest item key \(keyDescription)")
        let latestItemKey = try await itemKeyDatasource.getLatestKey(shareId: shareId, itemId: itemId)

        logger.trace("Decrypting latest item key \(keyDescription)")

        let vaultKey = try await getShareKey(shareId: shareId, keyRotation: latestItemKey.keyRotation)

        guard let encryptedItemKeyData = try latestItemKey.key.base64Decode() else {
            logger.trace("Failed to base 64 decode latest item key \(keyDescription)")
            throw PPClientError.crypto(.failedToBase64Decode)
        }

        let decryptedItemKeyData = try AES.GCM.open(encryptedItemKeyData,
                                                    key: vaultKey.keyData,
                                                    associatedData: .itemKey)

        logger.trace("Decrypted latest item key \(keyDescription)")
        return .init(shareId: shareId,
                     itemId: itemId,
                     keyRotation: latestItemKey.keyRotation,
                     keyData: decryptedItemKeyData)
    }
}

private extension PassKeyManager {
    func decryptAndCache(_ encryptedShareKey: SymmetricallyEncryptedShareKey) throws -> DecryptedShareKey {
        let shareId = encryptedShareKey.shareId
        let keyRotation = encryptedShareKey.shareKey.keyRotation
        let keyDescription = "share id \(shareId), keyRotation: \(keyRotation)"
        logger.trace("Decrypting share key \(keyDescription)")

        let decryptedKey = try symmetricKey.decrypt(encryptedShareKey.encryptedKey)
        guard let decryptedKeyData = try decryptedKey.base64Decode() else {
            throw PPClientError.crypto(.failedToBase64Decode)
        }
        let decryptedShareKey = DecryptedShareKey(shareId: encryptedShareKey.shareId,
                                                  keyRotation: encryptedShareKey.shareKey.keyRotation,
                                                  keyData: decryptedKeyData)
        decryptedShareKeys.insert(decryptedShareKey)

        logger.info("Decrypted & cached share key share \(keyDescription)")
        return decryptedShareKey
    }
}
