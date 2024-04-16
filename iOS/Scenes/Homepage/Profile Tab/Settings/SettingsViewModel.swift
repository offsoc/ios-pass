//
// SettingsViewModel.swift
// Proton Pass - Created on 31/03/2023.
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
import Combine
import Core
import Entities
import Factory
import SwiftUI

@MainActor
protocol SettingsViewModelDelegate: AnyObject {
    func settingsViewModelWantsToGoBack()
    func settingsViewModelWantsToEditDefaultBrowser()
    func settingsViewModelWantsToEditTheme()
    func settingsViewModelWantsToEditClipboardExpiration()
    func settingsViewModelWantsToClearLogs()
}

@MainActor
final class SettingsViewModel: ObservableObject, DeinitPrintable {
    deinit { print(deinitMessage) }

    let isShownAsSheet: Bool
    private let favIconRepository = resolve(\SharedRepositoryContainer.favIconRepository)
    private let logger = resolve(\SharedToolingContainer.logger)
    private let preferencesManager = resolve(\SharedToolingContainer.preferencesManager)
    private let syncEventLoop = resolve(\SharedServiceContainer.syncEventLoop)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private let indexItemsForSpotlight = resolve(\SharedUseCasesContainer.indexItemsForSpotlight)
    private let currentSpotlightVaults = resolve(\DataStreamContainer.currentSpotlightSelectedVaults)
    private let getSpotlightVaults = resolve(\UseCasesContainer.getSpotlightVaults)
    private let updateSpotlightVaults = resolve(\UseCasesContainer.updateSpotlightVaults)
    private let getUserPlan = resolve(\SharedUseCasesContainer.getUserPlan)
    private let getSharedPreferences = resolve(\SharedUseCasesContainer.getSharedPreferences)
    private let updateSharedPreferences = resolve(\SharedUseCasesContainer.updateSharedPreferences)
    private let getUserPreferences = resolve(\SharedUseCasesContainer.getUserPreferences)
    private let updateUserPreferences = resolve(\SharedUseCasesContainer.updateUserPreferences)

    let vaultsManager = resolve(\SharedServiceContainer.vaultsManager)

    @Published private(set) var selectedBrowser: Browser
    @Published private(set) var selectedTheme: Theme
    @Published private(set) var selectedClipboardExpiration: ClipboardExpiration
    @Published private(set) var plan: Plan?
    @Published private(set) var displayFavIcons: Bool
    @Published private(set) var shareClipboard: Bool
    @Published private(set) var spotlightEnabled: Bool
    @Published private(set) var spotlightSearchableContent: SpotlightSearchableContent
    @Published private(set) var spotlightSearchableVaults: SpotlightSearchableVaults
    @Published private(set) var spotlightVaults: [Vault]?

    weak var delegate: SettingsViewModelDelegate?
    private var cancellables = Set<AnyCancellable>()

    init(isShownAsSheet: Bool) {
        self.isShownAsSheet = isShownAsSheet

        let sharedPreferences = getSharedPreferences()
        let userPreferences = getUserPreferences()

        selectedBrowser = sharedPreferences.browser
        selectedTheme = sharedPreferences.theme
        selectedClipboardExpiration = sharedPreferences.clipboardExpiration
        displayFavIcons = sharedPreferences.displayFavIcons
        shareClipboard = sharedPreferences.shareClipboard
        spotlightEnabled = userPreferences.spotlightEnabled
        spotlightSearchableContent = userPreferences.spotlightSearchableContent
        spotlightSearchableVaults = userPreferences.spotlightSearchableVaults

        setup()
    }
}

// MARK: - Public APIs

extension SettingsViewModel {
    func goBack() {
        delegate?.settingsViewModelWantsToGoBack()
    }

    func editDefaultBrowser() {
        delegate?.settingsViewModelWantsToEditDefaultBrowser()
    }

    func editTheme() {
        delegate?.settingsViewModelWantsToEditTheme()
    }

    func editClipboardExpiration() {
        delegate?.settingsViewModelWantsToEditClipboardExpiration()
    }

