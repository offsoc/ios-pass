//
// CredentialProviderCoordinator.swift
// Proton Pass - Created on 27/09/2022.
// Copyright (c) 2022 Proton Technologies AG
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

@preconcurrency import AuthenticationServices
import Client
import Combine
import Core
import CoreData
import CryptoKit
import DesignSystem
import Entities
import Factory
import MBProgressHUD
import ProtonCoreAuthentication
import ProtonCoreLogin
import ProtonCoreNetworking
import ProtonCoreServices
import Screens
import Sentry
import SwiftUI

@MainActor
final class CredentialProviderCoordinator: DeinitPrintable {
    deinit {
        print(deinitMessage)
    }

    /// Self-initialized properties
    private let apiManager = resolve(\SharedToolingContainer.apiManager)
    private let credentialProvider = resolve(\SharedDataContainer.credentialProvider)
    private let preferences = resolve(\SharedToolingContainer.preferences)
    private let preferencesManager = resolve(\SharedToolingContainer.preferencesManager)
    private let setUpSentry = resolve(\SharedUseCasesContainer.setUpSentry)

    private let logger = resolve(\SharedToolingContainer.logger)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private let corruptedSessionEventStream = resolve(\SharedDataStreamContainer.corruptedSessionEventStream)

    private let theme = resolve(\SharedToolingContainer.theme)
    private weak var rootViewController: UIViewController?
    private weak var context: ASCredentialProviderExtensionContext?
    private var cancellables = Set<AnyCancellable>()

    // Use cases
    private let completeConfiguration = resolve(\AutoFillUseCaseContainer.completeConfiguration)
    private let cancelAutoFill = resolve(\AutoFillUseCaseContainer.cancelAutoFill)
    private let wipeAllData = resolve(\SharedUseCasesContainer.wipeAllData)
    private let sendErrorToSentry = resolve(\SharedUseCasesContainer.sendErrorToSentry)

    // Lazily injected because some use cases are dependent on repositories
    // which are not registered when the user is not logged in
    @LazyInjected(\SharedUseCasesContainer.addTelemetryEvent) private var addTelemetryEvent
    @LazyInjected(\SharedUseCasesContainer.indexAllLoginItems) private var indexAllLoginItems
    @LazyInjected(\AutoFillUseCaseContainer.checkAndAutoFill) private var checkAndAutoFill
    @LazyInjected(\AutoFillUseCaseContainer.completeAutoFill) private var completeAutoFill
    @LazyInjected(\AutoFillUseCaseContainer.completePasskeyRegistration) private var completePasskeyRegistration
    @LazyInjected(\SharedViewContainer.bannerManager) private var bannerManager
    @LazyInjected(\SharedServiceContainer.upgradeChecker) private var upgradeChecker
    @LazyInjected(\SharedServiceContainer.vaultsManager) private var vaultsManager
    @LazyInjected(\SharedUseCasesContainer.revokeCurrentSession) private var revokeCurrentSession

    /// Derived properties
    private var lastChildViewController: UIViewController?
    private var currentCreateEditItemViewModel: BaseCreateEditItemViewModel?
    private var credentialsViewModel: CredentialsViewModel?
    private var generatePasswordCoordinator: GeneratePasswordCoordinator?
    private var customCoordinator: CustomCoordinator?

    private var topMostViewController: UIViewController? {
        rootViewController?.topMostViewController
    }

    init(rootViewController: UIViewController, context: ASCredentialProviderExtensionContext) {
        SharedViewContainer.shared.register(rootViewController: rootViewController)
        self.rootViewController = rootViewController
        self.context = context

        // Post init
        rootViewController.view.overrideUserInterfaceStyle = preferences.theme.userInterfaceStyle
        setUpSentry(bundle: .main)
        AppearanceSettings.apply()
        setUpRouting()

        apiManager.sessionWasInvalidated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionUID in
                guard let self else { return }
                logOut(error: PassError.unexpectedLogout, sessionId: sessionUID)
            }
            .store(in: &cancellables)

        corruptedSessionEventStream
            .removeDuplicates()
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reason in
                guard let self else { return }
                logOut(error: PassError.corruptedSession(reason), sessionId: reason.sessionId)
            }
            .store(in: &cancellables)
    }

    func start(mode: AutoFillMode) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await preferencesManager.setUp()
                switch mode {
                case let .showAllLogins(identifiers, requestParams):
                    handleShowAllLoginsMode(identifiers: identifiers,
                                            passkeyRequestParams: requestParams)

                case let .checkAndAutoFill(request):
                    handleCheckAndAutoFill(request)

                case let .authenticateAndAutofill(request):
                    handleAuthenticateAndAutofill(request)

                case .configuration:
                    configureExtension()

                case let .passkeyRegistration(request):
                    handlePasskeyRegistration(request)
                }
            } catch {
                handle(error: error)
            }
        }
    }
}

