//
// ItemRepository.swift
// Proton Pass - Created on 20/09/2022.
// Copyright (c) 2022 Proton Technologies AG
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
import CoreData
import CryptoKit
import Entities
import ProtonCore_Login
import ProtonCore_Networking
import ProtonCore_Services

private let kBatchPageSize = 99

public protocol ItemRepositoryProtocol: TOTPCheckerProtocol {
    var userData: UserData { get }
    var symmetricKey: SymmetricKey { get }
    var localDatasoure: LocalItemDatasourceProtocol { get }
    var remoteDatasource: RemoteItemRevisionDatasourceProtocol { get }
    var shareEventIDRepository: ShareEventIDRepositoryProtocol { get }
    var passKeyManager: PassKeyManagerProtocol { get }
    var logger: Logger { get }

    /// Get all items (both active & trashed)
    func getAllItems() async throws -> [SymmetricallyEncryptedItem]

    /// Get all local items of all shares by state
    func getItems(state: ItemState) async throws -> [SymmetricallyEncryptedItem]

    /// Get all local items of a share by state
    func getItems(shareId: String, state: ItemState) async throws -> [SymmetricallyEncryptedItem]

    /// Get a specific Item
    func getItem(shareId: String, itemId: String) async throws -> SymmetricallyEncryptedItem?

    /// Get alias item by alias email
    func getAliasItem(email: String) async throws -> SymmetricallyEncryptedItem?

    /// Get decrypted item content
    func getItemContent(shareId: String, itemId: String) async throws -> ItemContent?

    /// Full sync for a given `shareId`
    func refreshItems(shareId: String) async throws

    @discardableResult
    func createItem(itemContent: ProtobufableItemContentProtocol,
                    shareId: String) async throws -> SymmetricallyEncryptedItem

    @discardableResult
    func createAlias(info: AliasCreationInfo,
                     itemContent: ProtobufableItemContentProtocol,
                     shareId: String) async throws -> SymmetricallyEncryptedItem

    @discardableResult
    func createAliasAndOtherItem(info: AliasCreationInfo,
                                 aliasItemContent: ProtobufableItemContentProtocol,
                                 otherItemContent: ProtobufableItemContentProtocol,
                                 shareId: String) async throws
        -> (SymmetricallyEncryptedItem, SymmetricallyEncryptedItem)

    func trashItems(_ items: [SymmetricallyEncryptedItem]) async throws

    func deleteAlias(email: String) async throws

    func untrashItems(_ items: [SymmetricallyEncryptedItem]) async throws

    func deleteItems(_ items: [SymmetricallyEncryptedItem], skipTrash: Bool) async throws

    func updateItem(oldItem: ItemRevision,
                    newItemContent: ProtobufableItemContentProtocol,
                    shareId: String) async throws

    func upsertItems(_ items: [ItemRevision], shareId: String) async throws

    @discardableResult
    func move(item: ItemIdentifiable, toShareId: String) async throws -> SymmetricallyEncryptedItem

    /// Delete all local items
    func deleteAllItemsLocally() async throws

    /// Delete items locally after sync events
    func deleteAllItemsLocally(shareId: String) async throws

    /// Delete items locally after sync events
    func deleteItemsLocally(itemIds: [String], shareId: String) async throws

    // MARK: - AutoFill operations

    /// Get active log in items of all shares
    func getActiveLogInItems() async throws -> [SymmetricallyEncryptedItem]

    /// Update the last use time of an item. Only log in items are concerned.
    func update(item: ItemIdentifiable, lastUseTime: TimeInterval) async throws
}

private extension ItemRepositoryProtocol {
    var userId: String { userData.user.ID }
}

public extension ItemRepositoryProtocol {
    func getAllItems() async throws -> [SymmetricallyEncryptedItem] {
        try await localDatasoure.getAllItems()
    }

    func getItems(state: ItemState) async throws -> [SymmetricallyEncryptedItem] {
        try await localDatasoure.getItems(state: state)
    }

    func getItems(shareId: String, state: ItemState) async throws -> [SymmetricallyEncryptedItem] {
        try await localDatasoure.getItems(shareId: shareId, state: state)
    }

