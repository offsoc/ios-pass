// Generated using Sourcery 2.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// Proton Pass.
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
import Entities
import Foundation

public final class PreferencesMigratorMock: @unchecked Sendable, PreferencesMigrator {

    public init() {}

    // MARK: - migratePreferences
    public var closureMigratePreferences: () -> () = {}
    public var invokedMigratePreferencesfunction = false
    public var invokedMigratePreferencesCount = 0
    public var stubbedMigratePreferencesResult: (AppPreferences, SharedPreferences, UserPreferences)!

    public func migratePreferences() -> (AppPreferences, SharedPreferences, UserPreferences) {
        invokedMigratePreferencesfunction = true
        invokedMigratePreferencesCount += 1
        closureMigratePreferences()
        return stubbedMigratePreferencesResult
    }
}
