//
//  SelectOpponentViewController.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 8/12/25.
//

import UIKit

/// Simple row model
struct OpponentRow {
    let uid: String
    let username: String
    let displayName: String
}

/// Used when returning from ScoreList so we can highlight/auto-open that opponent
struct OpponentPref {
    let uid: String
    let username: String
}

final class SelectOpponentViewController: UIViewController {

    // MARK: - Outlets (Storyboard)
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

    private var all: [OpponentRow] = []
    private var filtered: [OpponentRow] = []

    private var myUid: String = ""

    // MARK: - Preselect support (set by ScoreList before showing this VC)
    var preselectOpponent: OpponentPref?
    /// If true we’ll immediately open LiveScore for the preselected opponent after loading.
    var autoOpenPreselected = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Opponent"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag

        searchBar.delegate = self

        guard let me = FirebaseService.shared.currentUserId else {
            alert("Not logged in", "Please log in again.")
            return
        }
        myUid = me
        loadFriends()
    }

    private func loadFriends() {
        // Friends are stored as [uid: username]
        FirebaseService.shared.fetchUser(byUserId: myUid) { [weak self] user in
            guard let self = self, let user = user else { return }

            var rows: [OpponentRow] = []
            let group = DispatchGroup()

            for (uid, username) in user.friends {
                group.enter()
                FirebaseService.shared.fetchUser(byUserId: uid) { u in
                    let name = u?.name ?? username
                    rows.append(OpponentRow(uid: uid, username: username, displayName: name))
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.all = rows.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                self.filtered = self.all
                self.tableView.reloadData()
                self.updateEmptyState()

                // If we were asked to preselect/auto-open an opponent, do it now.
                if let pref = self.preselectOpponent,
                   let idx = self.filtered.firstIndex(where: { $0.uid == pref.uid }) {
                    let ip = IndexPath(row: idx, section: 0)
                    self.tableView.scrollToRow(at: ip, at: .middle, animated: true)
                    if self.autoOpenPreselected {
                        // mimic a tap
                        self.tableView(self.tableView, didSelectRowAt: ip)
                    }
                }
            }
        }
    }

    private func updateEmptyState() {
        if filtered.isEmpty {
            let l = UILabel()
            l.text = "No friends yet.\nAdd a friend to start a match."
            l.textAlignment = .center
            l.numberOfLines = 0
            l.textColor = .secondaryLabel
            l.font = .systemFont(ofSize: 16)
            tableView.backgroundView = l
            tableView.separatorStyle = .none
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }
    }

    private func alert(_ t: String, _ m: String) {
        let a = UIAlertController(title: t, message: m, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // Small helper so we can reuse push logic
    private func pushLiveScore(for opp: OpponentRow) {
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "LiveScoreVC") as! LiveScoreViewController
        vc.myUid = myUid
        vc.opponentUid = opp.uid
        vc.opponentUsername = opp.username
        vc.opponentDisplayName = opp.displayName

        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .pageSheet
            present(nav, animated: true)
        }
    }
}

extension SelectOpponentViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        updateEmptyState()
        return filtered.count
    }

    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "OpponentCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "OpponentCell")
        let row = filtered[indexPath.row]
        cell.textLabel?.text = row.displayName
        cell.detailTextLabel?.text = "@\(row.username)"
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        let opp = filtered[indexPath.row]
        print("Tapped:", opp.username)
        pushLiveScore(for: opp)
    }
}

extension SelectOpponentViewController: UISearchBarDelegate {
    func searchBar(_ sb: UISearchBar, textDidChange text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        filtered = q.isEmpty ? all : all.filter {
            $0.displayName.localizedCaseInsensitiveContains(q) ||
            $0.username.localizedCaseInsensitiveContains(q)
        }
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ sb: UISearchBar) {
        sb.resignFirstResponder()
    }
}
