//
//  FirebaseService.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 8/10/25.
//

import Foundation
import FirebaseDatabase

final class FirebaseService {
    static let shared = FirebaseService()
    let ref = Database.database().reference()

    private init() {}

    // MARK: - Session
    var currentUserId: String? {
        get { UserDefaults.standard.string(forKey: "loggedInUserId") }
        set { UserDefaults.standard.set(newValue, forKey: "loggedInUserId") }
    }

    // MARK: - Users
    func fetchAllUsers(completion: @escaping ([String: UserModel]) -> Void) {
        ref.child("Accounts").observeSingleEvent(of: .value) { snap in
            var map: [String: UserModel] = [:]
            for child in snap.children {
                guard let s = child as? DataSnapshot,
                      let dict = s.value as? [String: Any],
                      let u = UserModel(userId: s.key, dict: dict) else { continue }
                map[s.key] = u
            }
            completion(map)
        }
    }

    func fetchUser(byUserId uid: String, completion: @escaping (UserModel?) -> Void) {
        ref.child("Accounts").child(uid).observeSingleEvent(of: .value) { s in
            guard let dict = s.value as? [String: Any],
                  let u = UserModel(userId: uid, dict: dict) else { completion(nil); return }
            completion(u)
        }
    }

    func fetchUser(byUsername username: String, completion: @escaping (String?, UserModel?) -> Void) {
        // Simple scan (OK for prototypes). For prod, index usernames separately.
        fetchAllUsers { map in
            if let pair = map.first(where: { $0.value.username == username }) {
                completion(pair.key, pair.value)
            } else {
                completion(nil, nil)
            }
        }
    }

    func createUser(name: String, username: String, password: String, completion: @escaping (String?) -> Void) {
        let userRef = ref.child("Accounts").childByAutoId()
        let data: [String: Any] = [
            "name": name,
            "username": username,
            "password": password,
            "friends": [String: String](),
            "matches": [String: Any]()
        ]
        userRef.setValue(data) { err, _ in
            completion(err == nil ? userRef.key : nil)
        }
    }

    // MARK: - Friends (uid -> username)
    func addFriend(myUid: String, friendUid: String, friendUsername: String, completion: @escaping (Bool) -> Void) {
        ref.child("Accounts").child(myUid).child("friends").updateChildValues([friendUid: friendUsername]) { err, _ in
            completion(err == nil)
        }
    }

    // MARK: - Matches
    func fetchMatches(for uid: String, completion: @escaping ([Match]) -> Void) {
        ref.child("Accounts").child(uid).child("matches").observeSingleEvent(of: .value) { s in
            var items: [Match] = []
            if let dict = s.value as? [String: Any] {
                for (mid, raw) in dict {
                    if let d = raw as? [String: Any], let m = Match(matchId: mid, dict: d) { items.append(m) }
                }
            }
            completion(items.sorted { $0.matchId < $1.matchId })
        }
    }

    func addMatch(for uid: String, opponentUid: String, p1: Int, p2: Int, completion: @escaping (Bool) -> Void) {
        let refMatch = ref.child("Accounts").child(uid).child("matches").childByAutoId()
        let m: [String: Any] = [
            "matchId": refMatch.key ?? UUID().uuidString,
            "opponentUserId": opponentUid,
            "scores": [
                "player1": p1,
                "player2": p2
            ]
        ]
        refMatch.setValue(m) { err, _ in
            completion(err == nil)
        }

    }
}
// FirebaseService.swift  (add these methods)
extension FirebaseService {

    // /Accounts/<uid>/friendRequests/incoming/<fromUid> = FriendRequest
    // /Accounts/<uid>/friendRequests/outgoing/<toUid>   = { toUid, status, createdAt }
    func sendFriendRequest(from myUid: String, toUsername: String, completion: @escaping (Bool, String?) -> Void) {
        fetchUser(byUserId: myUid) { me in
            guard let me = me else { completion(false, "Current user not found"); return }
            self.fetchUser(byUsername: toUsername) { toUid, toUser in
                guard let toUid = toUid, let _ = toUser else { completion(false, "User not found"); return }
                let now = Date().timeIntervalSince1970

                // incoming for recipient
                let incoming = FriendRequest(
                    dict: [
                        "fromUid": myUid,
                        "fromUsername": me.username,
                        "fromName": me.name,
                        "createdAt": now,
                        "status": "pending"
                    ])!.dict

                // outgoing for sender (small record)
                let outgoing: [String: Any] = [
                    "toUid": toUid,
                    "createdAt": now,
                    "status": "pending"
                ]

                let updates: [String: Any] = [
                    "/Accounts/\(toUid)/friendRequests/incoming/\(myUid)": incoming,
                    "/Accounts/\(myUid)/friendRequests/outgoing/\(toUid)": outgoing
                ]
                self.ref.updateChildValues(updates) { err, _ in
                    completion(err == nil, err?.localizedDescription)
                }
            }
        }
    }

