//
// PreferencesManagerTests.swift
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

@testable import Client
import ClientMocks
import CoreMocks
import Combine
import CryptoKit
import Entities
import XCTest

final class PreferencesManagerTest: XCTestCase {
    var currentUserIdProvider: CurrentUserIdProviderMock!
    var keychainMockProvider: KeychainProtocolMockProvider!
    var symmetricKeyProviderMockFactory: SymmetricKeyProviderMockFactory!
    var appPreferencesDatasource: LocalAppPreferencesDatasourceProtocolMock!
    var lastAppPreferences: AppPreferences!
    var sharedPreferencesDatasource: LocalSharedPreferencesDatasourceProtocol!
    var userPreferencesDatasource: LocalUserPreferencesDatasourceProtocol!
    var preferencesMigrator: PreferencesMigratorMock!
    var sut: PreferencesManagerProtocol!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        currentUserIdProvider = .init()
        currentUserIdProvider.stubbedGetCurrentUserIdResult = .random()

        keychainMockProvider = .init()
        keychainMockProvider.setUp()

        symmetricKeyProviderMockFactory = .init()
        symmetricKeyProviderMockFactory.setUp()

        appPreferencesDatasource = .init()
        appPreferencesDatasource.stubbedGetPreferencesResult = lastAppPreferences
        appPreferencesDatasource.closureUpsertPreferences = {
            if let prefs = self.appPreferencesDatasource.invokedUpsertPreferencesParameters?.0 {
                self.lastAppPreferences = prefs
            }
        }
        appPreferencesDatasource.closureRemovePreferences = {
            self.lastAppPreferences = nil
        }

        sharedPreferencesDatasource =
        LocalSharedPreferencesDatasource(symmetricKeyProvider: symmetricKeyProviderMockFactory.getProvider(),
                                         keychain: keychainMockProvider.getKeychain())

        userPreferencesDatasource =
        LocalUserPreferencesDatasource(symmetricKeyProvider: symmetricKeyProviderMockFactory.getProvider(),
                                       databaseService: DatabaseService(inMemory: true))

        preferencesMigrator = .init()
        preferencesMigrator.stubbedMigratePreferencesResult = (.default, .default, .default)

        cancellables = .init()

        sut = PreferencesManager(currentUserIdProvider: currentUserIdProvider,
                                 appPreferencesDatasource: appPreferencesDatasource,
                                 sharedPreferencesDatasource: sharedPreferencesDatasource,
                                 userPreferencesDatasource: userPreferencesDatasource, 
                                 logManager: LogManagerProtocolMock(), 
                                 preferencesMigrator: preferencesMigrator)
    }

    override func tearDown() {
        keychainMockProvider = nil
        symmetricKeyProviderMockFactory = nil
        userPreferencesDatasource = nil
        sharedPreferencesDatasource = nil
        sut = nil
        cancellables = nil
        super.tearDown()
    }
}

// MARK: - App preferences
extension PreferencesManagerTest {
    func testCreateDefaultAppPreferences() async throws {
        try await sut.setUp()
        var expectation = AppPreferences.default
        expectation.didMigratePreferences = true
        XCTAssertEqual(sut.appPreferences.value, expectation)
    }

