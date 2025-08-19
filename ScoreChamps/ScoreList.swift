//
//  ScoreList.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 2025-05-21.
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
        title = "Scores"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()

        // If your storyboard cell isn't set to Subtitle, we'll create one on the fly in cellForRow.
        loadMatches()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMatches() // refresh after adding a new match
    }

    @IBAction func newScoreTapped(_ sender: Any) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "NewScoreViewController") as? NewScoreViewController else {
            assertionFailure("Storyboard ID mismatch for NewScoreViewController")
            return
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func loadMatches() {
        guard !currentUserId.isEmpty else { return }
        FirebaseService.shared.fetchMatches(for: currentUserId) { [weak self] list in
            guard let self = self else { return }
            // newest first? use list.reversed()
            self.matches = list
            DispatchQueue.main.async { self.tableView.reloadData() }
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

        cell.textLabel?.text = "vs. …"
        cell.detailTextLabel?.text = "You \(m.player1) – \(m.player2)"
        cell.accessoryType = .disclosureIndicator

        // Resolve opponent name
        user(for: m.opponentUserId) { [weak tableView] user in
            DispatchQueue.main.async {
                guard
                    let tableView = tableView,
                    let ip = tableView.indexPath(for: cell),
                    ip == indexPath
                else { return }

                if let u = user {
                    let name = !u.name.isEmpty ? u.name : (!u.username.isEmpty ? "@\(u.username)" : u.userId)
                    cell.textLabel?.text = "vs. \(name)"
                } else {
                    cell.textLabel?.text = "vs. (unknown)"
                }
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // TODO: push a match details screen if desired
    }
}
