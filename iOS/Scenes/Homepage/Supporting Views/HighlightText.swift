//
// HighlightText.swift
// Proton Pass - Created on 13/03/2023.
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
import SwiftUI

struct HighlightText: View {
    let texts: [Text]

    init(highlightableText: HighlightableText) {
        var texts = [Text]()

        if !highlightableText.isLeadingText {
            texts.append(Text(verbatim: "..."))
        }

        if let highlightText = highlightableText.highlightText {
            let components = highlightableText.fullText.components(separatedBy: highlightText)
            for (index, eachComponent) in components.enumerated() {
                texts.append(Text(eachComponent))
                if index != components.count - 1 {
                    texts.append(Text(highlightText)
                        .foregroundColor(PassColor.interactionNormMajor2.toColor))
                }
            }
        } else {
            texts.append(Text(highlightableText.fullText))
        }

        if !highlightableText.isTrailingText {
            texts.append(Text(verbatim: "..."))
        }
        self.texts = texts
    }

    public var body: some View {
        Text(texts)
    }
}