    func testReceiveEventWhenUpdatingAppPreferences() async throws {
        // Given
        try await sut.setUp()
        let expectation = XCTestExpectation(description: "Should receive update event")
        let newValue = Int.random(in: 1...100)
        sut.appPreferencesUpdates
            .filter(\.createdItemsCount)
            .sink { value in
                if value == newValue {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        try await sut.updateAppPreferences(\.createdItemsCount, value: newValue)

        // Then
        XCTAssertEqual(sut.appPreferences.value?.createdItemsCount, newValue)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func testRemoveAppPreferences() async throws {
        try await sut.setUp()
        await sut.removeAppPreferences()
        let preferences = try appPreferencesDatasource.getPreferences()
        XCTAssertNil(preferences)
    }
}

// MARK: - Shared preferences
extension PreferencesManagerTest {
    func testCreateDefaultSharedPreferences() async throws {
        try await sut.setUp()
        XCTAssertEqual(sut.sharedPreferences.value, SharedPreferences.default)
    }

    func testReceiveEventWhenUpdatingSharedPreferences() async throws {
        // Given
        try await sut.setUp()

        let expectationAppLockTime = XCTestExpectation(description: "Should receive update event")
        let newAppLockTime = try XCTUnwrap(AppLockTime.random())
        sut.sharedPreferencesUpdates
            .filter(\.appLockTime)
            .sink { value in
                if value == newAppLockTime {
                    expectationAppLockTime.fulfill()
                }
            }
            .store(in: &cancellables)

        let expectationPinCode = XCTestExpectation(description: "Should receive update event")
        // Explicitly test nil to see if we can receive events for nullable values
        let newPinCode: String? = nil
        sut.sharedPreferencesUpdates
            .filter(\.pinCode)
            .sink { value in
                if value == newPinCode {
                    expectationPinCode.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        try await sut.updateSharedPreferences(\.appLockTime, value: newAppLockTime)
        try await sut.updateSharedPreferences(\.pinCode, value: newPinCode)

        // Then
        XCTAssertEqual(sut.sharedPreferences.value?.appLockTime, newAppLockTime)
        XCTAssertEqual(sut.sharedPreferences.value?.pinCode, newPinCode)
        await fulfillment(of: [expectationAppLockTime, expectationPinCode], timeout: 1)
    }

    func testRemoveSharedPreferences() async throws {
        try await sut.setUp()
        try await sut.removeSharedPreferences()
        let preferences = try sharedPreferencesDatasource.getPreferences()
        XCTAssertNil(preferences)
    }
}

// MARK: - User's preferences
extension PreferencesManagerTest {
    func testCreateDefaultUserPreferences() async throws {
        try await sut.setUp()
        XCTAssertEqual(sut.userPreferences.value, UserPreferences.default)
    }

    func testReceiveEventWhenUpdatingUserPreferences() async throws {
        // Given
        try await sut.setUp()
        let expectation = XCTestExpectation(description: "Should receive update event")
        let newValue = try XCTUnwrap(SpotlightSearchableContent.random())
        sut.userPreferencesUpdates
            .filter(\.spotlightSearchableContent)
            .sink { value in
                if value == newValue {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        try await sut.updateUserPreferences(\.spotlightSearchableContent, value: newValue)

        // Then
        XCTAssertEqual(sut.userPreferences.value?.spotlightSearchableContent, newValue)
        await fulfillment(of: [expectation], timeout: 1)
    }

    func testRemoveUserPreferences() async throws {
        try await sut.setUp()
        try await sut.removeUserPreferences()
        if let userId = try await currentUserIdProvider.getCurrentUserId() {
            let preferences = try await userPreferencesDatasource.getPreferences(for: userId)
            XCTAssertNil(preferences)
        }
    }
}

// MARK: Migration
extension PreferencesManagerTest {
    func testMigration() async throws {
        // Given
        var expectedAppPrefs = AppPreferences.random()
        expectedAppPrefs.didMigratePreferences = true
        let expectedSharedPrefs = SharedPreferences.random()
        let expectedUserPrefs = UserPreferences.random()
        preferencesMigrator.stubbedMigratePreferencesResult =
        (expectedAppPrefs, expectedSharedPrefs, expectedUserPrefs)

        appPreferencesDatasource.closureGetPreferences = {
            if self.preferencesMigrator.invokedMigratePreferencesfunction {
                self.appPreferencesDatasource.stubbedGetPreferencesResult = expectedAppPrefs
            }
        }

        // When
        for _ in 0..<5 {
            // Simulate different app launches
            try await sut.setUp()
        }

        // Then
        XCTAssertTrue(preferencesMigrator.invokedMigratePreferencesfunction)
        // Only migrate once
        XCTAssertEqual(preferencesMigrator.invokedMigratePreferencesCount, 1)
        XCTAssertEqual(sut.appPreferences.value, expectedAppPrefs)
        XCTAssertEqual(sut.sharedPreferences.value, expectedSharedPrefs)
        XCTAssertEqual(sut.userPreferences.value, expectedUserPrefs)
    }
}
