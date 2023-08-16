//
// CredentialsViewModel.swift
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

import AuthenticationServices
import Client
import Combine
import Core
import CryptoKit
import Factory
import SwiftUI

protocol CredentialsViewModelDelegate: AnyObject {
    func credentialsViewModelWantsToShowLoadingHud()
    func credentialsViewModelWantsToHideLoadingHud()
    func credentialsViewModelWantsToCancel()
    func credentialsViewModelWantsToPresentSortTypeList(selectedSortType: SortType,
                                                        delegate: SortTypeListViewModelDelegate)
    func credentialsViewModelWantsToCreateLoginItem(shareId: String, url: URL?)
    func credentialsViewModelWantsToUpgrade()
    func credentialsViewModelDidSelect(credential: ASPasswordCredential,
                                       itemContent: ItemContent,
                                       serviceIdentifiers: [ASCredentialServiceIdentifier])
    func credentialsViewModelDidFail(_ error: Error)
}

enum CredentialsViewState: Equatable {
    /// Empty search query
    case idle
    case searching
    case searchResults([ItemSearchResult])
    case loading
    case error(Error)

    static func == (lhs: CredentialsViewState, rhs: CredentialsViewState) -> Bool {
        switch (lhs, rhs) {
        case let (.error(lhsError), .error(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.idle, .idle),
             (.loading, .loading),
             (.searching, .searching),
             (.searchResults, .searchResults):
            return true
        default:
            return false
        }
    }
}

protocol TitledItemIdentifiable: ItemIdentifiable {
    var itemTitle: String { get }
}

protocol CredentialItem: DateSortable, AlphabeticalSortable, TitledItemIdentifiable, Identifiable {}

extension ItemUiModel: CredentialItem {
    var itemTitle: String { title }
}

extension ItemSearchResult: CredentialItem {
    var itemTitle: String { highlightableTitle.fullText }
}

final class CredentialsViewModel: ObservableObject, PullToRefreshable {
    @Published private(set) var state = CredentialsViewState.loading
    @Published private(set) var results: CredentialsFetchResult?
    @Published private(set) var planType: PassPlan.PlanType?
    @Published var query = ""
    @Published var notMatchedItemInformation: UnmatchedItemAlertInformation?
    @Published var isShowingConfirmationAlert = false

    @AppStorage(Constants.sortTypeKey, store: kSharedUserDefaults)

    var selectedSortType = SortType.mostRecent

    private var lastTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private let shareRepository: ShareRepositoryProtocol
    private let itemRepository: ItemRepositoryProtocol
    private let upgradeChecker: UpgradeCheckerProtocol
    private let symmetricKey: SymmetricKey
    private let serviceIdentifiers: [ASCredentialServiceIdentifier]
    private let logger = resolve(\SharedToolingContainer.logger)
    private let logManager = resolve(\SharedToolingContainer.logManager)

    let favIconRepository: FavIconRepositoryProtocol
    let urls: [URL]

    weak var delegate: CredentialsViewModelDelegate?

    /// `PullToRefreshable` conformance
    var pullToRefreshContinuation: CheckedContinuation<Void, Never>?
    let syncEventLoop: SyncEventLoop

    init(userId: String,
         shareRepository: ShareRepositoryProtocol,
         shareEventIDRepository: ShareEventIDRepositoryProtocol,
         itemRepository: ItemRepositoryProtocol,
         upgradeChecker: UpgradeCheckerProtocol,
         shareKeyRepository: ShareKeyRepositoryProtocol,
         remoteSyncEventsDatasource: RemoteSyncEventsDatasourceProtocol,
         favIconRepository: FavIconRepositoryProtocol,
         symmetricKey: SymmetricKey,
         serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        self.shareRepository = shareRepository
        self.itemRepository = itemRepository
        self.upgradeChecker = upgradeChecker
        self.favIconRepository = favIconRepository
        self.symmetricKey = symmetricKey
        self.serviceIdentifiers = serviceIdentifiers
        urls = serviceIdentifiers.compactMap { serviceIdentifier in
            // ".domain" means in app context where identifiers don't have protocol,
            // so we manually add https as protocol otherwise URL comparison would not work without protocol.
            let id = serviceIdentifier
                .type == .domain ? "https://\(serviceIdentifier.identifier)" : serviceIdentifier.identifier
            return URL(string: id)
        }

        syncEventLoop = .init(currentDateProvider: CurrentDateProvider(),
                              userId: userId,
                              shareRepository: shareRepository,
                              shareEventIDRepository: shareEventIDRepository,
                              remoteSyncEventsDatasource: remoteSyncEventsDatasource,
                              itemRepository: itemRepository,
                              shareKeyRepository: shareKeyRepository,
                              logManager: logManager)

        setup()
    }
}

// MARK: - Public actions

extension CredentialsViewModel {
    func cancel() {
        delegate?.credentialsViewModelWantsToCancel()
    }

