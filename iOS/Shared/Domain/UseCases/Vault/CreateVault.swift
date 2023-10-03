//
//
// CreateVault.swift
// Proton Pass - Created on 14/09/2023.
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

protocol CreateVaultUseCase: Sendable {
    @discardableResult
    func execute(with vault: VaultProtobuf) async throws -> Share
}

extension CreateVaultUseCase {
    @discardableResult
    func callAsFunction(with vault: VaultProtobuf) async throws -> Share {
        try await execute(with: vault)
    }
}

final class CreateVault: CreateVaultUseCase {
    private let vaultsManager: VaultsManagerProtocol
    private let repository: ShareRepositoryProtocol

    init(vaultsManager: VaultsManagerProtocol,
         repository: ShareRepositoryProtocol) {
        self.vaultsManager = vaultsManager
        self.repository = repository
    }

    func execute(with vault: VaultProtobuf) async throws -> Share {
        let share = try await repository.createVault(vault)
        vaultsManager.refresh()

        return share
    }
}
