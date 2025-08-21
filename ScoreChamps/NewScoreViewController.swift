//
//  NewScoreViewController.swift
//  ScoreChamps
//

import UIKit

protocol NewScoreDelegate: AnyObject {
    func newScoreViewController(_ vc: NewScoreViewController, didCreate score: ScoreModel)
}

final class NewScoreViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: NewScoreDelegate?
    var onSaved: (() -> Void)?   // called after a successful save
    var onClosed: (() -> Void)?  // called when screen is closed (cancel/back)

    private var friends: [UserModel] = []

    private var currentUserId: String {
        FirebaseService.shared.currentUserId ?? ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .systemBackground

        loadFriends()
    }

    // Optional: hook a "Close" UIButton in storyboard to this
    @IBAction func closeTapped(_ sender: Any) {
        onClosed?()
        dismiss(animated: true)
    }

    private func loadFriends() {
        let uid = currentUserId
        guard !uid.isEmpty else { return }
        FirebaseService.shared.fetchFriends(for: uid) { [weak self] users in
            DispatchQueue.main.async {
                self?.friends = users
                self?.tableView.reloadData()
            }
        }
    }

    private func promptForScores(opponent: UserModel) {
        let label: String = !opponent.name.isEmpty
            ? opponent.name
            : (!opponent.username.isEmpty ? "@\(opponent.username)" : opponent.userId)

        let alert = UIAlertController(
            title: "New Score vs \(label)",
            message: "Add a title and scores",
            preferredStyle: .alert
        )

        // 1) Title (optional)
        alert.addTextField { tf in
            tf.placeholder = "Title (optional)"
            tf.autocapitalizationType = .words
            tf.returnKeyType = .done
        }

        // 2) Your score
        alert.addTextField { tf in
            tf.placeholder = "Your score"
            tf.keyboardType = .numberPad
        }

        // 3) Their score
        alert.addTextField { tf in
            tf.placeholder = "\(label)'s score"
            tf.keyboardType = .numberPad
        }

        // Cancel closes (since no nav controller)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            self?.onClosed?()
            self?.dismiss(animated: true)
        }))

        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard
                let self = self,
                let titleText = alert.textFields?[0].text,                      // Title (optional)
                let yoursText = alert.textFields?[1].text,
                let theirsText = alert.textFields?[2].text,
                let yourScore  = Int(yoursText),
                let theirScore = Int(theirsText),
                !self.currentUserId.isEmpty
            else { return }

            // Save to both players under /Accounts/.../matches (where ScoreList reads)
            FirebaseService.shared.addMatchBothSides(
                myUid: self.currentUserId,
                opponentUid: opponent.userId,
                myScore: yourScore,
                oppScore: theirScore,
                title: titleText.isEmpty ? nil : titleText                      // <-- NEW
            ) { ok, err in
                DispatchQueue.main.async {
                    if ok {
                        self.onSaved?()
                        self.dismiss(animated: true)
                    } else {
                        let a = UIAlertController(title: "Error", message: err ?? "Failed to save match.", preferredStyle: .alert)
                        a.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(a, animated: true)
                    }
                }
            }

            // (Optional) If you also keep a global /Scores history:
            // FirebaseService.shared.createScore(player1Id: self.currentUserId, player2Id: opponent.userId, player1Score: yourScore, player2Score: theirScore, title: titleText.isEmpty ? nil : titleText) { _ in }
        }))

        present(alert, animated: true)
    }
}

extension NewScoreViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        friends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Subtitle style if no prototype cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "FriendCell")

        let u = friends[indexPath.row]
        let primary: String = !u.name.isEmpty ? u.name : (!u.username.isEmpty ? "@\(u.username)" : u.userId)
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
