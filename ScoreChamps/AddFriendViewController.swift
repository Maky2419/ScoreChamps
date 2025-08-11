//
//  AddFriendViewController.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 8/10/25.
//

// AddFriendViewController.swift
import UIKit

final class AddFriendViewController: UIViewController {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

    private var allUsers: [UserModel] = []
    private var filtered: [UserModel] = []
    private var myUid: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add Friend"
        tableView.dataSource = self
        tableView.delegate = self
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no

        guard let me = FirebaseService.shared.currentUserId else { return }
        myUid = me

        // Load all users, filter out self & existing friends
        FirebaseService.shared.fetchAllUsers { [weak self] map in
            guard let self else { return }

            let meUser = map[me]

            // Get my existing friends as Set<String> of UIDs
            let existingFriends: Set<String> = Set(meUser?.friends.map { $0.key } ?? [])

            // Build list: everyone except me and already-friends
            self.allUsers = map
                .filter { uid, _ in uid != me && !existingFriends.contains(uid) }
                .map { $0.value }
                .sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }

            self.filtered = self.allUsers
            self.tableView.reloadData()
        }
    }
}

extension AddFriendViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }

    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let u = filtered[indexPath.row]
        let cell = tv.dequeueReusableCell(withIdentifier: "AddFriendCell") ??
                   UITableViewCell(style: .subtitle, reuseIdentifier: "AddFriendCell")
        cell.textLabel?.text = u.name
        cell.detailTextLabel?.text = "@\(u.username)"
        cell.accessoryType = .detailButton
        return cell
    }

    func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        let user = filtered[indexPath.row]
        FirebaseService.shared.sendFriendRequest(from: myUid, toUsername: user.username) { ok, err in
            let msg = ok ? "Request sent to @\(user.username)" : (err ?? "Failed")
            let a = UIAlertController(title: ok ? "Sent" : "Error", message: msg, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(a, animated: true)
        }
    }
}

extension AddFriendViewController: UISearchBarDelegate {
    func searchBar(_ sb: UISearchBar, textDidChange text: String) {
        if text.trimmingCharacters(in: .whitespaces).isEmpty { filtered = allUsers }
        else {
            filtered = allUsers.filter {
                $0.username.localizedCaseInsensitiveContains(text) ||
                $0.name.localizedCaseInsensitiveContains(text)
            }
        }
        tableView.reloadData()
    }
}
