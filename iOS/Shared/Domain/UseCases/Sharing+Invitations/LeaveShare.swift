//
//
// LeaveShare.swift
// Proton Pass - Created on 03/08/2023.
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
//

import Client

protocol LeaveShareUseCase: Sendable {
    func execute(with shareId: String) async throws
}

extension LeaveShareUseCase {
    func callAsFunction(with shareId: String) async throws {
        try await execute(with: shareId)
    }
}

final class LeaveShare: @unchecked Sendable, LeaveShareUseCase {
    private let repository: ShareRepositoryProtocol
    private let itemRepository: ItemRepositoryProtocol
    private let vaultManager: VaultsManagerProtocol

    init(repository: ShareRepositoryProtocol,
         itemRepository: ItemRepositoryProtocol,
         vaultManager: VaultsManagerProtocol) {
        self.repository = repository
        self.itemRepository = itemRepository
        self.vaultManager = vaultManager
    }

    func execute(with shareId: String) async throws {
        try await repository.deleteShare(shareId: shareId)
        try await repository.deleteShareLocally(shareId: shareId)
        try await itemRepository.deleteAllItemsLocally(shareId: shareId)
        vaultManager.refresh()
    }
}
