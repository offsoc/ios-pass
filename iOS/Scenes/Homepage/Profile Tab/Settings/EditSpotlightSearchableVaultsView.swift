//
// EditSpotlightSearchableVaultsView.swift
// Proton Pass - Created on 31/01/2024.
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

import DesignSystem
import Entities
import Factory
import SwiftUI

struct EditSpotlightSearchableVaultsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EditSpotlightSearchableVaultsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ForEach(SpotlightSearchableVaults.allCases, id: \.rawValue) { content in
                row(for: content)
                PassDivider()
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Searchable vaults")
                    .navigationTitleText()
            }
        }
        .scrollViewEmbeded(maxWidth: .infinity)
        .background(PassColor.backgroundWeak.toColor)
        .navigationStackEmbeded()
        .onChange(of: viewModel.selection) { _ in
            dismiss()
        }
    }
}

private extension EditSpotlightSearchableVaultsView {
    func row(for vaults: SpotlightSearchableVaults) -> some View {
        SelectableOptionRow(action: { viewModel.update(vaults) },
                            height: .compact,
                            content: {
                                Text(vaults.title)
                                    .foregroundColor(PassColor.textNorm.toColor)
                            },
                            isSelected: vaults == viewModel.selection)
    }
}
