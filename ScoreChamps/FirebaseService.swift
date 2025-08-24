//
//  FirebaseService.swift
//  ScoreChamps
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
        // Prototype scan; for production, index usernames.
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
            "friends": [String: String](), // friendUid -> username (truthy)
            "matches": [String: Any]()
        ]
        userRef.setValue(data) { err, _ in
            completion(err == nil ? userRef.key : nil)
        }
    }

    // MARK: - Friends

    /// Reads `/Accounts/{uid}/friends` and resolves to `UserModel`s.
    /// Supports both map `{ friendId: true/username/... }` and list `["fid", ...]`.
    func fetchFriends(for userId: String, completion: @escaping ([UserModel]) -> Void) {
        ref.child("Accounts").child(userId).observeSingleEvent(of: .value) { [weak self] userSnap in
            guard let self = self,
                  let userDict = userSnap.value as? [String: Any] else { completion([]); return }

            var friendIds: [String] = []

            if let map = userDict["friends"] as? [String: Any] {
                friendIds = map.compactMap { (k, v) in
                    if let b = v as? Bool, b { return k }
                    if let n = v as? NSNumber, n.boolValue { return k }
                    if let s = v as? String { return s.isEmpty ? nil : k } // username stored → truthy
                    return nil
                }
            } else if let list = userDict["friends"] as? [String] {
                friendIds = list
            }

            guard !friendIds.isEmpty else { completion([]); return }

            self.ref.child("Accounts").observeSingleEvent(of: .value) { accountsSnap in
                var out: [UserModel] = []
                for child in accountsSnap.children {
                    guard let s = child as? DataSnapshot,
                          friendIds.contains(s.key),
                          let dict = s.value as? [String: Any],
                          let u = UserModel(userId: s.key, dict: dict) else { continue }
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
        ref.child("Accounts").child(myUid).child("friends")
            .updateChildValues([friendUid: friendUsername]) { err, _ in
                completion(err == nil)
            }
    }

    // MARK: Friend Requests
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
                        if let d = raw as? [String: Any],
                           let r = FriendRequest(dict: d),
                           r.status == "pending" {
                            items.append(r)
                        }
                    }
                }
                handler(items.sorted { $0.createdAt > $1.createdAt })
            }
    }

    func removeIncomingFriendRequestsObserver(_ handle: DatabaseHandle, for uid: String) {
        ref.child("Accounts").child(uid).child("friendRequests").child("incoming")
            .removeObserver(withHandle: handle)
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
            "/Accounts/\(requesterUid)/friendRequests/outgoing/\(myUid)/status": "declined" // fixed typo
        ]
        ref.updateChildValues(updates) { err, _ in completion(err == nil) }
    }

    // MARK: - Matches

    /// Read matches under /Accounts/{uid}/matches → [Match]
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

    /// Update /Accounts/{uid}/matches/{matchId}/scores
    func updateMatch(for uid: String,
                     matchId: String,
                     p1: Int,
                     p2: Int,
                     completion: @escaping (Bool) -> Void) {
        let scoresRef = ref.child("Accounts").child(uid).child("matches").child(matchId).child("scores")
        scoresRef.updateChildValues(["player1": p1, "player2": p2]) { err, _ in
            completion(err == nil)
        }
        // Optionally bump updatedAt, etc.
    }

    /// Create a match for both players and store reciprocal keys so we can delete both later.
    func addMatchBothSides(myUid: String,
                           opponentUid: String,
                           myScore: Int,
                           oppScore: Int,
                           title: String? = nil,
                           completion: @escaping (Bool, String?) -> Void) {

        let myKey  = ref.child("Accounts").child(myUid).child("matches").childByAutoId().key ?? UUID().uuidString
        let oppKey = ref.child("Accounts").child(opponentUid).child("matches").childByAutoId().key ?? UUID().uuidString

        var myMatch: [String: Any] = [
            "opponentUserId": opponentUid,
            "scores": ["player1": myScore, "player2": oppScore],
            "createdAt": ServerValue.timestamp(),
            "reciprocalMatchId": oppKey
        ]
        var oppMatch: [String: Any] = [
            "opponentUserId": myUid,
            "scores": ["player1": oppScore, "player2": myScore],
            "createdAt": ServerValue.timestamp(),
            "reciprocalMatchId": myKey
        ]
        if let t = title, !t.isEmpty {
            myMatch["title"] = t
            oppMatch["title"] = t
        }

        let updates: [String: Any] = [
            "/Accounts/\(myUid)/matches/\(myKey)"      : myMatch,
            "/Accounts/\(opponentUid)/matches/\(oppKey)": oppMatch
        ]

        ref.updateChildValues(updates) { error, _ in
            completion(error == nil, error?.localizedDescription)
        }
    }

    /// Delete both sides (uses reciprocal key if available, else falls back to searching).
    func deleteMatchBothSides(myUid: String,
                              myMatchId: String,
                              completion: @escaping (Bool, String?) -> Void) {
        let myRef = ref.child("Accounts").child(myUid).child("matches").child(myMatchId)
        myRef.observeSingleEvent(of: .value) { [weak self] snap in
            guard let self = self else { return }
            guard let dict = snap.value as? [String: Any] else {
                completion(false, "Match not found.")
                return
            }

            let opponentUid = dict["opponentUserId"] as? String ?? ""
            let reciprocal  = dict["reciprocalMatchId"] as? String

            let myCreatedAt: TimeInterval? = {
                if let t = dict["createdAt"] as? TimeInterval { return t }
                if let n = dict["createdAt"] as? NSNumber { return n.doubleValue }
                return nil
            }()

            if let oppKey = reciprocal, !opponentUid.isEmpty {
                let updates: [String: Any] = [
                    "/Accounts/\(myUid)/matches/\(myMatchId)"    : NSNull(),
                    "/Accounts/\(opponentUid)/matches/\(oppKey)" : NSNull()
                ]
                self.ref.updateChildValues(updates) { err, _ in
                    completion(err == nil, err?.localizedDescription)
                }
                return
            }

            guard !opponentUid.isEmpty else {
                myRef.removeValue { err, _ in completion(err == nil, err?.localizedDescription) }
                return
            }

            self.ref.child("Accounts").child(opponentUid).child("matches")
                .observeSingleEvent(of: .value) { oppSnap in
                    var candidateKey: String?

                    for child in oppSnap.children {
                        guard let s = child as? DataSnapshot,
                              let d = s.value as? [String: Any] else { continue }

                        if let rec = d["reciprocalMatchId"] as? String, rec == myMatchId {
                            candidateKey = s.key; break
                        }
                        if let theirNum = d["createdAt"] as? NSNumber, let mine = myCreatedAt,
                           abs(theirNum.doubleValue - mine) < 0.5 { candidateKey = s.key; break }
                        if let theirTs = d["createdAt"] as? TimeInterval, let mine = myCreatedAt,
                           abs(theirTs - mine) < 0.5 { candidateKey = s.key; break }
                    }

                    var updates: [String: Any] = [
                        "/Accounts/\(myUid)/matches/\(myMatchId)" : NSNull()
                    ]
                    if let oppKey = candidateKey {
                        updates["/Accounts/\(opponentUid)/matches/\(oppKey)"] = NSNull()
                    }

                    self.ref.updateChildValues(updates) { err, _ in
                        if let err = err {
                            completion(false, err.localizedDescription)
                        } else if candidateKey == nil {
                            completion(true, "Deleted your copy. Opponent copy not found.")
                        } else {
                            completion(true, nil)
                        }
                    }
                }
        }
    }

    // MARK: - Optional global Scores collection (separate log)
    func createScore(player1Id: String,
                     player2Id: String,
                     player1Score: Int,
                     player2Score: Int,
                     title: String? = nil,
                     completion: @escaping (Result<ScoreModel, Error>) -> Void) {
        let newRef = ref.child("Scores").childByAutoId()
        var payload: [String: Any] = [
            "id": newRef.key ?? UUID().uuidString,
            "player1Id": player1Id,
            "player2Id": player2Id,
            "player1Score": player1Score,
            "player2Score": player2Score,
            "createdAt": Date().timeIntervalSince1970
        ]
        if let t = title, !t.isEmpty { payload["title"] = t }

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

    // MARK: - Delete Request workflow

    /// Create a delete request record and notify opponent. Opponent must accept before deletion.
    func requestDeleteMatch(myUid: String,
                            myMatchId: String,
                            completion: @escaping (Bool, String?) -> Void) {

        let myMatchRef = ref.child("Accounts").child(myUid).child("matches").child(myMatchId)
        myMatchRef.observeSingleEvent(of: .value) { [weak self] snap in
            guard let self = self else { return }
            guard let dict = snap.value as? [String: Any] else {
                completion(false, "Match not found.")
                return
            }
            let opponentUid = dict["opponentUserId"] as? String ?? ""
            let oppMatchId  = dict["reciprocalMatchId"] as? String
            let title       = dict["title"] as? String

            guard !opponentUid.isEmpty else {
                completion(false, "Opponent not found.")
                return
            }

            let reqRef = self.ref.child("DeleteRequests").childByAutoId()
            let now = ServerValue.timestamp()
            var payload: [String: Any] = [
                "id": reqRef.key ?? UUID().uuidString,
                "fromUid": myUid,
                "toUid": opponentUid,
                "myMatchId": myMatchId,
                "createdAt": now,
                "status": "pending"
            ]
            if let oppMatchId = oppMatchId { payload["oppMatchId"] = oppMatchId }
            if let title = title { payload["title"] = title }

            let key = reqRef.key ?? UUID().uuidString
            let updates: [String: Any] = [
                "/DeleteRequests/\(key)": payload,
                "/Accounts/\(opponentUid)/deleteRequests/incoming/\(key)": ["status": "pending"],
                "/Accounts/\(myUid)/deleteRequests/outgoing/\(key)": ["status": "pending"]
            ]

            self.ref.updateChildValues(updates) { err, _ in
                completion(err == nil, err?.localizedDescription)
            }
        }
    }

    /// Observe pending incoming delete requests for a user.
    func observeIncomingDeleteRequests(for uid: String,
                                       handler: @escaping ([DeleteRequest]) -> Void) -> DatabaseHandle {
        let incomingRef = ref.child("Accounts").child(uid).child("deleteRequests").child("incoming")
        return incomingRef.observe(.value) { [weak self] snap in
            guard let self = self else { return }

            var ids: [String] = []
            if let dict = snap.value as? [String: Any] {
                ids = Array(dict.keys)
            }
            guard !ids.isEmpty else { handler([]); return }

            let group = DispatchGroup()
            var out: [DeleteRequest] = []

            for id in ids {
                group.enter()
                self.ref.child("DeleteRequests").child(id).observeSingleEvent(of: .value) { s in
                    defer { group.leave() }
                    guard let d = s.value as? [String: Any],
                          let r = DeleteRequest(id: s.key, dict: d),
                          r.toUid == uid,
                          r.status == "pending" else { return }
                    out.append(r)
                }
            }

            group.notify(queue: .main) {
                handler(out.sorted { $0.createdAt > $1.createdAt })
            }
        }
    }

    func removeIncomingDeleteRequestsObserver(_ handle: DatabaseHandle, for uid: String) {
        ref.child("Accounts").child(uid).child("deleteRequests").child("incoming")
            .removeObserver(withHandle: handle)
    }

    /// Accept or decline a delete request.
    /// On accept: remove responder's copy, mark accepted, and *attempt* to remove requester's copy.
    /// If cross-user deletion is blocked by rules, we still return success.
    func respondToDeleteRequest(responderUid: String,
                                requestId: String,
                                accept: Bool,
                                completion: @escaping (Bool, String?) -> Void) {
        let reqRef = ref.child("DeleteRequests").child(requestId)

        reqRef.observeSingleEvent(of: .value) { [weak self] s in
            guard let self = self else { return }
            guard let d = s.value as? [String: Any],
                  var req = DeleteRequest(id: s.key, dict: d) else {
                completion(false, "Request not found.")
                return
            }

            guard req.toUid == responderUid else {
                completion(false, "Not authorized to respond to this request.")
                return
            }
            guard req.status == "pending" else {
                completion(false, "Request is already \(req.status).")
                return
            }

            // Decline → just update status + clean indexes
            guard accept else {
                let updates: [String: Any] = [
                    "/DeleteRequests/\(requestId)/status": "declined",
                    "/Accounts/\(req.toUid)/deleteRequests/incoming/\(requestId)" : NSNull(),
                    "/Accounts/\(req.fromUid)/deleteRequests/outgoing/\(requestId)": NSNull()
                ]
                self.ref.updateChildValues(updates) { err, _ in
                    completion(err == nil, err?.localizedDescription)
                }
                return
            }

            // Resolve responder's matchId if request didn't carry it
            func resolveResponderMatchId(_ done: @escaping (String?) -> Void) {
                if let oppKey = req.oppMatchId, !oppKey.isEmpty {
                    done(oppKey)
                    return
                }
                self.ref.child("Accounts").child(req.toUid).child("matches")
                    .observeSingleEvent(of: .value) { snap in
                        var found: String?
                        for child in snap.children {
                            guard let s = child as? DataSnapshot,
                                  let dict = s.value as? [String: Any] else { continue }
                            if let rec = dict["reciprocalMatchId"] as? String, rec == req.myMatchId {
                                found = s.key; break
                            }
                        }
                        done(found)
                    }
            }

            resolveResponderMatchId { responderMatchId in
                // Phase 1: best-effort remove responder's copy
                var phase1: [String: Any] = [:]
                if let rm = responderMatchId {
                    phase1["/Accounts/\(req.toUid)/matches/\(rm)"] = NSNull()
                }

                func proceedToPhase2() {
                    // Phase 2: mark accepted, clear inbox/outbox; try to remove requester's copy.
                    var phase2: [String: Any] = [
                        "/DeleteRequests/\(requestId)/status": "accepted",
                        "/Accounts/\(req.toUid)/deleteRequests/incoming/\(requestId)" : NSNull(),
                        "/Accounts/\(req.fromUid)/deleteRequests/outgoing/\(requestId)": NSNull()
                    ]
                    phase2["/Accounts/\(req.fromUid)/matches/\(req.myMatchId)"] = NSNull() // may be denied

                    self.ref.updateChildValues(phase2) { err, _ in
                        if let err = err {
                            // Most likely a permission error deleting the other user's match.
                            completion(true, "Accepted. Your copy was removed. The other side will delete when they open the app.")
                        } else {
                            completion(true, nil)
                        }
                    }
                }

                if phase1.isEmpty {
                    proceedToPhase2()
                } else {
                    self.ref.updateChildValues(phase1) { _, _ in
                        // Ignore errors (already deleted, etc.) and continue
                        proceedToPhase2()
                    }
                }
            }
        }
    }
}

