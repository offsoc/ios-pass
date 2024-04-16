//
// SettingsView.swift
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
import DesignSystem
import Entities
import Macro
import ProtonCoreUIFoundations
import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        realBody
            .if(viewModel.isShownAsSheet) { view in
                view.navigationStackEmbeded()
            }
            .theme(viewModel.selectedTheme)
    }
}

private extension SettingsView {
    var realBody: some View {
        ScrollView {
            VStack(spacing: DesignConstant.sectionPadding) {
                untitledSection
                clipboardSection
                    .padding(.vertical)
                spotlightSection
                logsSection
                applicationSection
                    .padding(.top)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
        .navigationBarBackButtonHidden()
        .navigationBarHidden(false)
        .navigationBarTitleDisplayMode(.large)
        .background(Color(uiColor: PassColor.backgroundNorm))
        .toolbar { toolbarContent }
        .animation(.default, value: viewModel.spotlightEnabled)
        .animation(.default, value: viewModel.spotlightSearchableVaults)
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            CircleButton(icon: viewModel.isShownAsSheet ? IconProvider.chevronDown : IconProvider.chevronLeft,
                         iconColor: PassColor.interactionNormMajor2,
                         backgroundColor: PassColor.interactionNormMinor1,
                         accessibilityLabel: "Go back",
                         action: { viewModel.goBack() })
        }
    }
}

private extension SettingsView {
    var untitledSection: some View {
        VStack(spacing: 0) {
            if !ProcessInfo.processInfo.isiOSAppOnMac {
                OptionRow(action: { viewModel.editDefaultBrowser() },
                          title: #localized("Default browser"),
                          height: .tall,
                          content: {
                              Text(viewModel.selectedBrowser.description)
                                  .foregroundColor(Color(uiColor: PassColor.textNorm))
                          },
                          trailing: { ChevronRight() })

                PassSectionDivider()
            }

            OptionRow(action: { viewModel.editTheme() },
                      title: #localized("Theme"),
                      height: .tall,
                      content: {
                          Label(title: {
                              Text(viewModel.selectedTheme.description)
                          }, icon: {
                              Image(uiImage: viewModel.selectedTheme.icon)
                                  .resizable()
                                  .scaledToFit()
                                  .frame(width: 14, height: 14)
                          })
                          .foregroundColor(Color(uiColor: PassColor.textNorm))
                      },
                      trailing: { ChevronRight() })

            PassSectionDivider()

            OptionRow(height: .tall) {
                StaticToggle("Show website thumbnails",
                             isOn: viewModel.displayFavIcons,
                             action: { viewModel.toggleDisplayFavIcons() })
            }
        }
        .roundedEditableSection()
    }
}

private extension SettingsView {
    var clipboardSection: some View {
        VStack(spacing: DesignConstant.sectionPadding) {
            Text("Clipboard")
                .sectionHeaderText()
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                OptionRow(action: { viewModel.editClipboardExpiration() },
                          title: #localized("Clear clipboard"),
                          height: .tall,
                          content: {
                              Text(viewModel.selectedClipboardExpiration.description)
                                  .foregroundColor(Color(uiColor: PassColor.textNorm))
                          },
                          trailing: { ChevronRight() })

                PassSectionDivider()

                OptionRow(height: .tall) {
                    StaticToggle("Share clipboard between devices",
                                 isOn: viewModel.shareClipboard,
                                 action: { viewModel.toggleShareClipboard() })
                }
            }
            .roundedEditableSection()
        }
    }
}