    func fetchItems() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                self.logger.trace("Loading log in items")
                if case .error = self.state {
                    self.state = .loading
                }
                let plan = try await self.upgradeChecker.passPlanRepository.getPlan()
                self.planType = plan.planType

                self.results = try await self.fetchCredentialsTask(plan: plan).value
                self.state = .idle
                self.logger.info("Loaded log in items")
            } catch {
                self.logger.error(error)
                self.state = .error(error)
            }
        }
    }

    func presentSortTypeList() {
        delegate?.credentialsViewModelWantsToPresentSortTypeList(selectedSortType: selectedSortType,
                                                                 delegate: self)
    }

    func associateAndAutofill(item: ItemIdentifiable) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer { self.delegate?.credentialsViewModelWantsToHideLoadingHud() }
            self.delegate?.credentialsViewModelWantsToShowLoadingHud()
            do {
                self.logger.trace("Associate and autofilling \(item.debugInformation)")
                let encryptedItem = try await self.getItemTask(item: item).value
                let oldContent = try encryptedItem.getItemContent(symmetricKey: self.symmetricKey)
                guard case let .login(oldData) = oldContent.contentData else {
                    throw PPError.credentialProvider(.notLogInItem)
                }
                guard let newUrl = self.urls.first?.schemeAndHost, !newUrl.isEmpty else {
                    throw PPError.credentialProvider(.invalidURL(urls.first))
                }
                let newLoginData = ItemContentData.login(.init(username: oldData.username,
                                                               password: oldData.password,
                                                               totpUri: oldData.totpUri,
                                                               urls: oldData.urls + [newUrl]))
                let newContent = ItemContentProtobuf(name: oldContent.name,
                                                     note: oldContent.note,
                                                     itemUuid: oldContent.itemUuid,
                                                     data: newLoginData,
                                                     customFields: oldContent.customFields)
                try await self.itemRepository.updateItem(oldItem: encryptedItem.item,
                                                         newItemContent: newContent,
                                                         shareId: encryptedItem.shareId)
                self.autoFill(item: item)
                self.logger.info("Associate and autofill successfully \(item.debugInformation)")
            } catch {
                self.logger.error(error)
                self.state = .error(error)
            }
        }
    }

    func select(item: ItemIdentifiable) {
        assert(results != nil, "Credentials are not fetched")
        guard let results else { return }

        // Check if given URL is valid before proposing "associate & autofill"
        if notMatchedItemInformation == nil,
           let schemeAndHost = urls.first?.schemeAndHost,
           !schemeAndHost.isEmpty,
           let notMatchedItem = results.notMatchedItems
           .first(where: { $0.itemId == item.itemId && $0.shareId == item.shareId }) {
            notMatchedItemInformation = UnmatchedItemAlertInformation(item: notMatchedItem,
                                                                      url: schemeAndHost)
            return
        }

        // Given URL is not valid or item is matched, in either case just autofill normally
        autoFill(item: item)
    }

    func autoFill(item: ItemIdentifiable) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                self.logger.trace("Selecting \(item.debugInformation)")
                let (credential, itemContent) = try await self.getCredentialTask(for: item).value
                self.delegate?.credentialsViewModelDidSelect(credential: credential,
                                                             itemContent: itemContent,
                                                             serviceIdentifiers: self.serviceIdentifiers)
                self.logger.info("Selected \(item.debugInformation)")
            } catch {
                self.logger.error(error)
                self.state = .error(error)
            }
        }
    }

    func handleAuthenticationSuccess() {
        logger.info("Local authentication succesful")
    }

    func handleAuthenticationFailure() {
        logger.error("Failed to locally authenticate. Logging out.")
        delegate?.credentialsViewModelDidFail(PPError.credentialProvider(.failedToAuthenticate))
    }

    func createLoginItem() {
        guard case .idle = state else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let vaults = try await self.shareRepository.getVaults()
                guard let primaryVault = vaults.first(where: { $0.isPrimary }) ?? vaults.first else { return }
                self.delegate?.credentialsViewModelWantsToCreateLoginItem(shareId: primaryVault.shareId,
                                                                          url: self.urls.first)
            } catch {
                self.logger.error(error)
                self.delegate?.credentialsViewModelDidFail(error)
            }
        }
    }

    func upgrade() {
        delegate?.credentialsViewModelWantsToUpgrade()
    }
}

