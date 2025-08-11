//
//  Models.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 8/10/25.
//

import Foundation

struct Match {
    let matchId: String
    let opponentUserId: String
    let player1: Int
    let player2: Int

    init?(matchId: String, dict: [String: Any]) {
        guard
            let opponentUserId = dict["opponentUserId"] as? String,
            let scores = dict["scores"] as? [String: Any],
            let p1 = scores["player1"] as? Int,
            let p2 = scores["player2"] as? Int
        else { return nil }
        self.matchId = matchId
        self.opponentUserId = opponentUserId
        self.player1 = p1
        self.player2 = p2
    }

    var dict: [String: Any] {
        ["opponentUserId": opponentUserId,
         "scores": ["player1": player1, "player2": player2]]
    }
}

struct UserModel {
    let userId: String
    let name: String
    let username: String
    let password: String          // prototype only
    let friends: [String: String] // uid -> username

    init?(userId: String, dict: [String: Any]) {
        guard
            let name = dict["name"] as? String,
            let username = dict["username"] as? String,
            let password = dict["password"] as? String
        else { return nil }
        self.userId = userId
        self.name = name
        self.username = username
        self.password = password
        self.friends = dict["friends"] as? [String: String] ?? [:]
    }
}
struct FriendRequest {
    let fromUid: String
    let fromUsername: String
    let fromName: String
    let createdAt: TimeInterval
    let status: String // "pending" | "accepted" | "declined"

    init?(dict: [String: Any]) {
        guard
            let fromUid = dict["fromUid"] as? String,
            let fromUsername = dict["fromUsername"] as? String,
            let fromName = dict["fromName"] as? String,
            let createdAt = dict["createdAt"] as? TimeInterval,
            let status = dict["status"] as? String
        else { return nil }
        self.fromUid = fromUid
        self.fromUsername = fromUsername
        self.fromName = fromName
        self.createdAt = createdAt
        self.status = status
    }

    var dict: [String: Any] {
        [
            "fromUid": fromUid,
            "fromUsername": fromUsername,
            "fromName": fromName,
            "createdAt": createdAt,
            "status": status
        ]
    }
}