    func getItem(shareId: String, itemId: String) async throws -> SymmetricallyEncryptedItem? {
        try await localDatasoure.getItem(shareId: shareId, itemId: itemId)
    }

    func getItemContent(shareId: String, itemId: String) async throws -> ItemContent? {
        let encryptedItem = try await getItem(shareId: shareId, itemId: itemId)
        return try encryptedItem?.getItemContent(symmetricKey: symmetricKey)
    }

    func getAliasItem(email: String) async throws -> SymmetricallyEncryptedItem? {
        try await localDatasoure.getAliasItem(email: email)
    }

    func refreshItems(shareId: String) async throws {
        logger.trace("Refreshing share \(shareId)")
        let itemRevisions = try await remoteDatasource.getItemRevisions(shareId: shareId)
        logger.trace("Got \(itemRevisions.count) items from remote for share \(shareId)")

        logger.trace("Encrypting \(itemRevisions.count) remote items for share \(shareId)")
        var encryptedItems = [SymmetricallyEncryptedItem]()
        for itemRevision in itemRevisions {
            let encrypedItem = try await symmetricallyEncrypt(itemRevision: itemRevision, shareId: shareId)
            encryptedItems.append(encrypedItem)
        }

        logger.trace("Removing all local old items if any for share \(shareId)")
        try await localDatasoure.removeAllItems(shareId: shareId)
        logger.trace("Removed all local old items for share \(shareId)")

        logger.trace("Saving \(itemRevisions.count) remote item revisions to local database")
        try await localDatasoure.upsertItems(encryptedItems)
        logger.trace("Saved \(encryptedItems.count) remote item revisions to local database")

        logger.trace("Refreshing last event ID for share \(shareId)")
        try await shareEventIDRepository.getLastEventId(forceRefresh: true,
                                                        userId: userData.user.ID,
                                                        shareId: shareId)
        logger.trace("Refreshed last event ID for share \(shareId)")
    }

    func createItem(itemContent: ProtobufableItemContentProtocol,
                    shareId: String) async throws -> SymmetricallyEncryptedItem {
        logger.trace("Creating item for share \(shareId)")
        let request = try await createItemRequest(itemContent: itemContent, shareId: shareId)
        let createdItemRevision = try await remoteDatasource.createItem(shareId: shareId,
                                                                        request: request)
        logger.trace("Saving newly created item \(createdItemRevision.itemID) to local database")
        let encryptedItem = try await symmetricallyEncrypt(itemRevision: createdItemRevision, shareId: shareId)
        try await localDatasoure.upsertItems([encryptedItem])
        logger.trace("Saved item \(createdItemRevision.itemID) to local database")

        return encryptedItem
    }

    func createAlias(info: AliasCreationInfo,
                     itemContent: ProtobufableItemContentProtocol,
                     shareId: String) async throws -> SymmetricallyEncryptedItem {
        logger.trace("Creating alias item")
        let createItemRequest = try await createItemRequest(itemContent: itemContent, shareId: shareId)
        let createAliasRequest = CreateCustomAliasRequest(info: info,
                                                          item: createItemRequest)
        let createdItemRevision =
            try await remoteDatasource.createAlias(shareId: shareId,
                                                   request: createAliasRequest)
        logger.trace("Saving newly created alias \(createdItemRevision.itemID) to local database")
        let encryptedItem = try await symmetricallyEncrypt(itemRevision: createdItemRevision, shareId: shareId)
        try await localDatasoure.upsertItems([encryptedItem])
        logger.trace("Saved alias \(createdItemRevision.itemID) to local database")
        return encryptedItem
    }

