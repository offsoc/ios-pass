//
// FormatFileAttachmentSize.swift
// Proton Pass - Created on 27/11/2024.
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
//

import Core
import Foundation

public protocol FormatFileAttachmentSizeUseCase: Sendable {
    func execute(_ size: any BinaryInteger) -> String?
}

public extension FormatFileAttachmentSizeUseCase {
    func callAsFunction(_ size: any BinaryInteger) -> String? {
        execute(size)
    }
}

public final class FormatFileAttachmentSize: @unchecked Sendable, FormatFileAttachmentSizeUseCase {
    private let formatter: ByteCountFormatter

    public init(formatter: ByteCountFormatter = Constants.Attachment.formatter) {
        self.formatter = formatter
    }

    public func execute(_ size: any BinaryInteger) -> String? {
        formatter.string(for: size)
    }
}