    func toggleDisplayFavIcons() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let newValue = !displayFavIcons
                try await updateSharedPreferences(\.displayFavIcons, value: newValue)
                if !newValue {
                    logger.trace("Fav icons are disabled. Removing all cached fav icons")
                    try await favIconRepository.emptyCache()
                    logger.info("Removed all cached fav icons")
                }
                displayFavIcons = newValue
            } catch {
                handle(error)
            }
        }
    }

    func toggleShareClipboard() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let newValue = !shareClipboard
                try await updateSharedPreferences(\.shareClipboard, value: newValue)
                shareClipboard = newValue
            } catch {
                handle(error)
            }
        }
    }

    func toggleSpotlight() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if !spotlightEnabled, plan?.isFreeUser == true {
                    router.present(for: .upselling(.default))
                    return
                }
                let newValue = !spotlightEnabled
                try await updateUserPreferences(\.spotlightEnabled, value: newValue)
                spotlightEnabled = newValue
                reindexItemsForSpotlight()
            } catch {
                handle(error)
            }
        }
    }

    func editSpotlightSearchableContent() {
        router.present(for: .editSpotlightSearchableContent)
    }

    func editSpotlightSearchableVaults() {
        router.present(for: .editSpotlightSearchableVaults)
    }

    func editSpotlightSearchableSelectedVaults() {
        guard spotlightVaults != nil else { return }
        router.present(for: .editSpotlightVaults)
    }

    func viewHostAppLogs() {
        router.present(for: .logView(module: .hostApp))
    }

    func viewAutoFillExensionLogs() {
        router.present(for: .logView(module: .autoFillExtension))
    }

    func clearLogs() {
        delegate?.settingsViewModelWantsToClearLogs()
    }

    func forceSync() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                router.present(for: .fullSync)
                syncEventLoop.stop()
                logger.info("Doing full sync")
                try await vaultsManager.fullSync()
                logger.info("Done full sync")
                syncEventLoop.start()
                router.display(element: .successMessage(config: .refresh))
            } catch {
                logger.error(error)
                router.display(element: .displayErrorBanner(error))
            }
        }
    }
}

// MARK: - Private APIs

private extension SettingsViewModel {
    func setup() {
        preferencesManager
            .sharedPreferencesUpdates
            .filter(\.browser)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                selectedBrowser = newValue
            }
            .store(in: &cancellables)

        preferencesManager
            .sharedPreferencesUpdates
            .filter(\.theme)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                selectedTheme = newValue
            }
            .store(in: &cancellables)

        preferencesManager
            .sharedPreferencesUpdates
            .filter(\.clipboardExpiration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                selectedClipboardExpiration = newValue
            }
            .store(in: &cancellables)

        preferencesManager
            .userPreferencesUpdates
            .filter(\.spotlightSearchableContent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                spotlightSearchableContent = newValue
            }
            .store(in: &cancellables)

        preferencesManager
            .userPreferencesUpdates
            .filter(\.spotlightSearchableVaults)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                spotlightSearchableVaults = newValue
            }
            .store(in: &cancellables)

        preferencesManager
            .userPreferencesUpdates
            .filter([\.spotlightSearchableContent, \.spotlightSearchableVaults])
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                reindexItemsForSpotlight()
            }
            .store(in: &cancellables)

        currentSpotlightVaults
            .dropFirst() // Drop first event when the stream is init
            .receive(on: DispatchQueue.main)
            // Debouncing 1.5 secs because this will trigger expensive database operations
            // and Spotlight indexation
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] vaults in
                guard let self else { return }
                spotlightVaults = vaults
                reindexItemsForSpotlight()
            }
            .store(in: &cancellables)

        getUserPlan()
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .compactMap { $0 }
            .sink { [weak self] refreshedPlan in
                guard let self else {
                    return
                }
                plan = refreshedPlan
                if refreshedPlan.isFreeUser {
                    spotlightEnabled = false
                }
            }
            .store(in: &cancellables)

        vaultsManager.attach(to: self, storeIn: &cancellables)
        refreshSpotlightVaults()
    }

    func reindexItemsForSpotlight() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let preferences = getUserPreferences()
                if preferences.spotlightEnabled {
                    if let spotlightVaults {
                        try await updateSpotlightVaults(for: spotlightVaults)
                    }
                }
                try await indexItemsForSpotlight(preferences)
            } catch {
                handle(error)
            }
        }
    }

    func refreshSpotlightVaults() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                logger.trace("Refreshing spotlight vaults")
                let vaults = try await getSpotlightVaults()
                spotlightVaults = vaults
                currentSpotlightVaults.send(vaults)
                logger.trace("Found \(spotlightVaults?.count ?? 0) spotlight vaults")
            } catch {
                handle(error)
            }
        }
    }

    func handle(_ error: Error) {
        logger.error(error)
        router.display(element: .displayErrorBanner(error))
    }
}
