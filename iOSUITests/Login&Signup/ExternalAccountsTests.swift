//
//  ExternalAccountsTests.swift
//  iOSUITests - Created on 12/23/22.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

import fusion
import ProtonCoreDoh
import ProtonCoreEnvironment
import ProtonCoreQuarkCommands
import ProtonCoreTestingToolkitUnitTestsCore
import ProtonCoreTestingToolkitUITestsLogin
import XCTest

final class ExternalAccountsTests: LoginBaseTestCase {
    let timeout = 120.0

    let welcomeRobot = WelcomeRobot()

    // Sign-in with internal account works
    // Sign-in with external account works
    // Sign-in with username account works (account is converted to internal under the hood)
    func testSignInWithInternalAccountWorks() {
        let randomUsername = StringUtils.randomAlphanumericString(length: 8)
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)
        let accountToCreate = AccountAvailableForCreation.freeWithAddressAndKeys(username: randomUsername,
                                                                                 password: randomPassword)

        guard createAccount(accountToCreate: accountToCreate, doh: doh, username: randomUsername) else { return }

        SigninExternalAccountsCapability()
            .signInWithAccount(userName: randomUsername,
                               password: randomPassword,
                               loginRobot: welcomeRobot.logIn(),
                               retRobot: AutoFillRobot.self)
            .verify.isAutoFillSetupShown(timeout: timeout)
    }

    func testSignInWithExternalAccountWorks() {
        let randomEmail = "\(StringUtils.randomAlphanumericString(length: 8))@proton.uitests"
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)
        let accountToCreate = AccountAvailableForCreation.external(email: randomEmail, password: randomPassword)

        guard createAccount(accountToCreate: accountToCreate, doh: doh, username: randomEmail) else { return }

        SigninExternalAccountsCapability()
            .signInWithAccount(userName: randomEmail,
                               password: randomPassword,
                               loginRobot: welcomeRobot.logIn(),
                               retRobot: AutoFillRobot.self)
            .verify.isAutoFillSetupShown(timeout: timeout)
    }

    func testSignInWithUsernameAccountWorks() {
        let randomUsername = StringUtils.randomAlphanumericString(length: 8)
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)
        let accountToCreate = AccountAvailableForCreation.freeNoAddressNoKeys(username: randomUsername,
                                                                              password: randomPassword)

        guard createAccount(accountToCreate: accountToCreate, doh: doh, username: randomUsername) else { return }

        SigninExternalAccountsCapability()
            .signInWithAccount(userName: randomUsername,
                               password: randomPassword,
                               loginRobot: welcomeRobot.logIn(),
                               retRobot: AutoFillRobot.self)
            .verify.isAutoFillSetupShown(timeout: timeout)
    }

    // Sign-up with internal account works
    // Sign-up with external account works
    // The UI for sign-up with username account is not available

    func testSignUpWithInternalAccountWorks() {
        let randomUsername = StringUtils.randomAlphanumericString(length: 8)
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)
        let randomEmail = "\(StringUtils.randomAlphanumericString(length: 8))@proton.uitests"

        let signupRobot = welcomeRobot
            .logIn()
            .switchToCreateAccount()
            .otherAccountButtonTap()
            .verify.otherAccountExtButtonIsShown()

        SignupExternalAccountsCapability()
            .signUpWithInternalAccount(
                signupRobot: signupRobot,
                username: randomUsername,
                password: randomPassword,
                userEmail: randomEmail,
                verificationCode: "666666",
                retRobot: AutoFillRobot.self
            ).verify.isAutoFillSetupShown(timeout: timeout)
    }

    func testSignUpWithExternalAccountIsNotAvailable() {
        let randomPassword = StringUtils.randomAlphanumericString(length: 8)
        let randomEmail = "\(StringUtils.randomAlphanumericString(length: 8))@example.com"

        let signupRobot = welcomeRobot
            .logIn()
            .switchToCreateAccount()
            .verify.otherAccountIntButtonIsShown()

        SignupExternalAccountsCapability()
            .signUpWithExternalAccount(
                signupRobot: signupRobot,
                userEmail: randomEmail,
                password: randomPassword,
                verificationCode: "666666",
                retRobot: AutoFillRobot.self
            )
            .verify.isAutoFillSetupShown(timeout: timeout)
    }

    func testSignUpWithUsernameAccountIsNotAvailable() {
        welcomeRobot.logIn()
            .switchToCreateAccount()
            .otherAccountButtonTap()
            .verify.otherAccountExtButtonIsShown()
            .verify.domainsButtonIsShown()
    }

    // MARK: - Helpers

    private func createAccount(accountToCreate: AccountAvailableForCreation,
                               doh: DoHInterface,
                               username: String) -> Bool {
        let expectQuarkCommandToFinish = expectation(description: "Quark command should finish")
        var quarkCommandResult: Result<CreatedAccountDetails, CreateAccountError>?
        QuarkCommands.create(account: accountToCreate, currentlyUsedHostUrl: doh.getCurrentlyUsedHostUrl()) { result in
            quarkCommandResult = result
            expectQuarkCommandToFinish.fulfill()
        }

        wait(for: [expectQuarkCommandToFinish], timeout: 5.0)
        if case .failure(let error) = quarkCommandResult {
            XCTFail("Internal account creation failed: \(error.userFacingMessageInQuarkCommands)")
            return false
        }
        return true

    }
}
