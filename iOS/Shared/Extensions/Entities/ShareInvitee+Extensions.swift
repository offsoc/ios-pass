//
// ShareInvitee+Extensions.swift
// Proton Pass - Created on 19/10/2023.
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

import Entities
import Macro

extension ShareInvites {
    var invitees: [any ShareInvitee] {
        existingUserInvites + newUserInvites
    }
}

extension UserShareInfos: @retroactive ShareInvitee {
    public var shareType: TargetType {
        TargetType(rawValue: targetType) ?? .unknown
    }

    public var shareRole: ShareRole {
        ShareRole(rawValue: shareRoleID) ?? .read
    }

    public var email: String {
        userEmail
    }

    public func subtitle(managerAsAdmin: Bool) -> String {
        if owner {
            #localized("Owner")
        } else {
            shareRole.title(managerAsAdmin: managerAsAdmin)
        }
    }

    public var isPending: Bool {
        false
    }

    public var isManager: Bool {
        shareRole == .manager
    }

    public var options: [ShareInviteeOption] {
        [
            .updateRole(shareId: shareID, role: shareRole),
            .confirmTransferOwnership(.init(email: userEmail, shareId: shareID)),
            .revokeAccess(shareId: shareID)
        ]
    }
}

extension ShareExistingUserInvite: @retroactive ShareInvitee {
    public var owner: Bool {
        false
    }

    public var email: String {
        invitedEmail
    }

    public func subtitle(managerAsAdmin: Bool) -> String {
        #localized("Invitation sent")
    }

    public var isPending: Bool {
        true
    }

    public var isManager: Bool {
        shareRole == .manager
    }

    public var options: [ShareInviteeOption] {
        [
            .remindExistingUserInvitation(inviteId: inviteID),
            .cancelExistingUserInvitation(inviteId: inviteID)
        ]
    }
}

extension ShareNewUserInvite: @retroactive ShareInvitee {
    public var owner: Bool {
        false
    }

    public var email: String {
        invitedEmail
    }

    public func subtitle(managerAsAdmin: Bool) -> String {
        switch inviteState {
        case .waitingForAccountCreation:
            #localized("Pending account creation")
        case .accountCreated:
            shareRole.title(managerAsAdmin: managerAsAdmin)
        }
    }

    public var isPending: Bool {
        true
    }

    public var isManager: Bool {
        shareRole == .manager
    }

    public var options: [ShareInviteeOption] {
        switch inviteState {
        case .waitingForAccountCreation:
            [
                .cancelNewUserInvitation(inviteId: newUserInviteID)
            ]

        case .accountCreated:
            [
                .cancelNewUserInvitation(inviteId: newUserInviteID),
                .confirmAccess(.init(inviteId: newUserInviteID, email: invitedEmail))
            ]
        }
    }
}