private extension CredentialsViewModel {
    func doSearch(term: String) {
        guard state != .searching else { return }
        guard !term.isEmpty else {
            state = .idle
            return
        }

        lastTask?.cancel()
        lastTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            let hashedTerm = term.sha256
            self.logger.trace("Searching for term \(hashedTerm)")
            self.state = .searching
            let searchResults = self.results?.searchableItems.result(for: term) ?? []
            if Task.isCancelled {
                return
            }
            self.state = .searchResults(searchResults)
            if searchResults.isEmpty {
                self.logger.trace("No results for term \(hashedTerm)")
            } else {
                self.logger.trace("Found results for term \(hashedTerm)")
            }
        }
    }
}

// MARK: Setup & utils functions

private extension CredentialsViewModel {
    func setup() {
        syncEventLoop.delegate = self
        syncEventLoop.start()
        fetchItems()

        $query
            .debounce(for: 0.4, scheduler: DispatchQueue.main)
            .removeDuplicates()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] term in
                self?.doSearch(term: term)
            }
            .store(in: &cancellables)

        $notMatchedItemInformation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isShowingConfirmationAlert = true
            }
            .store(in: &cancellables)

        $isShowingConfirmationAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                guard !showing else {
                    return
                }
                self?.notMatchedItemInformation = nil
            }
            .store(in: &cancellables)
    }
}

// MARK: - Private supporting tasks

