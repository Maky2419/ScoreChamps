//
//  EditMatchViewController.swift
//  ScoreChamps
//

import UIKit

final class EditMatchViewController: UIViewController {

    // Inject this before presenting
    var match: Match!

    // Callbacks so ScoreList can refresh after dismiss
    var onSaved:  (() -> Void)?
    var onClosed: (() -> Void)?

    // MARK: - Outlets (connect these in storyboard)
    @IBOutlet weak var titleLabel: UILabel!        // shows match title (optional)
    @IBOutlet weak var opponentLabel: UILabel!

    @IBOutlet weak var yourScoreLabel: UILabel!
    @IBOutlet weak var theirScoreLabel: UILabel!

    @IBOutlet weak var yourMinusButton: UIButton!
    @IBOutlet weak var yourPlusButton: UIButton!
    @IBOutlet weak var theirMinusButton: UIButton!
    @IBOutlet weak var theirPlusButton: UIButton!

    // In-view buttons (no nav bar)
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!     // wire this up in storyboard

    // MARK: - State
    private var yourScore: Int = 0
    private var theirScore: Int = 0

    private var currentUserId: String {
        FirebaseService.shared.currentUserId ?? ""
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        guard match != nil else {
            assertionFailure("EditMatchViewController requires match")
            dismiss(animated: true)
            return
        }

        // Prefill scores from the match
        yourScore  = match.player1
        theirScore = match.player2
        updateScoreLabels()

        // Title label (optional)
        if let t = match.title, !t.isEmpty {
            titleLabel.text = t
        } else {
            titleLabel.text = "Match"
        }

        // Opponent label
        opponentLabel.text = "vs. …"
        FirebaseService.shared.fetchUser(byUserId: match.opponentUserId) { [weak self] user in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let u = user {
                    let name = !u.name.isEmpty ? u.name : (!u.username.isEmpty ? "@\(u.username)" : u.userId)
                    self.opponentLabel.text = "vs. \(name)"
                } else {
                    self.opponentLabel.text = "vs. (unknown)"
                }
            }
        }

        // Buttons text / style (optional)
        saveButton.setTitle("Save", for: .normal)
        cancelButton.setTitle("Close", for: .normal)
        deleteButton.setTitle("Delete", for: .normal)
        deleteButton.setTitleColor(.systemRed, for: .normal)
    }

    private func updateScoreLabels() {
        yourScoreLabel.text  = "\(yourScore)"
        theirScoreLabel.text = "\(theirScore)"
        yourMinusButton.isEnabled  = yourScore  > 0
        theirMinusButton.isEnabled = theirScore > 0
    }

    // MARK: - +/- actions
    @IBAction func yourMinusTapped(_ sender: UIButton) {
        if yourScore > 0 { yourScore -= 1; updateScoreLabels() }
    }
    @IBAction func yourPlusTapped(_ sender: UIButton) {
        yourScore += 1; updateScoreLabels()
    }
    @IBAction func theirMinusTapped(_ sender: UIButton) {
        if theirScore > 0 { theirScore -= 1; updateScoreLabels() }
    }
    @IBAction func theirPlusTapped(_ sender: UIButton) {
        theirScore += 1; updateScoreLabels()
    }

    // MARK: - Save / Close
    @IBAction func saveTapped(_ sender: UIButton) {
        guard !currentUserId.isEmpty else { return }
        FirebaseService.shared.updateMatch(
            for: currentUserId,
            matchId: match.matchId,
            p1: yourScore,
            p2: theirScore
        ) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if ok {
                    self.onSaved?()
                    self.dismiss(animated: true)
                } else {
                    let a = UIAlertController(title: "Error", message: "Could not save score.", preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(a, animated: true)
                }
            }
        }
    }

    @IBAction func cancelTapped(_ sender: UIButton) {
        onClosed?()
        dismiss(animated: true)
    }

    // MARK: - Delete flow = send request (opponent must accept)
    @IBAction func deleteTapped(_ sender: UIButton) {
        guard !currentUserId.isEmpty else { return }

        let alert = UIAlertController(
            title: "Request Deletion?",
            message: "This will notify your opponent. The match will be deleted only after they accept.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send Request", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            FirebaseService.shared.requestDeleteMatch(
                myUid: self.currentUserId,
                myMatchId: self.match.matchId
            ) { ok, msg in
                DispatchQueue.main.async {
                    if ok {
                        let a = UIAlertController(
                            title: "Request Sent",
                            message: "We’ll delete the match once your opponent accepts.",
                            preferredStyle: .alert
                        )
                        a.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                            // You might keep the editor open or close it—closing keeps UX simple
                            self.onSaved?() // optional refresh when returning
                            self.dismiss(animated: true)
                        }))
                        self.present(a, animated: true)
                    } else {
                        let a = UIAlertController(title: "Error", message: msg ?? "Could not send request.", preferredStyle: .alert)
                        a.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(a, animated: true)
                    }
                }
            }
        }))
        present(alert, animated: true)
    }
}
