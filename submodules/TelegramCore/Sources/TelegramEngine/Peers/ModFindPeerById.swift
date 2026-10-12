import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

// MARK: Mod - find an account / chat by its numeric id

private func modFindUserOnServer(accountPeerId: PeerId, postbox: Postbox, network: Network, userId: Int64) -> Signal<Peer?, NoError> {
    // The server answers with access_hash = 0 for users this account can "see"
    // (common chats, contacts, users from loaded messages, bots, …).
    return network.request(Api.functions.users.getUsers(id: [.inputUser(.init(userId: userId, accessHash: 0))]))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<[Api.User]?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Peer?, NoError> in
        guard let apiUser = result?.first else {
            return .single(nil)
        }
        return postbox.transaction { transaction -> Peer? in
            let parsedPeers = AccumulatedPeers(users: [apiUser])
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
            return transaction.getPeer(apiUser.peerId)
        }
    }
}

public extension TelegramEngine.Peers {
    /// Accepts a user id (123456789), a Bot API chat id of a channel / supergroup (-100…)
    /// or of a basic group (-123…). Looks in the local database first, then asks the server.
    func modFindPeerById(_ rawId: Int64) -> Signal<EnginePeer?, NoError> {
        let account = self.account
        let channelPrefix: Int64 = 1000000000000

        let localPeer: (PeerId) -> Signal<Peer?, NoError> = { peerId in
            return account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            }
        }

        let result: Signal<Peer?, NoError>
        if rawId <= -channelPrefix {
            let channelId = -rawId - channelPrefix
            result = localPeer(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)))
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                if let peer {
                    return .single(peer)
                }
                return _internal_findChannelById(accountPeerId: account.peerId, postbox: account.postbox, network: account.network, channelId: channelId)
            }
        } else if rawId < 0 {
            result = localPeer(PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(-rawId)))
        } else if rawId > 0 {
            result = localPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(rawId)))
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                if let peer {
                    return .single(peer)
                }
                return modFindUserOnServer(accountPeerId: account.peerId, postbox: account.postbox, network: account.network, userId: rawId)
            }
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                if let peer {
                    return .single(peer)
                }
                // A raw MTProto channel id without the -100 prefix.
                return localPeer(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(rawId)))
                |> mapToSignal { peer -> Signal<Peer?, NoError> in
                    if let peer {
                        return .single(peer)
                    }
                    return _internal_findChannelById(accountPeerId: account.peerId, postbox: account.postbox, network: account.network, channelId: rawId)
                }
            }
        } else {
            result = .single(nil)
        }
        return result
        |> map { peer in
            return peer.flatMap(EnginePeer.init)
        }
    }
}
