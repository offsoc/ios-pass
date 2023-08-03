//
// ShareEventIDRepository.swift
// Proton Pass - Created on 27/10/2022.
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
import ProtonCore_Networking
import ProtonCore_Services

public protocol ShareEventIDRepositoryProtocol {
    var localDatasource: LocalShareEventIDDatasourceProtocol { get }
    var remoteDatasource: RemoteShareEventIDDatasourceProtocol { get }
    var logger: Logger { get }

    /// Get local last event ID if any. If not fetch from remote and save to local database and return.
    @discardableResult
    func getLastEventId(forceRefresh: Bool, userId: String, shareId: String) async throws -> String
    func upsertLastEventId(userId: String, shareId: String, lastEventId: String) async throws
}

public extension ShareEventIDRepositoryProtocol {
    func getLastEventId(forceRefresh: Bool, userId: String, shareId: String) async throws -> String {
        if forceRefresh {
            logger.trace("Force refreshing last event id of share \(shareId) of user \(userId)")
            return try await fetchLastEventIdFromRemoteAndSaveToLocal(userId: userId, shareId: shareId)
        }
        logger.trace("Getting last event id of share \(shareId) of user \(userId)")
        if let localLastEventId =
            try await localDatasource.getLastEventId(userId: userId,
                                                     shareId: shareId) {
            logger.trace("Found local last event id of share \(shareId) of user \(userId)")
            return localLastEventId
        }
        return try await fetchLastEventIdFromRemoteAndSaveToLocal(userId: userId, shareId: shareId)
    }

    func upsertLastEventId(userId: String, shareId: String, lastEventId: String) async throws {
        try await localDatasource.upsertLastEventId(userId: userId,
                                                    shareId: shareId,
                                                    lastEventId: lastEventId)
    }
}

extension ShareEventIDRepositoryProtocol {
    func fetchLastEventIdFromRemoteAndSaveToLocal(userId: String, shareId: String) async throws -> String {
        logger.trace("Getting remote last event id of share \(shareId) of user \(userId)")
        let newLastEventId =
            try await remoteDatasource.getLastEventId(shareId: shareId)
        logger.trace("Upserting remote last event id of share \(shareId) of user \(userId)")
        try await localDatasource.upsertLastEventId(userId: userId,
                                                    shareId: shareId,
                                                    lastEventId: newLastEventId)
        return newLastEventId
    }
}

public final class ShareEventIDRepository: ShareEventIDRepositoryProtocol {
    public let localDatasource: LocalShareEventIDDatasourceProtocol
    public let remoteDatasource: RemoteShareEventIDDatasourceProtocol
    public let logger: Logger

    public init(localDatasource: LocalShareEventIDDatasourceProtocol,
                remoteDatasource: RemoteShareEventIDDatasourceProtocol,
                logManager: LogManagerProtocol) {
        self.localDatasource = localDatasource
        self.remoteDatasource = remoteDatasource
        logger = .init(manager: logManager)
    }

    public init(container: NSPersistentContainer,
                apiService: APIService,
                logManager: LogManagerProtocol) {
        localDatasource = LocalShareEventIDDatasource(container: container)
        remoteDatasource = RemoteShareEventIDDatasource(apiService: apiService)
        logger = .init(manager: logManager)
    }
}