    func observeIncomingRequests(for uid: String, handler: @escaping ([FriendRequest]) -> Void) -> DatabaseHandle {
        ref.child("Accounts").child(uid).child("friendRequests").child("incoming")
            .observe(.value) { snap in
                var items: [FriendRequest] = []
                if let dict = snap.value as? [String: Any] {
                    for (_, raw) in dict {
                        if let d = raw as? [String: Any], let r = FriendRequest(dict: d), r.status == "pending" {
                            items.append(r)
                        }
                    }
                }
                // newest first
                handler(items.sorted { $0.createdAt > $1.createdAt })
            }
    }

    func acceptFriendRequest(myUid: String, from requester: FriendRequest, completion: @escaping (Bool) -> Void) {
        // Add each other as friends (uid -> username)
        fetchUser(byUserId: requester.fromUid) { other in
            guard let other = other else { completion(false); return }
            self.fetchUser(byUserId: myUid) { me in
                guard let me = me else { completion(false); return }

                let updates: [String: Any] = [
                    "/Accounts/\(myUid)/friends/\(requester.fromUid)": other.username,
                    "/Accounts/\(requester.fromUid)/friends/\(myUid)": me.username,
                    "/Accounts/\(myUid)/friendRequests/incoming/\(requester.fromUid)/status": "accepted",
                    "/Accounts/\(requester.fromUid)/friendRequests/outgoing/\(myUid)/status": "accepted"
                ]
                self.ref.updateChildValues(updates) { err, _ in completion(err == nil) }
            }
        }
    }

    func declineFriendRequest(myUid: String, from requesterUid: String, completion: @escaping (Bool) -> Void) {
        let updates: [String: Any] = [
            "/Accounts/\(myUid)/friendRequests/incoming/\(requesterUid)/status": "declined",
            "/Accounts/\(requesterUid)/friendRequests/outgoing/\(myUid)/status": "declined"
        ]
        ref.updateChildValues(updates) { err, _ in completion(err == nil) }
    }
}
extension FirebaseService {

    /// Create a match for both players (two writes) using a single multi-path update.
    /// - myUid's entry: opponentUserId = opponentUid, scores.player1 = myScore, scores.player2 = oppScore
    /// - opponent's entry: opponentUserId = myUid, scores.player1 = oppScore, scores.player2 = myScore
    func addMatchBothSides(myUid: String,
                           opponentUid: String,
                           myScore: Int,
                           oppScore: Int,
                           completion: @escaping (Bool, String?) -> Void) {

        let myMatchKey  = ref.child("Accounts").child(myUid).child("matches").childByAutoId().key ?? UUID().uuidString
        let oppMatchKey = ref.child("Accounts").child(opponentUid).child("matches").childByAutoId().key ?? UUID().uuidString

        let myMatch: [String: Any] = [
            "opponentUserId": opponentUid,
            "scores": ["player1": myScore, "player2": oppScore],
            "createdAt": ServerValue.timestamp()
        ]

        let oppMatch: [String: Any] = [
            "opponentUserId": myUid,
            "scores": ["player1": oppScore, "player2": myScore],
            "createdAt": ServerValue.timestamp()
        ]

        let updates: [String: Any] = [
            "/Accounts/\(myUid)/matches/\(myMatchKey)" : myMatch,
            "/Accounts/\(opponentUid)/matches/\(oppMatchKey)" : oppMatch
        ]

        ref.updateChildValues(updates) { error, _ in
            completion(error == nil, error?.localizedDescription)
        }
    }
}
