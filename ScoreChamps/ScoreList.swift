import UIKit

class ScoreList: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    private var matches: [Match] = []
    private var usersCache: [String: UserModel] = [:] // cache opponent lookups

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scores"
        tableView.dataSource = self
        tableView.delegate = self
        loadMatches()
    }

    private func loadMatches() {
        guard let me = FirebaseService.shared.currentUserId else { return }
        FirebaseService.shared.fetchMatches(for: me) { [weak self] list in
            self?.matches = list.reversed()
            self?.tableView.reloadData()
        }
    }

    private func opponentName(for uid: String, completion: @escaping (String) -> Void) {
        if let cached = usersCache[uid] { completion(cached.username); return }
        FirebaseService.shared.fetchUser(byUserId: uid) { [weak self] u in
            if let u { self?.usersCache[uid] = u; completion(u.username) }
            else { completion(uid) }
        }
    }
}

extension ScoreList: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { matches.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ScoreCell")
        let m = matches[indexPath.row]
        cell.textLabel?.text = "You \(m.player1) – \(m.player2) Opponent"
        cell.detailTextLabel?.text = "Loading…"
        opponentName(for: m.opponentUserId) { name in
            if let c = tableView.cellForRow(at: indexPath) {
                c.textLabel?.text = "You \(m.player1) – \(m.player2) \(name)"
                c.detailTextLabel?.text = "vs @\(name)"
            }
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}
