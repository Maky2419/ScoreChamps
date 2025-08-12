import UIKit

final class ScoreList: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    // Your Match model from FirebaseService.fetchMatches(...)
    private var matches: [Match] = []
    private var usersCache: [String: UserModel] = [:] // cache opponent lookups

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scores"
        tableView.dataSource = self
        tableView.delegate = self
        loadMatches()
    }

    @IBAction func newScoreTapped(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "SelectOpponentVC")
        navigationController?.pushViewController(vc, animated: true)
    }

    private func loadMatches() {
        guard let me = FirebaseService.shared.currentUserId else { return }
        FirebaseService.shared.fetchMatches(for: me) { [weak self] list in
            self?.matches = list.reversed()
            self?.tableView.reloadData()
        }
    }

    // Convenience: get opponent user (cached)
    private func opponent(for uid: String, completion: @escaping (UserModel?) -> Void) {
        if let cached = usersCache[uid] { completion(cached); return }
        FirebaseService.shared.fetchUser(byUserId: uid) { [weak self] u in
            if let u { self?.usersCache[uid] = u }
            completion(u)
        }
    }
}

extension ScoreList: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        matches.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ScoreCell")

        let m = matches[indexPath.row]
        cell.textLabel?.text = "You \(m.player1) – \(m.player2) …"
        cell.detailTextLabel?.text = "Loading opponent…"
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .none

        // Fill in opponent name/username when loaded
        let ip = indexPath
        opponent(for: m.opponentUserId) { [weak tableView] user in
            guard let tv = tableView,
                  let c = tv.cellForRow(at: ip) else { return }
            let name = user?.name ?? user?.username ?? "Opponent"
            let uname = user?.username ?? "opponent"
            c.textLabel?.text = "You \(m.player1) – \(m.player2) \(name)"
            c.detailTextLabel?.text = "vs @\(uname)"
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let m = matches[indexPath.row]

        guard let nav = navigationController else { return }

        // Prefer popping back to an existing picker if it's already in the stack
        if let picker = nav.viewControllers.first(where: { $0 is SelectOpponentViewController }) as? SelectOpponentViewController {
            // Preselect this opponent in the picker (username is optional)
            let username = usersCache[m.opponentUserId]?.username ?? ""
            picker.preselectOpponent = OpponentPref(uid: m.opponentUserId, username: username)
            picker.autoOpenPreselected = false
            nav.popToViewController(picker, animated: true)
            return
        }

        // Otherwise push a new picker and preselect the same opponent
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "SelectOpponentVC") as! SelectOpponentViewController
        let username = usersCache[m.opponentUserId]?.username ?? ""
        vc.preselectOpponent = OpponentPref(uid: m.opponentUserId, username: username)
        vc.autoOpenPreselected = false
        nav.pushViewController(vc, animated: true)
    }
}
