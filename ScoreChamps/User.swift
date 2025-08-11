struct User {
        let userId: String
        let name: String
        let username: String
        let password: String        // ⚠️ For prototyping only; prefer Firebase Auth
        let friends: [String: Bool]
        let matches: [String: Match]
        
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
            
            // Optional fields
            self.friends = dict["friends"] as? [String: Bool] ?? [:]
            
            var parsedMatches: [String: Match] = [:]
            if let matchesDict = dict["matches"] as? [String: Any] {
                for (mid, raw) in matchesDict {
                    if let m = raw as? [String: Any], let match = Match(matchId: mid, dict: m) {
                        parsedMatches[mid] = match
                    }
                }
            }
            self.matches = parsedMatches
        }
    }

