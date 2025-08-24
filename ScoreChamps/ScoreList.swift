//
//  ScoreList.swift
//  ScoreChamps
//

import UIKit

final class ScoreList: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    private var matches: [Match] = []
    private var usersCache: [String: UserModel] = [:]

    private var currentUserId: String {
        FirebaseService.shared.currentUserId ?? ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.allowsSelection = true
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension

        // Pull to refresh (optional)
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = rc

        loadMatches()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMatches()
    }

    @objc private func refreshPulled() {
        loadMatches()
    }

    // MARK: - Actions
    @IBAction func newScoreTapped(_ sender: Any) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "NewScoreViewController") as? NewScoreViewController else {
            assertionFailure("Storyboard ID mismatch for NewScoreViewController")
            return
        }
        vc.onSaved  = { [weak self] in self?.loadMatches() }
        vc.onClosed = { [weak self] in self?.loadMatches() }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    // Optional: if you have a "Log out" button wired to this IBAction
    @IBAction func logoutTapped(_ sender: Any) {
        FirebaseService.shared.currentUserId = nil

        // If we were pushed: pop; if presented: dismiss.
        if let nav = navigationController {
            nav.popToRootViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Data
    private func loadMatches() {
        guard !currentUserId.isEmpty else { return }
        FirebaseService.shared.fetchMatches(for: currentUserId) { [weak self] list in
            guard let self = self else { return }
            self.matches = list
            DispatchQueue.main.async {
                self.tableView.refreshControl?.endRefreshing()
                self.tableView.reloadData()
            }
        }
    }

    // Cache + fetch opponent profile
    private func user(for uid: String, completion: @escaping (UserModel?) -> Void) {
        if let cached = usersCache[uid] { completion(cached); return }
        FirebaseService.shared.fetchUser(byUserId: uid) { [weak self] u in
            if let u = u { self?.usersCache[uid] = u }
            completion(u)
        }
    }

    private func showEditor(for match: Match) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "EditMatchViewController") as? EditMatchViewController else {
            assertionFailure("Storyboard ID 'EditMatchViewController' not found or class mismatch.")
            return
        }
        vc.match = match
        vc.onSaved  = { [weak self] in self?.loadMatches() }
        vc.onClosed = { [weak self] in self?.loadMatches() }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
}

// MARK: - UITableView
extension ScoreList: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        matches.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Ensure subtitle style even if there is no prototype cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ScoreCell")

        let m = matches[indexPath.row]

        // Title (optional) + opponent placeholder
        if let title = m.title, !title.isEmpty {
            cell.textLabel?.text = "\(title) — vs. …"
        } else {
            cell.textLabel?.text = "vs. …"
        }

        // Your score vs their score
        cell.detailTextLabel?.text = "You \(m.player1) – \(m.player2)"
        cell.accessoryType = .disclosureIndicator

        // Resolve opponent name asynchronously (protect against reuse)
        user(for: m.opponentUserId) { [weak tableView] user in
            DispatchQueue.main.async {
                guard
                    let tableView = tableView,
                    let currentIndex = tableView.indexPath(for: cell),
                    currentIndex == indexPath
                else { return }

                let nameText: String
                if let u = user {
                    nameText = !u.name.isEmpty ? u.name : (!u.username.isEmpty ? "@\(u.username)" : u.userId)
                } else {
                    nameText = "(unknown)"
                }

                if let title = m.title, !title.isEmpty {
                    cell.textLabel?.text = "\(title) — vs. \(nameText)"
                } else {
                    cell.textLabel?.text = "vs. \(nameText)"
                }
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showEditor(for: matches[indexPath.row])
    }
}