// MARK: - DeleteRequest model
struct DeleteRequest {
    let id: String
    let fromUid: String
    let toUid: String
    let myMatchId: String
    let oppMatchId: String?
    let title: String?
    let createdAt: TimeInterval
    let status: String // pending | accepted | declined

    init?(id: String, dict: [String: Any]) {
        guard
            let fromUid = dict["fromUid"] as? String,
            let toUid = dict["toUid"] as? String,
            let myMatchId = dict["myMatchId"] as? String,
            let status = dict["status"] as? String
        else { return nil }

        self.id = id
        self.fromUid = fromUid
        self.toUid = toUid
        self.myMatchId = myMatchId
        self.oppMatchId = dict["oppMatchId"] as? String
        self.title = dict["title"] as? String

        if let t = dict["createdAt"] as? TimeInterval {
            self.createdAt = t
        } else if let n = dict["createdAt"] as? NSNumber {
            self.createdAt = n.doubleValue
        } else {
            self.createdAt = Date().timeIntervalSince1970
        }

        self.status = status
    }

    var dict: [String: Any] {
        var out: [String: Any] = [
            "id": id,
            "fromUid": fromUid,
            "toUid": toUid,
            "myMatchId": myMatchId,
            "createdAt": createdAt,
            "status": status
        ]
        if let opp = oppMatchId { out["oppMatchId"] = opp }
        if let t = title { out["title"] = t }
        return out
    }
}
