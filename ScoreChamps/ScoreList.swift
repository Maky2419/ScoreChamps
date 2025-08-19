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
        // Title is optional since we aren't using a nav bar
        // title = "Scores"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.allowsSelection = true
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension

        loadMatches()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // If you present fullScreen, viewWillAppear will run again after dismiss.
        // For pageSheet/overFullScreen it may not; we also reload via closures on dismiss.
        loadMatches()
    }

    @IBAction func newScoreTapped(_ sender: Any) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "NewScoreViewController") as? NewScoreViewController else {
            assertionFailure("Storyboard ID mismatch for NewScoreViewController")
            return
        }
        // Callback so we refresh when the modal is dismissed after saving/cancel
        vc.onSaved = { [weak self] in self?.loadMatches() }
        vc.onClosed = { [weak self] in self?.loadMatches() }

        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func loadMatches() {
        guard !currentUserId.isEmpty else { return }
        FirebaseService.shared.fetchMatches(for: currentUserId) { [weak self] list in
            guard let self = self else { return }
            self.matches = list                // or Array(list.reversed()) for newest first
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

    private func showEditor(for match: Match) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "EditMatchViewController") as? EditMatchViewController else {
            assertionFailure("Storyboard ID 'EditMatchViewController' not found or class mismatch.")
            return
        }
        vc.match = match
        vc.onSaved = { [weak self] in self?.loadMatches() }
        vc.onClosed = { [weak self] in self?.loadMatches() }

        // Present modally since we're not using a nav controller
        vc.modalPresentationStyle = .fullScreen   // or .pageSheet on iPad if you prefer
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

        // default while we resolve opponent
        cell.textLabel?.text = "vs. …"
        cell.detailTextLabel?.text = "You \(m.player1) – \(m.player2)"
        cell.accessoryType = .disclosureIndicator

        // Resolve opponent name asynchronously (protect against cell reuse)
        user(for: m.opponentUserId) { [weak tableView] user in
            DispatchQueue.main.async {
                guard
                    let tableView = tableView,
                    let currentIndex = tableView.indexPath(for: cell),
                    currentIndex == indexPath
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
        showEditor(for: matches[indexPath.row])
    }
}
