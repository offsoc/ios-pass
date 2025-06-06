//
// GetInAppNotificationsEndpoint.swift
// Proton Pass - Created on 05/11/2024.
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

import Entities
import ProtonCoreNetworking

struct GetInAppNotificationsResponse: Decodable, Sendable, Equatable {
    let notifications: PaginatedInAppNotifications
}

struct GetInAppNotificationsEndpoint: Endpoint, @unchecked Sendable {
    typealias Body = EmptyRequest
    typealias Response = GetInAppNotificationsResponse

    var debugDescription: String
    var path: String
    var parameters: [String: Any]?

    init(lastNotificationId: String? = nil) {
        debugDescription = "Get in app notifications"
        path = "/pass/v1/notification"
        if let lastNotificationId {
            parameters = ["Since": lastNotificationId]
        }
    }
}
