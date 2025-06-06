//
// NotificationTimeEntity.swift
// Proton Pass - Created on 04/12/2024.
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

import CoreData

@objc(NotificationTimeEntity)
final class NotificationTimeEntity: NSManagedObject {}

extension NotificationTimeEntity: Identifiable {}

extension NotificationTimeEntity {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<NotificationTimeEntity> {
        NSFetchRequest<NotificationTimeEntity>(entityName: "NotificationTimeEntity")
    }

    @NSManaged var time: Double
    @NSManaged var userID: String
}

extension NotificationTimeEntity {
    func hydrate(userId: String, timestamp: TimeInterval) {
        time = timestamp
        userID = userId
    }
}
