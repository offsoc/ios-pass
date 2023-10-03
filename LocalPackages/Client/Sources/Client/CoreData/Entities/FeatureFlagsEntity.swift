//
// FeatureFlagsEntity.swift
// Proton Pass - Created on 09/06/2023.
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

import CoreData

@objc(FeatureFlagsEntity)
public class FeatureFlagsEntity: NSManagedObject {}

extension FeatureFlagsEntity: Identifiable {}

extension FeatureFlagsEntity {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<FeatureFlagsEntity> {
        NSFetchRequest<FeatureFlagsEntity>(entityName: "FeatureFlagsEntity")
    }

    @NSManaged var flagsData: Data
    @NSManaged var userID: String?
}

extension FeatureFlagsEntity {
    func toFeatureFlags() -> FeatureFlags {
        let decoder = JSONDecoder()
        guard !flagsData.isEmpty else {
            return .default
        }
        guard let flags = try? decoder.decode([FeatureFlag].self, from: flagsData) else {
            assertionFailure("Should decode Featureflags.")
            return FeatureFlags.default
        }
        return FeatureFlags(flags: flags)
    }

    func hydrate(from flagsData: Data, userId: String) {
        self.flagsData = flagsData
        userID = userId
    }
}