private extension SettingsView {
    var spotlightSection: some View {
        VStack(spacing: 0) {
            Text("Spotlight")
                .sectionHeaderText()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DesignConstant.sectionPadding)

            VStack(spacing: 0) {
                OptionRow(height: .tall) {
                    StaticToggle("Show content in search",
                                 isOn: viewModel.spotlightEnabled,
                                 action: { viewModel.toggleSpotlight() })
                }

                if viewModel.spotlightEnabled {
                    PassSectionDivider()

                    OptionRow(action: { viewModel.editSpotlightSearchableContent() },
                              height: .tall,
                              content: {
                                  VStack(alignment: .leading, spacing: DesignConstant.sectionPadding / 2) {
                                      Text("Searchable content")
                                          .sectionTitleText()

                                      Text(viewModel.spotlightSearchableContent.title)
                                          .foregroundColor(PassColor.textNorm.toColor)
                                  }
                              },
                              trailing: { ChevronRight() })

                    PassSectionDivider()

                    OptionRow(action: { viewModel.editSpotlightSearchableVaults() },
                              height: .tall,
                              content: {
                                  VStack(alignment: .leading, spacing: DesignConstant.sectionPadding / 2) {
                                      Text("Searchable vaults")
                                          .sectionTitleText()

                                      Text(viewModel.spotlightSearchableVaults.title)
                                          .foregroundColor(PassColor.textNorm.toColor)
                                  }
                              },
                              trailing: { ChevronRight() })

                    if viewModel.spotlightSearchableVaults == .selected {
                        PassSectionDivider()

                        OptionRow(action: { viewModel.editSpotlightSearchableSelectedVaults() },
                                  height: .tall,
                                  content: {
                                      VStack(alignment: .leading, spacing: DesignConstant.sectionPadding / 2) {
                                          selectedVaultsRowTitle
                                          selectedVaultsRowDescription
                                      }
                                  },
                                  trailing: { ChevronRight() })
                    }
                }
            }
            .roundedEditableSection()

            Text("Allow items to appear in Search")
                .sectionTitleText()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DesignConstant.sectionPadding / 2)
        }
    }

    @ViewBuilder
    var selectedVaultsRowTitle: some View {
        if let vaults = viewModel.spotlightVaults, !vaults.isEmpty {
            Text("Selected vaults")
                .sectionTitleText() +
                Text(verbatim: " • ")
                .sectionTitleText() +
                Text(verbatim: "(\(vaults.count))")
                .sectionTitleText()
        } else {
            Text("Selected vaults")
                .sectionTitleText()
        }
    }

    @ViewBuilder
    var selectedVaultsRowDescription: some View {
        if let vaults = viewModel.spotlightVaults {
            if vaults.isEmpty {
                Text("No vaults")
                    .foregroundStyle(PassColor.textWeak.toColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(verbatim: vaults.map(\.name).joined(separator: ", "))
                    .foregroundStyle(PassColor.textNorm.toColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }
        } else {
            Text(verbatim: "Dummy text")
                .foregroundStyle(Color.clear)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .background(SkeletonBlock()
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .clipShape(Capsule())
                    .shimmering())
        }
    }
}

private extension SettingsView {
    var logsSection: some View {
        VStack(spacing: 0) {
            Text("Logs")
                .sectionHeaderText()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DesignConstant.sectionPadding)

            VStack(spacing: 0) {
                TextOptionRow(title: PassModule.hostApp.logTitle,
                              action: { viewModel.viewHostAppLogs() })

                PassSectionDivider()

                TextOptionRow(title: PassModule.autoFillExtension.logTitle,
                              action: { viewModel.viewAutoFillExensionLogs() })
            }
            .roundedEditableSection()

            OptionRow(action: { viewModel.clearLogs() },
                      height: .medium,
                      content: {
                          Text("Clear all logs")
                              .foregroundColor(Color(uiColor: PassColor.interactionNormMajor2))
                      },
                      trailing: {
                          CircleButton(icon: IconProvider.trash,
                                       iconColor: PassColor.interactionNormMajor2,
                                       backgroundColor: PassColor.interactionNormMinor1)
                      })
                      .roundedEditableSection()
                      .padding(.top, DesignConstant.sectionPadding / 2)
        }
    }
}

private extension SettingsView {
    var applicationSection: some View {
        VStack(spacing: 0) {
            Text("Application")
                .sectionHeaderText()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DesignConstant.sectionPadding)

            OptionRow(action: { viewModel.forceSync() },
                      height: .medium,
                      content: {
                          Text("Force synchronization")
                              .foregroundColor(Color(uiColor: PassColor.interactionNormMajor2))
                      },
                      trailing: {
                          CircleButton(icon: IconProvider.arrowRotateRight,
                                       iconColor: PassColor.interactionNormMajor2,
                                       backgroundColor: PassColor.interactionNormMinor1)
                      })
                      .roundedEditableSection()

            Text("Download all your items again to make sure you are in sync")
                .sectionTitleText()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignConstant.sectionPadding / 2)
        }
    }
}
