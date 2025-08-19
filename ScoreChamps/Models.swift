//
//  Models.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 8/10/25.
//

import Foundation

//
//  ScoreModel.swift
//  ScoreChamps
//

import Foundation
import FirebaseDatabase

struct ScoreModel: Codable {
    let id: String
    let player1Id: String
    let player2Id: String
    let player1Score: Int
    let player2Score: Int
    let createdAt: TimeInterval   // seconds since 1970

    // Convenience
    var date: Date { Date(timeIntervalSince1970: createdAt) }
    var winnerId: String? {
        guard player1Score != player2Score else { return nil }
        return player1Score > player2Score ? player1Id : player2Id
    }
}

// MARK: - Firebase helpers
extension ScoreModel {

    /// Build from a Firebase dict (Realtime DB)
    init?(id: String? = nil, dict: [String: Any]) {
        // Required strings
        guard
            let p1Id = dict["player1Id"] as? String,
            let p2Id = dict["player2Id"] as? String
        else { return nil }

        // Ints may come back as Int/Double/NSNumber
        func intValue(_ any: Any?) -> Int? {
            if let i = any as? Int { return i }
            if let d = any as? Double { return Int(d) }
            if let n = any as? NSNumber { return n.intValue }
            return nil
        }
        let p1Score = intValue(dict["player1Score"])
        let p2Score = intValue(dict["player2Score"])

        // createdAt may be Double/NSNumber (or missing)
        let created: TimeInterval = {
            if let t = dict["createdAt"] as? TimeInterval { return t }
            if let n = dict["createdAt"] as? NSNumber { return n.doubleValue }
            return Date().timeIntervalSince1970
        }()

        guard let s1 = p1Score, let s2 = p2Score else { return nil }

        self.id = (dict["id"] as? String) ?? id ?? UUID().uuidString
        self.player1Id = p1Id
        self.player2Id = p2Id
        self.player1Score = s1
        self.player2Score = s2
        self.createdAt = created
    }

    /// Build from a Realtime Database snapshot
    init?(snapshot: DataSnapshot) {
        guard let d = snapshot.value as? [String: Any] else { return nil }
        self.init(id: snapshot.key, dict: d)
    }

    /// Convert to a Firebase-friendly payload
    var dict: [String: Any] {
        return [
            "id": id,
            "player1Id": player1Id,
            "player2Id": player2Id,
            "player1Score": player1Score,
            "player2Score": player2Score,
            "createdAt": createdAt
        ]
    }
}


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
