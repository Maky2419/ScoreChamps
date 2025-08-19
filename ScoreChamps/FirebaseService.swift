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
                guard
                    let s = child as? DataSnapshot,
                    let dict = s.value as? [String: Any],
                    let u = UserModel(userId: s.key, dict: dict)
                else { continue }
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
        // Prototype: linear scan. For prod, index usernames.
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
            "friends": [String: String](), // map friendUid -> username (truthy)
            "matches": [String: Any]()
        ]
        userRef.setValue(data) { err, _ in
            completion(err == nil ? userRef.key : nil)
        }
    }

    // MARK: - Friends

    /// Reads `/Accounts/{uid}/friends` and returns full `UserModel`s.
    /// Supports both map `{ friendId: true/username/... }` and list `["fid", ...]`.
    func fetchFriends(for userId: String, completion: @escaping ([UserModel]) -> Void) {
        ref.child("Accounts").child(userId).observeSingleEvent(of: .value) { [weak self] userSnap in
            guard
                let self = self,
                let userDict = userSnap.value as? [String: Any]
            else { completion([]); return }

            var friendIds: [String] = []

            if let map = userDict["friends"] as? [String: Any] {
                friendIds = map.compactMap { (k, v) in
                    if let b = v as? Bool, b { return k }
                    if let n = v as? NSNumber, n.boolValue { return k }
                    if let s = v as? String { return s.isEmpty ? nil : k } // stored username -> truthy
                    return nil
                }
            } else if let list = userDict["friends"] as? [String] {
                friendIds = list
            }

            guard !friendIds.isEmpty else { completion([]); return }

            self.ref.child("Accounts").observeSingleEvent(of: .value) { accountsSnap in
                var out: [UserModel] = []
                for child in accountsSnap.children {
                    guard
                        let s = child as? DataSnapshot,
                        friendIds.contains(s.key),
                        let dict = s.value as? [String: Any],
                        let u = UserModel(userId: s.key, dict: dict)
                    else { continue }
                    out.append(u)
                }
                out.sort { a, b in
                    let an = a.name.isEmpty ? (a.username.isEmpty ? a.userId : a.username) : a.name
                    let bn = b.name.isEmpty ? (b.username.isEmpty ? b.userId : b.username) : b.name
                    return an.localizedCaseInsensitiveCompare(bn) == .orderedAscending
                }
                completion(out)
            }
        }
    }

    func addFriend(myUid: String, friendUid: String, friendUsername: String, completion: @escaping (Bool) -> Void) {
        ref.child("Accounts").child(myUid).child("friends").updateChildValues([friendUid: friendUsername]) { err, _ in
            completion(err == nil)
        }
    }

    // MARK: Friend Requests (prototype)
    func sendFriendRequest(from myUid: String, toUsername: String, completion: @escaping (Bool, String?) -> Void) {
        fetchUser(byUserId: myUid) { me in
            guard let me = me else { completion(false, "Current user not found"); return }
            self.fetchUser(byUsername: toUsername) { toUid, _ in
                guard let toUid = toUid else { completion(false, "User not found"); return }
                let now = Date().timeIntervalSince1970

                let incoming: [String: Any] = [
                    "fromUid": myUid,
                    "fromUsername": me.username,
                    "fromName": me.name,
                    "createdAt": now,
                    "status": "pending"
                ]
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
                handler(items.sorted { $0.createdAt > $1.createdAt })
            }
    }

    func acceptFriendRequest(myUid: String, from requester: FriendRequest, completion: @escaping (Bool) -> Void) {
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

    // MARK: - Matches
    func fetchMatches(for uid: String, completion: @escaping ([Match]) -> Void) {
        ref.child("Accounts").child(uid).child("matches").observeSingleEvent(of: .value) { s in
            var items: [Match] = []
            if let dict = s.value as? [String: Any] {
                for (mid, raw) in dict {
                    if let d = raw as? [String: Any], let m = Match(matchId: mid, dict: d) {
                        items.append(m)
                    }
                }
            }
            completion(items.sorted { $0.matchId < $1.matchId })
        }
    }

    /// One-sided add (only under uid)
    func addMatch(for uid: String, opponentUid: String, p1: Int, p2: Int, completion: @escaping (Bool) -> Void) {
        let refMatch = ref.child("Accounts").child(uid).child("matches").childByAutoId()
        let m: [String: Any] = [
            "matchId": refMatch.key ?? UUID().uuidString,
            "opponentUserId": opponentUid,
            "scores": ["player1": p1, "player2": p2],
            "createdAt": ServerValue.timestamp()
        ]
        refMatch.setValue(m) { err, _ in completion(err == nil) }
    }

    func updateMatch(for uid: String,
                     matchId: String,
                     p1: Int,
                     p2: Int,
                     completion: @escaping (Bool) -> Void) {
        let scoresRef = ref.child("Accounts")
            .child(uid)
            .child("matches")
            .child(matchId)
            .child("scores")

        scoresRef.updateChildValues(["player1": p1, "player2": p2]) { err, _ in
            completion(err == nil)
        }
    }
    
    /// Two-sided add via multi-path update (recommended for ScoreList).
    func addMatchBothSides(myUid: String,
                           opponentUid: String,
                           myScore: Int,
                           oppScore: Int,
                           completion: @escaping (Bool, String?) -> Void) {

        let myKey  = ref.child("Accounts").child(myUid).child("matches").childByAutoId().key ?? UUID().uuidString
        let oppKey = ref.child("Accounts").child(opponentUid).child("matches").childByAutoId().key ?? UUID().uuidString

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
            "/Accounts/\(myUid)/matches/\(myKey)" : myMatch,
            "/Accounts/\(opponentUid)/matches/\(oppKey)" : oppMatch
        ]

        ref.updateChildValues(updates) { error, _ in
            completion(error == nil, error?.localizedDescription)
        }
    }

    // MARK: - Optional global Scores collection
    func createScore(player1Id: String,
                     player2Id: String,
                     player1Score: Int,
                     player2Score: Int,
                     completion: @escaping (Result<ScoreModel, Error>) -> Void) {
        let newRef = ref.child("Scores").childByAutoId()
        let payload: [String: Any] = [
            "id": newRef.key ?? UUID().uuidString,
            "player1Id": player1Id,
            "player2Id": player2Id,
            "player1Score": player1Score,
            "player2Score": player2Score,
            "createdAt": Date().timeIntervalSince1970
        ]
        newRef.setValue(payload) { error, _ in
            if let error = error { completion(.failure(error)); return }
            let model = ScoreModel(
                id: payload["id"] as! String,
                player1Id: player1Id,
                player2Id: player2Id,
                player1Score: player1Score,
                player2Score: player2Score,
                createdAt: payload["createdAt"] as! TimeInterval
            )
            completion(.success(model))
        }
    }
}
