//
//
// UserEmailView.swift
// Proton Pass - Created on 19/07/2023.
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
//

import DesignSystem
import Factory
import Macro
import ProtonCoreUIFoundations
import SwiftUI

struct UserEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UserEmailViewModel()
    private var router = resolve(\RouterContainer.mainNavViewRouter)
    @FocusState private var defaultFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 31) {
            headerView

            emailTextField

            Spacer()
        }
        .onAppear {
            if #available(iOS 16, *) {
                defaultFocus = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    defaultFocus = true
                }
            }
        }
        .animation(.default, value: viewModel.error)
        .navigate(isActive: $viewModel.goToNextStep, destination: router.navigate(to: .userSharePermission))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(kItemDetailSectionPadding)
        .navigationBarTitleDisplayMode(.inline)
        .background(PassColor.backgroundNorm.toColor)
        .toolbar { toolbarContent }
        .ignoresSafeArea(.keyboard)
        .navigationModifier()
    }
}

private extension UserEmailView {
    var headerView: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Share with")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(PassColor.textNorm.toColor)

            Text("This user will receive an invitation to join your ‘\(viewModel.vaultName)’ vault")
                .font(.body)
                .foregroundColor(PassColor.textWeak.toColor)
        }
    }
}

private extension UserEmailView {
    var emailTextField: some View {
        VStack(alignment: .leading) {
            TextField("Email address", text: $viewModel.email)
                .font(.title)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .foregroundColor(PassColor.textNorm.toColor)
                .focused($defaultFocus, equals: true)
                .accentColor(PassColor.interactionNorm.toColor)
                .tint(PassColor.interactionNorm.toColor)

            if let error = viewModel.error {
                Text(error)
                    .font(.callout)
                    .foregroundColor(PassColor.textWeak.toColor)
            }
        }
    }
}

private extension UserEmailView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            CircleButton(icon: IconProvider.cross,
                         iconColor: PassColor.interactionNormMajor2,
                         backgroundColor: PassColor.interactionNormMinor1,
                         action: dismiss.callAsFunction)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isChecking {
                ProgressView()
            } else {
                DisablableCapsuleTextButton(title: #localized("Continue"),
                                            titleColor: PassColor.textInvert,
                                            disableTitleColor: PassColor.textHint,
                                            backgroundColor: PassColor.interactionNormMajor1,
                                            disableBackgroundColor: PassColor.interactionNormMinor1,
                                            disabled: !viewModel.canContinue,
                                            action: { viewModel.saveEmail() })
            }
        }
    }
}

struct UserEmailView_Previews: PreviewProvider {
    static var previews: some View {
        UserEmailView()
    }
}
