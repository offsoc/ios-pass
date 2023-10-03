//
// AnimatingGradient.swift
// Proton Pass - Created on 27/12/2022.
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

import SwiftUI

public struct AnimatingGradient: View {
    @State private var animateGradient = false
    let tintColor: UIColor

    public init(tintColor: UIColor = PassColor.interactionNorm) {
        self.tintColor = tintColor
    }

    public var body: some View {
        ZStack {
            Color(tintColor.withAlphaComponent(0.08))
            LinearGradient(colors: [.clear, Color(tintColor.withAlphaComponent(0.2)), .clear],
                           startPoint: .leading,
                           endPoint: .trailing)
                .offset(x: animateGradient ? 300 : -200)
                .frame(width: 200)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: false),
                           value: animateGradient)
        }
        .onFirstAppear {
            animateGradient.toggle()
        }
    }
}
