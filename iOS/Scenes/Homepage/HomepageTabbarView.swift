//
// HomepageTabbarView.swift
// Proton Pass - Created on 03/04/2023.
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
import DesignSystem
import Factory
import ProtonCoreUIFoundations
import SwiftUI
import UIKit

enum HomepageTab {
    case items, profile
}

protocol HomepageTabDelegete: AnyObject {
    func homepageTabShouldChange(tab: HomepageTab)
    func homepageTabShouldRefreshTabIcons()
}

struct HomepageTabbarView: UIViewControllerRepresentable {
    let itemsTabViewModel: ItemsTabViewModel
    let profileTabViewModel: ProfileTabViewModel
    weak var homepageCoordinator: HomepageCoordinator?
    weak var delegate: HomepageTabBarControllerDelegate?

    func makeUIViewController(context: Context) -> HomepageTabBarController {
        let controller = HomepageTabBarController(itemsTabView: .init(viewModel: itemsTabViewModel),
                                                  profileTabView: .init(viewModel: profileTabViewModel))
        controller.homepageTabBarControllerDelegate = delegate
        context.coordinator.homepageTabBarController = controller
        homepageCoordinator?.homepageTabDelegete = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: HomepageTabBarController, context: Context) {}

    func makeCoordinator() -> Coordinator { .init() }

    final class Coordinator: NSObject, HomepageTabDelegete {
        var homepageTabBarController: HomepageTabBarController?

        func homepageTabShouldChange(tab: HomepageTab) {
            homepageTabBarController?.select(tab: tab)
        }

        func homepageTabShouldRefreshTabIcons() {
            homepageTabBarController?.refreshTabBarIcons()
        }
    }
}

protocol HomepageTabBarControllerDelegate: AnyObject {
    func homepageTabBarControllerDidSelectItemsTab()
    func homepageTabBarControllerWantToCreateNewItem()
    func homepageTabBarControllerDidSelectProfileTab()
}

final class HomepageTabBarController: UITabBarController, DeinitPrintable {
    deinit { print(deinitMessage) }

    private let itemsTabView: ItemsTabView
    private let profileTabView: ProfileTabView
    private var profileTabViewController: UIViewController?

    private let accessRepository = resolve(\SharedRepositoryContainer.accessRepository)
    private let logger = resolve(\SharedToolingContainer.logger)

    weak var homepageTabBarControllerDelegate: HomepageTabBarControllerDelegate?

    init(itemsTabView: ItemsTabView, profileTabView: ProfileTabView) {
        self.itemsTabView = itemsTabView
        self.profileTabView = profileTabView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if #unavailable(iOS 16) {
            // UITabBarController automatically embeds child VCs into a UINavigationController
            // Which then causes 2 navigation bars stacked on top of each other because
            // the child VCs themselves also have a navigation bar
            // Looks like this is only the behavior before iOS 16. Safe to remove once dropped iOS 15
            navigationController?.setNavigationBarHidden(true, animated: false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        let itemsTabViewController = UIHostingController(rootView: itemsTabView)
        itemsTabViewController.tabBarItem.image = IconProvider.listBullets
        itemsTabViewController.tabBarItem.accessibilityHint = "Homepage tab"

        let dummyViewController = UIViewController()
        dummyViewController.tabBarItem.image = IconProvider.plus
        dummyViewController.tabBarItem.accessibilityHint = "Create new item button"

        let profileTabViewController = UIHostingController(rootView: profileTabView)
        profileTabViewController.tabBarItem.image = IconProvider.user
        profileTabViewController.tabBarItem.accessibilityHint = "Profile tab"
        profileTabViewController.tabBarItem.accessibilityIdentifier = "HomepageTabBarController_profileTabView"
        self.profileTabViewController = profileTabViewController

        viewControllers = [itemsTabViewController, dummyViewController, profileTabViewController]

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .regular)
        tabBarAppearance.backgroundColor = PassColor.tabBarBackground
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = PassColor.textNorm
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = PassColor.interactionNormMajor2
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance

        if let taBarItems = tabBar.items {
            for item in taBarItems {
                item.title = nil
                item.imageInsets = .init(top: 8, left: 0, bottom: -8, right: 0)
            }
        }

        refreshTabBarIcons()
    }
}

// MARK: - Public APIs

extension HomepageTabBarController {
    func select(tab: HomepageTab) {
        switch tab {
        case .items:
            selectedViewController = viewControllers?.first
        case .profile:
            selectedViewController = viewControllers?.last
        }
    }

    func refreshTabBarIcons() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let plan = try await self.accessRepository.getPlan()

                let (image, selectedImage): (UIImage, UIImage) = switch plan.planType {
                case .free:
                    (IconProvider.user, IconProvider.user)
                case .plus:
                    (PassIcon.tabProfilePaidUnselected, PassIcon.tabProfilePaidSelected)
                case .trial:
                    (PassIcon.tabProfileTrialUnselected, PassIcon.tabProfileTrialSelected)
                }

                self.profileTabViewController?.tabBarItem.image = image
                self.profileTabViewController?.tabBarItem.selectedImage = selectedImage
            } catch {
                self.logger.error(error)
            }
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension HomepageTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        guard let viewControllers = tabBarController.viewControllers else { return false }
        assert(viewControllers.count == 3)

        if viewController == viewControllers[0] {
            homepageTabBarControllerDelegate?.homepageTabBarControllerDidSelectItemsTab()
            return true
        }

        if viewController == viewControllers[1] {
            homepageTabBarControllerDelegate?.homepageTabBarControllerWantToCreateNewItem()
            return false
        }

        if viewController == viewControllers[2] {
            homepageTabBarControllerDelegate?.homepageTabBarControllerDidSelectProfileTab()
            return true
        }

        return false
    }
}
