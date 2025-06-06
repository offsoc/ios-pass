//
// Mailbox.swift
// Proton Pass - Created on 06/08/2024.
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

public struct Mailbox: Decodable, Hashable, Equatable, Sendable, Identifiable {
    public let mailboxID: Int
    public let email: String
    /// In case there is a pending email change, this will show what is the requested email change
    public var pendingEmail: String?
    public let verified: Bool
    public let isDefault: Bool
    public let aliasCount: Int

    public var verificationNeeded: Bool {
        pendingEmail != nil ? true : !verified
    }

    public init(mailboxID: Int,
                email: String,
                pendingEmail: String?,
                verified: Bool,
                isDefault: Bool,
                aliasCount: Int) {
        self.mailboxID = mailboxID
        self.email = email
        self.pendingEmail = pendingEmail
        self.verified = verified
        self.isDefault = isDefault
        self.aliasCount = aliasCount
    }

    public var id: Int {
        mailboxID
    }
}
