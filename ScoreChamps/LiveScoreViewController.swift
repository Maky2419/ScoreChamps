//
//  LiveScoreViewController.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 8/12/25.
//

import UIKit

final class LiveScoreViewController: UIViewController {

    // Injected before push
    var myUid: String = ""
    var opponentUid: String = ""
    var opponentUsername: String = ""
    var opponentDisplayName: String = ""

    // MARK: - Outlets (Storyboard)
    // Create labels and buttons and connect these outlets / actions.
    @IBOutlet weak var youScoreLabel: UILabel!
    @IBOutlet weak var oppScoreLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!

    private var youScore = 0
    private var oppScore = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Live Score"
        titleLabel.text = "You vs \(opponentDisplayName.isEmpty ? "@\(opponentUsername)" : opponentDisplayName)"
        updateLabels()
    }

    private func updateLabels() {
        youScoreLabel.text = "\(youScore)"
        oppScoreLabel.text = "\(oppScore)"
    }

    // MARK: - You (+1 / +5 / +10)
    @IBAction func youPlus1(_ sender: Any)  { youScore += 1;  updateLabels() }
    @IBAction func youPlus5(_ sender: Any)  { youScore += 5;  updateLabels() }
    @IBAction func youPlus10(_ sender: Any) { youScore += 10; updateLabels() }

    // MARK: - Opponent (+1 / +5 / +10)
    @IBAction func oppPlus1(_ sender: Any)  { oppScore += 1;  updateLabels() }
    @IBAction func oppPlus5(_ sender: Any)  { oppScore += 5;  updateLabels() }
    @IBAction func oppPlus10(_ sender: Any) { oppScore += 10; updateLabels() }

    // Optional: minus buttons
    @IBAction func youMinus1(_ sender: Any)  { youScore = max(0, youScore-1); updateLabels() }
    @IBAction func oppMinus1(_ sender: Any)  { oppScore = max(0, oppScore-1); updateLabels() }

    // Save on both sides
    @IBAction func saveAndFinish(_ sender: Any) {
        guard !myUid.isEmpty, !opponentUid.isEmpty else {
            toast("Missing user IDs.")
            return
        }

        FirebaseService.shared.addMatchBothSides(myUid: myUid,
                                                 opponentUid: opponentUid,
                                                 myScore: youScore,
                                                 oppScore: oppScore) { [weak self] ok, err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if ok {
                    self.navigationController?.popViewController(animated: true)
                } else {
                    self.toast(err ?? "Could not save match.")
                }
            }
        }
    }

    private func toast(_ msg: String) {
        let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