private extension CredentialProviderCoordinator {
    func handleShowAllLoginsMode(identifiers: [ASCredentialServiceIdentifier],
                                 passkeyRequestParams: (any PasskeyRequestParametersProtocol)?) {
        guard let context else { return }

        guard credentialProvider.isAuthenticated else {
            showNotLoggedInView()
            return
        }

        let viewModel = CredentialsViewModel(serviceIdentifiers: identifiers,
                                             passkeyRequestParams: passkeyRequestParams,
                                             context: context)
        viewModel.delegate = self
        credentialsViewModel = viewModel
        showView(CredentialsView(viewModel: viewModel))

        addNewEvent(type: .autofillDisplay)
        if passkeyRequestParams != nil {
            addNewEvent(type: .passkeyDisplay)
        }
    }

    func handleCheckAndAutoFill(_ request: AutoFillRequest) {
        Task { [weak self] in
            guard let self, let context else { return }
            do {
                try await checkAndAutoFill(request, context: context)
            } catch {
                logger.error(error)
                cancelAutoFill(reason: .failed, context: context)
            }
        }
    }

    func handleAuthenticateAndAutofill(_ request: AutoFillRequest) {
        let viewModel = LockedCredentialViewModel(request: request) { [weak self] result in
            guard let self, let context else { return }
            switch result {
            case let .success((credential, itemContent)):
                Task { [weak self] in
                    guard let self else { return }
                    try? await completeAutoFill(quickTypeBar: false,
                                                identifiers: request.serviceIdentifiers,
                                                credential: credential,
                                                itemContent: itemContent,
                                                context: context)
                }
            case let .failure(error):
                handle(error: error)
            }
        }
        showView(LockedCredentialView(preferences: preferences, viewModel: viewModel))
    }

    func handlePasskeyRegistration(_ request: PasskeyCredentialRequest) {
        guard let context else { return }
        let view = PasskeyCredentialsView(request: request,
                                          context: context,
                                          onCreate: { [weak self] in
                                              guard let self else { return }
                                              createNewLoginWithPasskey(request)
                                          },
                                          onCancel: { [weak self] in
                                              guard let self else { return }
                                              cancelAutoFill(reason: .userCanceled,
                                                             context: context)
                                          })
        showView(view)
    }

    func createNewLoginWithPasskey(_ request: PasskeyCredentialRequest) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await showCreateLoginView(url: nil, request: request)
        }
    }
}

private extension CredentialProviderCoordinator {
    func configureExtension() {
        guard let context else { return }
        guard credentialProvider.isAuthenticated else {
            showNotLoggedInView()
            return
        }

        let view = ExtensionSettingsView(onDismiss: { [weak self] in
            guard let self else { return }
            completeConfiguration(context: context)
        }, onLogOut: { [weak self] in
            guard let self else { return }
            logOut { [weak self] in
                guard let self else { return }
                completeConfiguration(context: context)
            }
        })
        showView(view)
    }
}

extension CredentialProviderCoordinator: ExtensionCoordinator {
    public func getRootViewController() -> UIViewController? {
        rootViewController
    }

    public func getLastChildViewController() -> UIViewController? {
        lastChildViewController
    }

    public func setLastChildViewController(_ viewController: UIViewController) {
        lastChildViewController = viewController
    }
}

// MARK: - Setup & Utils

private extension CredentialProviderCoordinator {
    // swiftlint:disable cyclomatic_complexity
    func setUpRouting() {
        router
            .newSheetDestination
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                guard let self else { return }
                switch destination {
                case .upgradeFlow:
                    startUpgradeFlow()
                case let .suffixView(suffixSelection):
                    createAliasLiteViewModelWantsToSelectSuffix(suffixSelection)
                case let .mailboxView(mailboxSelection, _):
                    createAliasLiteViewModelWantsToSelectMailboxes(mailboxSelection)
                case .vaultSelection:
                    createEditItemViewModelWantsToChangeVault()
                case let .createItem(item, type, response):
                    handleItemCreation(item, type: type, response: response)
                default:
                    break
                }
            }
            .store(in: &cancellables)

