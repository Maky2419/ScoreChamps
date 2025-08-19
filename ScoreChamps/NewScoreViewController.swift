//
//  NewScoreViewController.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 8/19/25.
//

import UIKit

protocol NewScoreDelegate: AnyObject {
    func newScoreViewController(_ vc: NewScoreViewController, didCreate score: ScoreModel)
}

final class NewScoreViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: NewScoreDelegate?
    private var friends: [UserModel] = []

    // Read the latest each time; don’t cache.
    private var currentUserId: String {
        FirebaseService.shared.currentUserId ?? ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose Opponent"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .systemBackground

        loadFriends()
    }

    // MARK: - Data
    private func loadFriends() {
        let uid = currentUserId
        guard !uid.isEmpty else {
            print("❗️No currentUserId in NewScoreVC")
            return
        }

        FirebaseService.shared.fetchFriends(for: uid) { [weak self] users in
            DispatchQueue.main.async {
                self?.friends = users
                self?.tableView.reloadData()
            }
        }
    }

    // MARK: - Create match
    private func promptForScores(opponent: UserModel) {
        let label: String = !opponent.name.isEmpty
            ? opponent.name
            : (!opponent.username.isEmpty ? "@\(opponent.username)" : opponent.userId)

        let alert = UIAlertController(
            title: "New Score vs \(label)",
            message: "Enter the final scores",
            preferredStyle: .alert
        )

        alert.addTextField { tf in
            tf.placeholder = "Your score"
            tf.keyboardType = UIKeyboardType.numberPad
        }
        alert.addTextField { tf in
            tf.placeholder = "\(label)'s score"
            tf.keyboardType = UIKeyboardType.numberPad
        }

        // Cancel -> close alert AND pop back
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            self?.popSelf()
        }))

        // Save -> write both sides; on success, pop back
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard
                let self = self,
                let yoursText = alert.textFields?.first?.text,
                let theirsText = alert.textFields?.last?.text,
                let yourScore = Int(yoursText),
                let theirScore = Int(theirsText),
                !self.currentUserId.isEmpty
            else { return }

            FirebaseService.shared.addMatchBothSides(
                myUid: self.currentUserId,
                opponentUid: opponent.userId,
                myScore: yourScore,
                oppScore: theirScore
            ) { ok, err in
                DispatchQueue.main.async {
                    if ok {
                        // Optional: notify delegate if you use it elsewhere
                        // self.delegate?.newScoreViewController(self, didCreate: ...)
                        self.popSelf()
                    } else {
                        let a = UIAlertController(title: "Error", message: err ?? "Failed to save match.", preferredStyle: .alert)
                        a.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(a, animated: true)
                    }
                }
            }
        }))

        present(alert, animated: true)
    }

    /// Pops to previous screen, or dismisses if presented modally.
    private func popSelf() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - UITableView
extension NewScoreViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        friends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Ensure Subtitle style when no prototype exists.
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "FriendCell")

        let u = friends[indexPath.row]
        let primary: String = !u.name.isEmpty ? u.name
            : (!u.username.isEmpty ? "@\(u.username)" : u.userId)
        let secondary: String = !u.username.isEmpty ? "@\(u.username)" : "ID: \(u.userId)"

        cell.textLabel?.text = primary
        cell.detailTextLabel?.text = secondary
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        promptForScores(opponent: friends[indexPath.row])
    }
}
