//
// RemoteShareInviteDatasource.swift
// Proton Pass - Created on 13/07/2023.
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
import Foundation

public protocol RemoteShareInviteDatasourceProtocol: RemoteDatasourceProtocol {
    func getPendingInvites(sharedId: String) async throws -> ShareInvites
    func inviteProtonUser(shareId: String, request: InviteUserToShareRequest) async throws -> Bool
    func inviteExternalUser(shareId: String, request: InviteNewUserToShareRequest) async throws -> Bool
    func promoteNewUserInvite(shareId: String, inviteId: String, keys: [ItemKey]) async throws -> Bool
    func sendInviteReminder(shareId: String, inviteId: String) async throws -> Bool
    func deleteShareInvite(shareId: String, inviteId: String) async throws -> Bool
    func deleteShareNewUserInvite(shareId: String, inviteId: String) async throws -> Bool
}

public extension RemoteShareInviteDatasourceProtocol {
    func getPendingInvites(sharedId: String) async throws -> ShareInvites {
        let endpoint = GetPendingInvitesforShareEndpoint(for: sharedId)
        let response = try await apiService.exec(endpoint: endpoint)
        return .init(exisingUserInvites: response.invites,
                     newUserInvites: response.newUserInvites)
    }

    func inviteProtonUser(shareId: String, request: InviteUserToShareRequest) async throws -> Bool {
        let endpoint = InviteUserToShareEndpoint(shareId: shareId, request: request)
        let response = try await apiService.exec(endpoint: endpoint)
        return response.isSuccessful
    }

    func promoteNewUserInvite(shareId: String, inviteId: String, keys: [ItemKey]) async throws -> Bool {
        let endpoint = PromoteNewUserInviteEndpoint(shareId: shareId, inviteId: inviteId, keys: keys)
        let response = try await apiService.exec(endpoint: endpoint)
        return response.isSuccessful
    }

    func inviteExternalUser(shareId: String, request: InviteNewUserToShareRequest) async throws -> Bool {
        let endpoint = InviteNewUserToShareEndpoint(shareId: shareId, request: request)
        let response = try await apiService.exec(endpoint: endpoint)
        return response.isSuccessful
    }

    func sendInviteReminder(shareId: String, inviteId: String) async throws -> Bool {
        let endpoint = SendInviteReminderToUserEndpoint(shareId: shareId, inviteId: inviteId)
        let response = try await apiService.exec(endpoint: endpoint)
        return response.isSuccessful
    }

    func deleteShareInvite(shareId: String, inviteId: String) async throws -> Bool {
        let endpoint = DeleteShareInviteEndpoint(shareId: shareId, inviteId: inviteId)
        let response = try await apiService.exec(endpoint: endpoint)
        return response.isSuccessful
    }

    func deleteShareNewUserInvite(shareId: String, inviteId: String) async throws -> Bool {
        let endpoint = DeleteShareNewUserInviteEndpoint(shareId: shareId, inviteId: inviteId)
        let response = try await apiService.exec(endpoint: endpoint)
        return response.isSuccessful
    }
}

public final class RemoteShareInviteDatasource: RemoteDatasource, RemoteShareInviteDatasourceProtocol {}