        router
            .globalElementDisplay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                guard let self else { return }
                switch destination {
                case let .globalLoading(shouldShow):
                    if shouldShow {
                        showLoadingHud()
                    } else {
                        hideLoadingHud()
                    }
                case let .displayErrorBanner(error):
                    bannerManager.displayTopErrorMessage(error)
                default:
                    return
                }
            }
            .store(in: &cancellables)
    }

    func handle(error: Error) {
        guard let context else { return }
        let defaultHandler: (Error) -> Void = { [weak self] error in
            guard let self else { return }
            logger.error(error)
            alert(error: error) { [weak self] in
                guard let self else { return }
                cancelAutoFill(reason: .failed, context: context)
            }
        }

        guard let error = error as? PassError,
              case let .credentialProvider(reason) = error else {
            defaultHandler(error)
            return
        }

        switch reason {
        case .userCancelled:
            cancelAutoFill(reason: .userCanceled, context: context)
            return
        case .failedToAuthenticate:
            logOut { [weak self] in
                guard let self else { return }
                cancelAutoFill(reason: .failed, context: context)
            }

        default:
            defaultHandler(error)
        }
    }

    func addNewEvent(type: TelemetryEventType) {
        addTelemetryEvent(with: type)
    }

    func logOut(error: Error? = nil,
                sessionId: String? = nil,
                completion: (() -> Void)? = nil) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                sendErrorToSentry(error, sessionId: sessionId)
            }
            await revokeCurrentSession()
            await wipeAllData()
            showNotLoggedInView()
            completion?()
        }
    }
}

// MARK: - Views for routing

private extension CredentialProviderCoordinator {
    func showNotLoggedInView() {
        guard let context else { return }
        let view = NotLoggedInView(variant: .autoFillExtension) { [weak self] in
            guard let self else { return }
            cancelAutoFill(reason: .userCanceled, context: context)
        }
        .theme(theme)
        showView(view)
    }

    func showCreateLoginView(url: URL?, request: PasskeyCredentialRequest?) async {
        do {
            showLoadingHud()
            if vaultsManager.getAllVaultContents().isEmpty {
                try await vaultsManager.asyncRefresh()
            }
            let vaults = vaultsManager.getAllVaultContents().map(\.vault)

            hideLoadingHud()
            let creationType = ItemCreationType.login(title: url?.host,
                                                      url: url?.schemeAndHost,
                                                      autofill: true,
                                                      passkeyCredentialRequest: request)
            let viewModel = try CreateEditLoginViewModel(mode: .create(shareId: vaults.oldestOwned?.shareId ?? "",
                                                                       type: creationType),
                                                         upgradeChecker: upgradeChecker,
                                                         vaults: vaults)
            viewModel.delegate = self
            viewModel.createEditLoginViewModelDelegate = self
            let view = CreateEditLoginView(viewModel: viewModel)
            present(view)
            currentCreateEditItemViewModel = viewModel
        } catch {
            logger.error(error)
            bannerManager.displayTopErrorMessage(error)
        }
    }

    func showGeneratePasswordView(delegate: GeneratePasswordViewModelDelegate) {
        let coordinator = GeneratePasswordCoordinator(generatePasswordViewModelDelegate: delegate,
                                                      mode: .createLogin)
        coordinator.delegate = self
        coordinator.start()
        generatePasswordCoordinator = coordinator
    }

    func handleCreatedItem(_ itemContentType: ItemContentType) {
        topMostViewController?.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            bannerManager.displayBottomSuccessMessage(itemContentType.creationMessage)
        }
    }

    func present(_ view: some View) {
        let viewController = UIHostingController(rootView: view)
        present(viewController)
    }

    func present(_ viewController: UIViewController, animated: Bool = true, dismissible: Bool = false) {
        viewController.isModalInPresentation = !dismissible
        viewController.overrideUserInterfaceStyle = preferences.theme.userInterfaceStyle
        topMostViewController?.present(viewController, animated: animated)
    }

    func startUpgradeFlow() {
        let alert = UIAlertController(title: "Upgrade",
                                      message: "Please open Proton Pass app to upgrade",
                                      preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okButton)
        rootViewController?.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            rootViewController?.present(alert, animated: true)
        }
    }
}

// MARK: - GeneratePasswordCoordinatorDelegate

extension CredentialProviderCoordinator: GeneratePasswordCoordinatorDelegate {
    func generatePasswordCoordinatorWantsToPresent(viewController: UIViewController) {
        present(viewController)
    }
}

// MARK: - CredentialsViewModelDelegate

extension CredentialProviderCoordinator: CredentialsViewModelDelegate {
    func credentialsViewModelWantsToCancel() {
        guard let context else { return }
        cancelAutoFill(reason: .userCanceled, context: context)
    }

    func credentialsViewModelWantsToLogOut() {
        logOut()
    }