    func createAliasAndOtherItem(info: AliasCreationInfo,
                                 aliasItemContent: ProtobufableItemContentProtocol,
                                 otherItemContent: ProtobufableItemContentProtocol,
                                 shareId: String)
        async throws -> (SymmetricallyEncryptedItem, SymmetricallyEncryptedItem) {
        logger.trace("Creating alias and another item")
        let createAliasItemRequest = try await createItemRequest(itemContent: aliasItemContent, shareId: shareId)
        let createOtherItemRequest = try await createItemRequest(itemContent: otherItemContent, shareId: shareId)
        let request = CreateAliasAndAnotherItemRequest(info: info,
                                                       aliasItem: createAliasItemRequest,
                                                       otherItem: createOtherItemRequest)
        let bundle = try await remoteDatasource.createAliasAndAnotherItem(shareId: shareId,
                                                                          request: request)
        logger.trace("Saving newly created alias & other item to local database")
        let encryptedAlias = try await symmetricallyEncrypt(itemRevision: bundle.alias, shareId: shareId)
        let encryptedOtherItem = try await symmetricallyEncrypt(itemRevision: bundle.item, shareId: shareId)
        try await localDatasoure.upsertItems([encryptedAlias, encryptedOtherItem])
        logger.trace("Saved alias & other item to local database")
        return (encryptedAlias, encryptedOtherItem)
    }

    func trashItems(_ items: [SymmetricallyEncryptedItem]) async throws {
        let count = items.count
        logger.trace("Trashing \(count) items")

        let itemsByShareId = Dictionary(grouping: items, by: { $0.shareId })
        for shareId in itemsByShareId.keys {
            guard let encryptedItems = itemsByShareId[shareId] else { continue }
            for batch in encryptedItems.chunked(into: kBatchPageSize) {
                logger.trace("Trashing \(batch.count) items for share \(shareId)")
                let modifiedItems =
                    try await remoteDatasource.trashItemRevisions(batch.map(\.item),
                                                                  shareId: shareId)
                try await localDatasoure.upsertItems(batch,
                                                     modifiedItems: modifiedItems)
                logger.trace("Trashed \(batch.count) items for share \(shareId)")
            }
        }
    }

    func deleteAlias(email: String) async throws {
        logger.trace("Deleting alias item \(email)")
        guard let item = try await localDatasoure.getAliasItem(email: email) else {
            logger.trace("Failed to delete alias item. No alias item found for \(email)")
            return
        }
        try await deleteItems([item], skipTrash: true)
    }

    func untrashItems(_ items: [SymmetricallyEncryptedItem]) async throws {
        let count = items.count
        logger.trace("Untrashing \(count) items")

        let itemsByShareId = Dictionary(grouping: items, by: { $0.shareId })
        for shareId in itemsByShareId.keys {
            guard let encryptedItems = itemsByShareId[shareId] else { continue }
            for batch in encryptedItems.chunked(into: kBatchPageSize) {
                logger.trace("Untrashing \(batch.count) items for share \(shareId)")
                let modifiedItems =
                    try await remoteDatasource.untrashItemRevisions(batch.map(\.item),
                                                                    shareId: shareId)
                try await localDatasoure.upsertItems(batch,
                                                     modifiedItems: modifiedItems)
                logger.trace("Untrashed \(batch.count) items for share \(shareId)")
            }
        }
    }

    func deleteItems(_ items: [SymmetricallyEncryptedItem], skipTrash: Bool) async throws {
        let count = items.count
        logger.trace("Deleting \(count) items")

        let itemsByShareId = Dictionary(grouping: items, by: { $0.shareId })
        for shareId in itemsByShareId.keys {
            guard let encryptedItems = itemsByShareId[shareId] else { continue }
            for batch in encryptedItems.chunked(into: kBatchPageSize) {
                logger.trace("Deleting \(batch.count) items for share \(shareId)")
                try await remoteDatasource.deleteItemRevisions(batch.map(\.item),
                                                               shareId: shareId,
                                                               skipTrash: skipTrash)
                try await localDatasoure.deleteItems(batch)
                logger.trace("Deleted \(batch.count) items for share \(shareId)")
            }
        }
    }

    func deleteAllItemsLocally() async throws {
        logger.trace("Deleting all items locally")
        try await localDatasoure.removeAllItems()
        logger.trace("Deleted all items locally")
    }

    func deleteAllItemsLocally(shareId: String) async throws {
        logger.trace("Deleting all items locally for share \(shareId)")
        try await localDatasoure.removeAllItems(shareId: shareId)
        logger.trace("Deleted all items locally for share \(shareId)")
    }

