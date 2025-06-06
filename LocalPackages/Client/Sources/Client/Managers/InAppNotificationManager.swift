//
// InAppNotificationManager.swift
// Proton Pass - Created on 07/11/2024.
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

import Combine
import Core
import Entities
import Foundation

public enum InAppNotificationDisplayState: Sendable {
    case inactive, active
}

public protocol InAppNotificationManagerProtocol: Sendable {
    func fetchNotifications(offsetId: String?, reset: Bool) async throws -> [InAppNotification]
    func getNotificationToDisplay() async throws -> InAppNotification?
    func updateNotificationState(notificationId: String, newState: InAppNotificationState) async throws
    func updateNotificationTime(_ date: Date) async throws
    func updateDisplayState(_ state: InAppNotificationDisplayState) async

    // MARK: - Qa only accessible function to test mock notifications

    @_spi(QA) func addMockNotification(notification: InAppNotification) async
    @_spi(QA) func removeMockNotification() async

    // periphery:ignore
    @_spi(Test) func getCurrentNofications() async -> [InAppNotification]
}

public extension InAppNotificationManagerProtocol {
    func fetchNotifications(offsetId: String? = nil, reset: Bool = true) async throws -> [InAppNotification] {
        try await fetchNotifications(offsetId: offsetId, reset: reset)
    }
}

public actor InAppNotificationManager: InAppNotificationManagerProtocol {
    private let repository: any InAppNotificationRepositoryProtocol
    private let timeDatasource: any LocalNotificationTimeDatasourceProtocol
    private let userManager: any UserManagerProtocol
    private let logger: Logger
    private var notifications: [InAppNotification] = []
    private var lastId: String?
    private var displayState: InAppNotificationDisplayState = .inactive

    private let delayBetweenNotifications: TimeInterval

    private var mockNotification: InAppNotification?

    public init(repository: any InAppNotificationRepositoryProtocol,
                timeDatasource: any LocalNotificationTimeDatasourceProtocol,
                userManager: any UserManagerProtocol,
                delayBetweenNotifications: TimeInterval = 1_800,
                logManager: any LogManagerProtocol) {
        self.repository = repository
        self.timeDatasource = timeDatasource
        self.userManager = userManager
        self.delayBetweenNotifications = delayBetweenNotifications
        logger = .init(manager: logManager)
    }
}

public extension InAppNotificationManager {
    func fetchNotifications(offsetId: String?,
                            reset: Bool) async throws -> [InAppNotification] {
        let userId = try await userManager.getActiveUserId()
        let paginatedNotifications = try await repository
            .getPaginatedNotifications(lastNotificationId: offsetId,
                                       userId: userId)
        lastId = paginatedNotifications.lastID
        if reset {
            notifications = paginatedNotifications.notifications
        } else {
            notifications.append(contentsOf: paginatedNotifications.notifications)
        }
        try await repository.removeAllNotifications(userId: userId)
        try await repository.upsertNotifications(notifications, userId: userId)
        return notifications
    }

    func getNotificationToDisplay() async throws -> InAppNotification? {
        guard displayState == .inactive else { return nil }
        let timestampDate = Date().timeIntervalSince1970

        if let mockNotification {
            return mockNotification.canBeDisplayed(timestampDate: timestampDate.toInt) ? mockNotification : nil
        }
        guard try await shouldDisplayNotification() else {
            return nil
        }
        return notifications.filter { notification in
            notification.canBeDisplayed(timestampDate: timestampDate.toInt)
        }.max(by: { lhs, rhs in
            // Priority descending
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            // StartTime ascending
            return lhs.startTime > rhs.startTime
        })
    }

    func updateNotificationState(notificationId: String, newState: InAppNotificationState) async throws {
        guard mockNotification == nil else {
            mockNotification?.state = newState.rawValue
            return
        }
        let userId = try await userManager.getActiveUserId()
        try await repository.changeNotificationStatus(notificationId: notificationId,
                                                      newStatus: newState,
                                                      userId: userId)
        if newState == .dismissed {
            try await repository.remove(notificationId: notificationId, userId: userId)
        }
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].state = newState.rawValue
        }
    }

    func updateNotificationTime(_ date: Date) async throws {
        let userId = try await userManager.getActiveUserId()
        try await timeDatasource.upsertNotificationTime(date.timeIntervalSince1970, for: userId)
    }

    func updateDisplayState(_ state: InAppNotificationDisplayState) async {
        displayState = state
    }
}

// MARK: - QA features

@_spi(QA) public extension InAppNotificationManager {
    func addMockNotification(notification: InAppNotification) async {
        mockNotification = notification
    }

    func removeMockNotification() async {
        notifications.removeAll(where: { $0.id == mockNotification?.id })
        mockNotification = nil
    }
}

@_spi(Test) public extension InAppNotificationManager {
    func getCurrentNofications() async -> [InAppNotification] {
        notifications
    }
}

private extension InAppNotificationManager {
    /// Display notification at most once every 30 minutes
    /// - Returns: A bool equals to `true` when there is more than 30 minutes past since last notification
    /// displayed
    func shouldDisplayNotification() async throws -> Bool {
        let userId = try await userManager.getActiveUserId()
        guard let timeInterval = try await timeDatasource.getNotificationTime(for: userId) else {
            return true
        }
        return (Date.now.timeIntervalSince1970 - timeInterval) >= delayBetweenNotifications
    }
}

private extension InAppNotification {
    func canBeDisplayed(timestampDate: Int) -> Bool {
        !hasBeenRead &&
            startTime <= timestampDate &&
            (endTime ?? .max) >= timestampDate
    }
}
