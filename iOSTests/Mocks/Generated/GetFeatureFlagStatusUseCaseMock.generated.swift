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
// swiftlint:disable all

@testable import UseCases
import Client
import Core
import ProtonCoreFeatureFlags

final class GetFeatureFlagStatusUseCaseMock: @unchecked Sendable, GetFeatureFlagStatusUseCase {
    // MARK: - execute
    var closureExecute: () -> () = {}
    var invokedExecute = false
    var invokedExecuteCount = 0
    var invokedExecuteParameters: (flag: any FeatureFlagTypeProtocol, Void)?
    var invokedExecuteParametersList = [(flag: any FeatureFlagTypeProtocol, Void)]()
    var stubbedExecuteResult: Bool!

    func execute(with flag: any FeatureFlagTypeProtocol) async -> Bool {
        invokedExecute = true
        invokedExecuteCount += 1
        invokedExecuteParameters = (flag, ())
        invokedExecuteParametersList.append((flag, ()))
        closureExecute()
        return stubbedExecuteResult
    }
}
