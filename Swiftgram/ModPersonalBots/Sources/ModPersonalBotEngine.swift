import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import ModSettings

/// Local "personal bot": watches incoming messages of an account and answers them
/// according to ModBotRules. Works while the app is running (foreground or shortly in background).
public final class ModPersonalBotEngine {
    private let account: Account
    private var disposable: Disposable?
    private var lastReplies: [String: Double] = [:]
    private var handledMessageIds = Set<MessageId>()

    public init(account: Account) {
        self.account = account
        self.disposable = (account.stateManager.notificationMessages
        |> deliverOnMainQueue).start(next: { [weak self] messageList in
            guard let self else {
                return
            }
            for (messages, _, _, _) in messageList {
                for message in messages {
                    self.handle(message: message)
                }
            }
        })
    }

    deinit {
        self.disposable?.dispose()
    }

    private func handle(message: Message) {
        if !ModBotRules.isEnabled {
            return
        }
        if !message.flags.contains(.Incoming) || message.text.isEmpty {
            return
        }
        if self.handledMessageIds.contains(message.id) {
            return
        }
        self.handledMessageIds.insert(message.id)
        if self.handledMessageIds.count > 2000 {
            self.handledMessageIds.removeAll()
        }
        // Don't talk to bots and channels, it may loop.
        guard let author = message.author as? TelegramUser, author.botInfo == nil else {
            return
        }
        let peerId = message.id.peerId
        let isPrivate = peerId.namespace == Namespaces.Peer.CloudUser
        let isGroup = peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel
        if peerId.namespace == Namespaces.Peer.CloudChannel, let channel = message.peers[peerId] as? TelegramChannel, case .broadcast = channel.info {
            return
        }
        let isMentioned = message.attributes.contains(where: { $0 is ConsumablePersonalMentionMessageAttribute })
        let appIsActive = UIApplication.shared.applicationState == .active

        for rule in ModBotRules.rules where rule.isEnabled {
            switch rule.scope {
            case .privateChats:
                if !isPrivate {
                    continue
                }
            case .groups:
                if !isGroup || !isMentioned {
                    continue
                }
            case .all:
                if !isPrivate && !(isGroup && isMentioned) {
                    continue
                }
            }
            if rule.onlyWhenAppInactive && appIsActive {
                continue
            }
            if !rule.matches(text: message.text) {
                continue
            }
            let cooldownKey = "\(rule.id)_\(peerId.toInt64())"
            let now = CFAbsoluteTimeGetCurrent()
            if let last = self.lastReplies[cooldownKey], now - last < max(5.0, rule.cooldownMinutes * 60.0) {
                return
            }
            self.lastReplies[cooldownKey] = now

            let text = rule.renderReply(authorName: author.firstName ?? author.username ?? "", incomingText: message.text)
            if text.isEmpty {
                return
            }
            let replySubject: EngineMessageReplySubject? = rule.replyWithQuote ? EngineMessageReplySubject(messageId: message.id, quote: nil, innerSubject: nil) : nil
            let enqueue: EnqueueMessage = .message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: message.threadId, replyToMessageId: replySubject, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
            let account = self.account
            Queue.mainQueue().after(max(0.0, min(60.0, rule.delaySeconds)), {
                let _ = enqueueMessages(account: account, peerId: peerId, messages: [enqueue]).start()
            })
            // Only the first matching rule answers.
            return
        }
    }
}
