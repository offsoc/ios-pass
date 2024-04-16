//
// UpdateUserPreferences.swift
// Proton Pass - Created on 12/04/2024.
// Copyright (c) 2024 Proton Technologies AG
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
import Entities
import Foundation

public protocol UpdateUserPreferencesUseCase: Sendable {
    func execute<T: Sendable>(_ keyPath: WritableKeyPath<UserPreferences, T>,
                              value: T) async throws
}

public extension UpdateUserPreferencesUseCase {
    func callAsFunction<T: Sendable>(_ keyPath: WritableKeyPath<UserPreferences, T>,
                                     value: T) async throws {
        try await execute(keyPath, value: value)
    }
}

public final class UpdateUserPreferences: UpdateUserPreferencesUseCase {
    private let manager: any PreferencesManagerProtocol

    public init(manager: any PreferencesManagerProtocol) {
        self.manager = manager
    }

    public func execute<T: Sendable>(_ keyPath: WritableKeyPath<UserPreferences, T>,
                                     value: T) async throws {
        try await manager.updateUserPreferences(keyPath, value: value)
    }
}