    func deleteItemsLocally(itemIds: [String], shareId: String) async throws {
        logger.trace("Deleting locally items \(itemIds) for share \(shareId)")
        try await localDatasoure.deleteItems(itemIds: itemIds, shareId: shareId)
        logger.trace("Deleted locally items \(itemIds) for share \(shareId)")
    }

    func updateItem(oldItem: ItemRevision,
                    newItemContent: ProtobufableItemContentProtocol,
                    shareId: String) async throws {
        let itemId = oldItem.itemID
        logger.trace("Updating item \(itemId) for share \(shareId)")
        let latestItemKey = try await passKeyManager.getLatestItemKey(shareId: shareId,
                                                                      itemId: itemId)
        let request = try UpdateItemRequest(oldRevision: oldItem,
                                            latestItemKey: latestItemKey,
                                            itemContent: newItemContent)
        let updatedItemRevision =
            try await remoteDatasource.updateItem(shareId: shareId,
                                                  itemId: itemId,
                                                  request: request)
        logger.trace("Finished updating remotely item \(itemId) for share \(shareId)")
        let encryptedItem = try await symmetricallyEncrypt(itemRevision: updatedItemRevision, shareId: shareId)
        try await localDatasoure.upsertItems([encryptedItem])
        logger.trace("Finished updating locally item \(itemId) for share \(shareId)")
    }

    func upsertItems(_ items: [ItemRevision], shareId: String) async throws {
        let encryptedItems = try await items.parallelMap {
            try await symmetricallyEncrypt(itemRevision: $0, shareId: shareId)
        }
        try await localDatasoure.upsertItems(encryptedItems)
    }

    func move(item: ItemIdentifiable, toShareId: String) async throws -> SymmetricallyEncryptedItem {
        logger.trace("Moving \(item.debugInformation) to share \(toShareId)")
        guard let oldEncryptedItem = try await getItem(shareId: item.shareId, itemId: item.itemId) else {
            throw PPClientError.itemNotFound(item: item)
        }

        let oldItemContent = try oldEncryptedItem.getItemContent(symmetricKey: symmetricKey)
        let destinationShareKey = try await passKeyManager.getLatestShareKey(shareId: toShareId)
        let request = try MoveItemRequest(itemContent: oldItemContent.protobuf,
                                          destinationShareId: toShareId,
                                          destinationShareKey: destinationShareKey)
        let newItem = try await remoteDatasource.move(itemId: item.itemId,
                                                      fromShareId: item.shareId,
                                                      request: request)
        let newEncryptedItem = try await symmetricallyEncrypt(itemRevision: newItem, shareId: toShareId)
        try await localDatasoure.deleteItems([oldEncryptedItem])
        try await localDatasoure.upsertItems([newEncryptedItem])
        logger.info("Moved \(item.debugInformation) to share \(toShareId)")
        return newEncryptedItem
    }

    func getActiveLogInItems() async throws -> [SymmetricallyEncryptedItem] {
        logger.trace("Getting local active log in items for all shares")
        let logInItems = try await localDatasoure.getActiveLogInItems()
        logger.trace("Got \(logInItems.count) active log in items for all shares")
        return logInItems
    }

    func update(item: ItemIdentifiable, lastUseTime: TimeInterval) async throws {
        logger.trace("Updating lastUsedTime \(item.debugInformation)")
        let updatedItem =
            try await remoteDatasource.updateLastUseTime(shareId: item.shareId,
                                                         itemId: item.itemId,
                                                         lastUseTime: lastUseTime)
        let encryptedUpdatedItem = try await symmetricallyEncrypt(itemRevision: updatedItem,
                                                                  shareId: item.shareId)
        try await localDatasoure.upsertItems([encryptedUpdatedItem])
        logger.trace("Updated lastUsedTime \(item.debugInformation)")
    }
}

// MARK: - Private util functions

