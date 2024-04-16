//
// AppPreferences.swift
// Proton Pass - Created on 29/03/2024.
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

import Foundation

/// Application-wide preferences
public struct AppPreferences: Codable, Equatable, Sendable {
    /// The user is onboarded or not
    public var onboarded: Bool

    /// The time of the next telemetry event batch
    public var telemetryThreshold: TimeInterval?

    /// Number of created items from this device. Used to ask for review when appropriate.
    public var createdItemsCount: Int

    /// Keep track of dismissed banners so we don't show them again
    public var dismissedBannerIds: [String]

    // swiftlint:disable:next todo
    // TODO: Introduced in april 2024, can be removed several months later
    public var didMigratePreferences: Bool

    public init(onboarded: Bool,
                telemetryThreshold: TimeInterval?,
                createdItemsCount: Int,
                dismissedBannerIds: [String],
                didMigratePreferences: Bool) {
        self.onboarded = onboarded
        self.telemetryThreshold = telemetryThreshold
        self.createdItemsCount = createdItemsCount
        self.dismissedBannerIds = dismissedBannerIds
        self.didMigratePreferences = didMigratePreferences
    }
}

private extension AppPreferences {
    enum Default {
        static let onboarded = false
        static let telemetryThreshold: TimeInterval? = nil
        static let createdItemsCount = 0
        static let dismissedBannerIds: [String] = []
        static let didMigratePreferences = false
    }

    enum CodingKeys: String, CodingKey {
        case onboarded
        case telemetryThreshold
        case createdItemsCount
        case dismissedBannerIds
        case didMigratePreferences
    }
}

public extension AppPreferences {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let onboarded = try container.decodeIfPresent(Bool.self, forKey: .onboarded)
        let telemetryThreshold = try container.decodeIfPresent(TimeInterval.self,
                                                               forKey: .telemetryThreshold)
        let createdItemsCount = try container.decodeIfPresent(Int.self, forKey: .createdItemsCount)
        let dismissedBannerIds = try container.decodeIfPresent([String].self, forKey: .dismissedBannerIds)
        let didMigratePreferences = try container.decodeIfPresent(Bool.self,
                                                                  forKey: .didMigratePreferences)
        self.init(onboarded: onboarded ?? Default.onboarded,
                  telemetryThreshold: telemetryThreshold ?? Default.telemetryThreshold,
                  createdItemsCount: createdItemsCount ?? Default.createdItemsCount,
                  dismissedBannerIds: dismissedBannerIds ?? Default.dismissedBannerIds,
                  didMigratePreferences: didMigratePreferences ?? Default.didMigratePreferences)
    }
}

extension AppPreferences: Defaultable {
    public static var `default`: Self {
        .init(onboarded: Default.onboarded,
              telemetryThreshold: Default.telemetryThreshold,
              createdItemsCount: Default.createdItemsCount,
              dismissedBannerIds: Default.dismissedBannerIds,
              didMigratePreferences: Default.didMigratePreferences)
    }
}
