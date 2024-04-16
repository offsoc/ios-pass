//
// QAFeaturesView.swift
// Proton Pass - Created on 15/04/2023.
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

import Core
import DesignSystem
import ProtonCoreUIFoundations
import SwiftUI

struct QAFeaturesView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Constants.QA.forceDisplayUpgradeAppBanner)
    private var displayUpgradeAppBanner = false

    @AppStorage(Constants.QA.displayAuthenticator)
    private var displayAuthenticator = false

    var body: some View {
        NavigationView {
            Form {
                OnboardSection()
                HapticFeedbacksSection()
                Section {
                    CachedFavIconsSection()
                    TelemetryEventsSection()
                    TrashItemsSection()
                    BannersSection()
                    Toggle(isOn: $displayUpgradeAppBanner) {
                        Text(verbatim: "Display upgrade app banner")
                    }
                    Toggle(isOn: $displayAuthenticator) {
                        Text(verbatim: "Display Authenticator")
                    }
                }
                if #available(iOS 17, *) {
                    TipKitSection()
                }
            }
            .navigationTitle(Text(verbatim: "QA Features"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CircleButton(icon: IconProvider.cross,
                                 iconColor: PassColor.interactionNormMajor2,
                                 backgroundColor: PassColor.interactionNormMinor1,
                                 accessibilityLabel: "Close",
                                 action: dismiss.callAsFunction)
                }
            }
        }
        .tint(PassColor.interactionNorm.toColor)
        .navigationViewStyle(.stack)
    }
}