private extension ItemRepositoryProtocol {
    func symmetricallyEncrypt(itemRevision: ItemRevision,
                              shareId: String) async throws -> SymmetricallyEncryptedItem {
        let vaultKey = try await passKeyManager.getShareKey(shareId: shareId,
                                                            keyRotation: itemRevision.keyRotation)
        let contentProtobuf = try itemRevision.getContentProtobuf(vaultKey: vaultKey)
        let encryptedContent = try contentProtobuf.encrypt(symmetricKey: symmetricKey)

        let isLogInItem: Bool
        if case .login = contentProtobuf.contentData {
            isLogInItem = true
        } else {
            isLogInItem = false
        }

        return .init(shareId: shareId,
                     item: itemRevision,
                     encryptedContent: encryptedContent,
                     isLogInItem: isLogInItem)
    }

    func createItemRequest(itemContent: ProtobufableItemContentProtocol,
                           shareId: String) async throws -> CreateItemRequest {
        let latestKey = try await passKeyManager.getLatestShareKey(shareId: shareId)
        return try CreateItemRequest(vaultKey: latestKey, itemContent: itemContent)
    }
}

// MARK: - TOTPCheckerProtocol

public extension ItemRepositoryProtocol {
    func totpCreationDateThreshold(numberOfTotp: Int) async throws -> Int64? {
        let items = try await localDatasoure.getAllItems()

        let loginItemsWithTotp =
            try items
                .filter(\.isLogInItem)
                .map { try $0.getItemContent(symmetricKey: symmetricKey) }
                .filter { item in
                    switch item.contentData {
                    case let .login(loginData):
                        return !loginData.totpUri.isEmpty
                    default:
                        return false
                    }
                }
                .sorted(by: { $0.item.createTime < $1.item.createTime })

        // Number of TOTP is not reached
        if loginItemsWithTotp.count < numberOfTotp {
            return nil
        }

        return loginItemsWithTotp.prefix(numberOfTotp).last?.item.createTime
    }
}

public final class ItemRepository: ItemRepositoryProtocol {
    public let userData: UserData
    public let symmetricKey: SymmetricKey
    public let localDatasoure: LocalItemDatasourceProtocol
    public let remoteDatasource: RemoteItemRevisionDatasourceProtocol
    public let shareEventIDRepository: ShareEventIDRepositoryProtocol
    public let passKeyManager: PassKeyManagerProtocol
    public let logger: Logger

    public init(userData: UserData,
                symmetricKey: SymmetricKey,
                localDatasoure: LocalItemDatasourceProtocol,
                remoteDatasource: RemoteItemRevisionDatasourceProtocol,
                shareEventIDRepository: ShareEventIDRepositoryProtocol,
                passKeyManager: PassKeyManagerProtocol,
                logManager: LogManagerProtocol) {
        self.userData = userData
        self.symmetricKey = symmetricKey
        self.localDatasoure = localDatasoure
        self.remoteDatasource = remoteDatasource
        self.shareEventIDRepository = shareEventIDRepository
        self.passKeyManager = passKeyManager
        logger = .init(manager: logManager)
    }

    public init(userData: UserData,
                symmetricKey: SymmetricKey,
                container: NSPersistentContainer,
                apiService: APIService,
                logManager: LogManagerProtocol) {
        self.userData = userData
        self.symmetricKey = symmetricKey
        localDatasoure = LocalItemDatasource(container: container)
        remoteDatasource = RemoteItemRevisionDatasource(apiService: apiService)
        shareEventIDRepository = ShareEventIDRepository(container: container,
                                                        apiService: apiService,
                                                        logManager: logManager)
        let shareKeyRepository = ShareKeyRepository(container: container,
                                                    apiService: apiService,
                                                    logManager: logManager,
                                                    symmetricKey: symmetricKey,
                                                    userData: userData)
        let itemKeyDatasource = RemoteItemKeyDatasource(apiService: apiService)
        passKeyManager = PassKeyManager(shareKeyRepository: shareKeyRepository,
                                        itemKeyDatasource: itemKeyDatasource,
                                        logManager: logManager,
                                        symmetricKey: symmetricKey)
        logger = .init(manager: logManager)
    }
}
