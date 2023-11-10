//
// AppDataTests.swift
// Proton Pass - Created on 04/11/2023.
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

@testable import Proton_Pass
import Factory
import ProtonCoreLogin
import ProtonCoreNetworking
import XCTest

final class AppDataTests: XCTestCase {
    var keychainData: [String: Data] = [:]
    var keychain: KeychainMock!
    var mainKeyProvider: MainKeyProviderMock!
    var sut: AppData!

    override func setUp() {
        super.setUp()
        keychain = KeychainMock()
        keychain.setDataStub.bodyIs { _, data, key in
            self.keychainData[key] = data
        }
        keychain.dataStub.bodyIs { _, key in
            self.keychainData[key]
        }
        keychain.removeStub.bodyIs { _, key in
            self.keychainData[key] = nil
        }

        mainKeyProvider = MainKeyProviderMock()
        mainKeyProvider.mainKeyStub.fixture = Array(repeating: .zero, count: 32)
        Scope.singleton.reset()
        SharedToolingContainer.shared.keychain.register { self.keychain }
        SharedToolingContainer.shared.mainKeyProvider.register { self.mainKeyProvider }
        sut = AppData()
    }

    override func tearDown() {
        keychain = nil
        mainKeyProvider = nil
        sut = nil
        super.tearDown()
    }
}

// MARK: - UserData
extension AppDataTests {
    func testUserDataNilByDefault() {
        XCTAssertNil(sut.getUserData())
    }

    func testUpdateUserData() throws {
        // Given
        let givenUserData = UserData.mock

        // When
        sut.setUserData(givenUserData)

        // Then
        try XCTAssertEqual(sut.getUserId(), givenUserData.user.ID)

        // When
        sut.setUserData(nil)

        // Then
        XCTAssertNil(sut.getUserData())
    }

    func testUserDataIsCached() {
        // When
        sut.setUserData(.mock)
        // Simulate multiple accesses
        for _ in 5...10 {
            _ = sut.getUserData()
        }

        // Then
        // UserData has never been updated, only read once from keychain and cache the result
        XCTAssert(keychain.dataStub.wasCalledExactlyOnce)

        // When
        sut.setUserData(.mock)
        for _ in 5...10 {
            _ = sut.getUserData()
        }

        // Then
        // UserData is updated, the cached is invalidated so reading once more time from keychain
        XCTAssertEqual(keychain.dataStub.callCounter, 2)
    }
}

// MARK: - Unauth session credentials
extension AppDataTests {
    func testUnauthSessionCredentialsNilByDefault() {
        XCTAssertNil(sut.getUnauthCredential())
    }

    func testUpdateUnauthSessionCredentials() throws {
        // Given
        let givenCredentials = AuthCredential.preview

        // When
        sut.setUnauthCredential(givenCredentials)

        // Then
        try XCTAssertEqual(sut.getUnauthCredential()?.sessionID, givenCredentials.sessionID)

        // When
        sut.setUnauthCredential(nil)

        // Then
        XCTAssertNil(sut.getUnauthCredential())
    }

    func testUnauthSessionCredentialsAreCached() {
        // When
        sut.setUnauthCredential(.preview)
        for _ in 5...10 {
            _ = sut.getUnauthCredential()
        }

        // Then
        XCTAssert(keychain.dataStub.wasCalledExactlyOnce)

        // When
        sut.setUnauthCredential(.preview)
        for _ in 5...10 {
            _ = sut.getUnauthCredential()
        }

        // Then
        XCTAssertEqual(keychain.dataStub.callCounter, 2)
    }
}

// MARK: - Symmetric key
extension AppDataTests {
    // Because we always randomize a new symmetric key when it's nil
    func testSymmetricKeyIsNeverNil() throws {
        try XCTAssertNotNil(sut.getSymmetricKey())

        // When
        sut.removeSymmetricKey()

        // Then
        try XCTAssertNotNil(sut.getSymmetricKey())
    }

    func testSymmetricKeyIsCached() throws {
        // When
        for _ in 5...10 {
            _ = try sut.getSymmetricKey()
        }

        // Then
        XCTAssert(keychain.dataStub.wasCalledExactlyOnce)

        // When
        sut.removeSymmetricKey()
        for _ in 5...10 {
            _ = try sut.getSymmetricKey()
        }

        // Then
        XCTAssertEqual(keychain.dataStub.callCounter, 2)
    }
}
