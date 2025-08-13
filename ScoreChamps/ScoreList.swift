import UIKit

final class ScoreList: UIViewController {
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh after adding a new match
        loadMatches()
    }

    @IBAction func newScoreTapped(_ sender: Any) {
        // Go to the friend picker screen
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "SelectOpponentVC")
        navigationController?.pushViewController(vc, animated: true)
    }

    private func loadMatches() {
        guard let me = FirebaseService.shared.currentUserId else { return }
        FirebaseService.shared.fetchMatches(for: me) { [weak self] list in
            guard let self = self else { return }
            self.matches = list.reversed()
            DispatchQueue.main.async { self.tableView.reloadData() }
        }
    }

    // Convenience: async fetch & cache opponent user
    private func user(for uid: String, completion: @escaping (UserModel?) -> Void) {
        if let cached = usersCache[uid] { completion(cached); return }
        FirebaseService.shared.fetchUser(byUserId: uid) { [weak self] u in
            if let u = u { self?.usersCache[uid] = u }
            completion(u)
        }
    }
}

extension ScoreList: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { matches.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ScoreCell")

        let m = matches[indexPath.row]
        cell.textLabel?.text = "vs. …"
        cell.detailTextLabel?.text = "You \(m.player1) – \(m.player2)"

        user(for: m.opponentUserId) { user in
            DispatchQueue.main.async {
                if let user = user,
                   tableView.indexPath(for: cell) == indexPath {
                    cell.textLabel?.text = "vs. \(user.name) (@\(user.username))"
                }
            }
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // If you later want to push a chart/details screen, do it here.
    }
}