private extension CredentialsViewModel {
    func getItemTask(item: ItemIdentifiable) -> Task<SymmetricallyEncryptedItem, Error> {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                throw PPError.CredentialProviderFailureReason.generic
            }
            guard let encryptedItem =
                try await self.itemRepository.getItem(shareId: item.shareId,
                                                      itemId: item.itemId) else {
                throw PPError.itemNotFound(shareID: item.shareId, itemID: item.itemId)
            }
            return encryptedItem
        }
    }

    func fetchCredentialsTask(plan: PassPlan) -> Task<CredentialsFetchResult, Error> {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                throw PPError.CredentialProviderFailureReason.generic
            }

            let vaults = try await self.shareRepository.getVaults()
            let encryptedItems = try await self.itemRepository.getActiveLogInItems()
            self.logger.debug("Mapping \(encryptedItems.count) encrypted items")

            let domainParser = try DomainParser()
            var searchableItems = [SearchableItem]()
            var matchedEncryptedItems = [ScoredSymmetricallyEncryptedItem]()
            var notMatchedEncryptedItems = [SymmetricallyEncryptedItem]()
            for encryptedItem in encryptedItems {
                let decryptedItemContent = try encryptedItem.getItemContent(symmetricKey: self.symmetricKey)

                let vault = vaults.first { $0.shareId == encryptedItem.shareId }
                assert(vault != nil, "Must have at least 1 vault")
                let shouldTakeIntoAccount = self.shouldTakeIntoAccount(vault: vault, withPlan: plan)

                if case let .login(data) = decryptedItemContent.contentData {
                    if shouldTakeIntoAccount {
                        try searchableItems.append(SearchableItem(from: encryptedItem,
                                                                  symmetricKey: self.symmetricKey,
                                                                  allVaults: vaults))
                    }

                    let itemUrls = data.urls.compactMap { URL(string: $0) }
                    var matchResults = [URLUtils.Matcher.MatchResult]()
                    for itemUrl in itemUrls {
                        for url in self.urls {
                            let result = URLUtils.Matcher.compare(itemUrl, url, domainParser: domainParser)
                            if case .matched = result {
                                matchResults.append(result)
                            }
                        }
                    }

                    if matchResults.isEmpty || !shouldTakeIntoAccount {
                        notMatchedEncryptedItems.append(encryptedItem)
                    } else {
                        let totalScore = matchResults.reduce(into: 0) { partialResult, next in
                            partialResult += next.score
                        }
                        matchedEncryptedItems.append(.init(item: encryptedItem,
                                                           matchScore: totalScore))
                    }
                }
            }

            let matchedItems = try await matchedEncryptedItems.sorted()
                .parallelMap { try $0.item.toItemUiModel(self.symmetricKey) }
            let notMatchedItems = try await notMatchedEncryptedItems.sorted()
                .parallelMap { try $0.toItemUiModel(self.symmetricKey) }

            self.logger.debug("Mapped \(encryptedItems.count) encrypted items.")
            self.logger.debug("\(vaults.count) vaults, \(searchableItems.count) searchable items")
            self.logger.debug("\(matchedItems.count) matched items, \(notMatchedItems.count) not matched items")
            return .init(vaults: vaults,
                         searchableItems: searchableItems,
                         matchedItems: matchedItems,
                         notMatchedItems: notMatchedItems)
        }
    }

    func getCredentialTask(for item: ItemIdentifiable) -> Task<(ASPasswordCredential, ItemContent), Error> {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                throw PPError.CredentialProviderFailureReason.generic
            }
            guard let itemContent =
                try await self.itemRepository.getItemContent(shareId: item.shareId,
                                                             itemId: item.itemId) else {
                throw PPError.itemNotFound(shareID: item.shareId, itemID: item.itemId)
            }

            switch itemContent.contentData {
            case let .login(data):
                let credential = ASPasswordCredential(user: data.username, password: data.password)
                return (credential, itemContent)
            default:
                throw PPError.credentialProvider(.notLogInItem)
            }
        }
    }

    /// When in free plan, only take primary vault into account (suggestions & search)
    /// Otherwise take everything into account
    func shouldTakeIntoAccount(vault: Vault?, withPlan plan: PassPlan) -> Bool {
        guard let vault else { return true }
        switch plan.planType {
        case .free:
            return vault.isPrimary
        default:
            return true
        }
    }
}

// MARK: - SortTypeListViewModelDelegate

extension CredentialsViewModel: SortTypeListViewModelDelegate {
    func sortTypeListViewDidSelect(_ sortType: SortType) {
        selectedSortType = sortType
    }
}

// MARK: - SyncEventLoopPullToRefreshDelegate

extension CredentialsViewModel: SyncEventLoopPullToRefreshDelegate {
    func pullToRefreshShouldStopRefreshing() {
        stopRefreshing()
    }
}

// MARK: - SyncEventLoopDelegate

extension CredentialsViewModel: SyncEventLoopDelegate {
    func syncEventLoopDidStartLooping() {
        logger.info("Started looping")
    }

    func syncEventLoopDidStopLooping() {
        logger.info("Stopped looping")
    }

    func syncEventLoopDidBeginNewLoop() {
        logger.info("Began new sync loop")
    }

    #warning("Handle no connection reason")
    func syncEventLoopDidSkipLoop(reason: SyncEventLoopSkipReason) {
        logger.info("Skipped sync loop \(reason)")
    }

    func syncEventLoopDidFinishLoop(hasNewEvents: Bool) {
        if hasNewEvents {
            logger.info("Has new events. Refreshing items")
            fetchItems()
        } else {
            logger.info("Has no new events. Do nothing.")
        }
        // We're only interested in refreshing items just once when in autofill context
        syncEventLoop.stop()
    }

    func syncEventLoopDidFailLoop(error: Error) {
        // Silently fail & not show error to users
        logger.error(error)
    }
}

extension PassPlan.PlanType {
    var searchBarPlaceholder: String {
        switch self {
        case .free:
            return "Search in primary vault"
        default:
            return "Search in all vaults"
        }
    }
}