    func credentialsViewModelWantsToPresentSortTypeList(selectedSortType: SortType,
                                                        delegate: SortTypeListViewModelDelegate) {
        guard let rootViewController else {
            return
        }
        let viewModel = SortTypeListViewModel(sortType: selectedSortType)
        viewModel.delegate = delegate
        let view = SortTypeListView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = Int(OptionRowHeight.compact.value) * SortType.allCases.count + 60
        viewController.setDetentType(.custom(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController, dismissible: true)
    }

    func credentialsViewModelWantsToCreateLoginItem(url: URL?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await showCreateLoginView(url: url, request: nil)
        }
    }
}

// MARK: - CreateEditItemViewModelDelegate

extension CredentialProviderCoordinator: CreateEditItemViewModelDelegate {
    func createEditItemViewModelWantsToChangeVault() {
        guard let rootViewController else { return }
        let viewModel = VaultSelectorViewModel()

        let view = VaultSelectorView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = 66 * vaultsManager.getVaultCount() + 180 // Space for upsell banner
        viewController.setDetentType(.customAndLarge(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController, dismissible: true)
    }

    func createEditItemViewModelWantsToAddCustomField(delegate: CustomFieldAdditionDelegate) {
        guard let rootViewController else {
            return
        }
        customCoordinator = CustomFieldAdditionCoordinator(rootViewController: rootViewController,
                                                           delegate: delegate)
        customCoordinator?.start()
    }

    func createEditItemViewModelWantsToEditCustomFieldTitle(_ uiModel: CustomFieldUiModel,
                                                            delegate: CustomFieldEditionDelegate) {
        guard let rootViewController else {
            return
        }
        customCoordinator = CustomFieldEditionCoordinator(rootViewController: rootViewController,
                                                          delegate: delegate,
                                                          uiModel: uiModel)
        customCoordinator?.start()
    }

    func handleItemCreation(_ item: SymmetricallyEncryptedItem,
                            type: ItemContentType,
                            response: CreatePasskeyResponse?) {
        switch type {
        case .login:
            Task { [weak self] in
                guard let self, let context else { return }
                do {
                    try await indexAllLoginItems(ignorePreferences: false)
                    if let response {
                        completePasskeyRegistration(response, context: context)
                    } else {
                        credentialsViewModel?.select(item: item)
                    }
                } catch {
                    logger.error(error)
                }
            }
        default:
            handleCreatedItem(type)
        }
        addNewEvent(type: .create(type))
    }
}

// MARK: - CreateEditLoginViewModelDelegate

extension CredentialProviderCoordinator: CreateEditLoginViewModelDelegate {
    func createEditLoginViewModelWantsToGenerateAlias(options: AliasOptions,
                                                      creationInfo: AliasCreationLiteInfo,
                                                      delegate: AliasCreationLiteInfoDelegate) {
        let viewModel = CreateAliasLiteViewModel(options: options, creationInfo: creationInfo)
        viewModel.aliasCreationDelegate = delegate
        let view = CreateAliasLiteView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)
        viewController.sheetPresentationController?.detents = [.medium()]
        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController, dismissible: true)
    }

    func createEditLoginViewModelWantsToGeneratePassword(_ delegate: GeneratePasswordViewModelDelegate) {
        showGeneratePasswordView(delegate: delegate)
    }
}

// MARK: - CreateAliasLiteViewModelDelegate

extension CredentialProviderCoordinator {
    func createAliasLiteViewModelWantsToSelectMailboxes(_ mailboxSelection: MailboxSelection) {
        guard let rootViewController else { return }
        let viewModel = MailboxSelectionViewModel(mailboxSelection: mailboxSelection,
                                                  mode: .createAliasLite,
                                                  titleMode: .create)
        let view = MailboxSelectionView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = Int(OptionRowHeight.compact.value) * mailboxSelection.mailboxes.count + 150
        viewController.setDetentType(.customAndLarge(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController)
    }

    func createAliasLiteViewModelWantsToSelectSuffix(_ suffixSelection: SuffixSelection) {
        guard let rootViewController else { return }
        let viewModel = SuffixSelectionViewModel(suffixSelection: suffixSelection)
        let view = SuffixSelectionView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        let customHeight = Int(OptionRowHeight.compact.value) * suffixSelection.suffixes.count + 100
        viewController.setDetentType(.customAndLarge(CGFloat(customHeight)),
                                     parentViewController: rootViewController)

        viewController.sheetPresentationController?.prefersGrabberVisible = true
        present(viewController)
    }
}

// swiftlint:enable cyclomatic_complexity
