import UIKit

class Score: UIViewController {
    @IBOutlet weak var opponentUsernameField: UITextField!
    @IBOutlet weak var yourScoreField: UITextField!
    @IBOutlet weak var theirScoreField: UITextField!
    @IBOutlet weak var saveButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "New Match"
    }

    @IBAction func saveTapped(_ sender: Any) {
        guard
            let me = FirebaseService.shared.currentUserId,
            let uname = opponentUsernameField.text, !uname.isEmpty,
            let p1Text = yourScoreField.text, let p1 = Int(p1Text),
            let p2Text = theirScoreField.text, let p2 = Int(p2Text)
        else { alert("Missing info", "Fill all fields correctly."); return }

        FirebaseService.shared.fetchUser(byUsername: uname) { uid, _ in
            guard let opponentUid = uid else { self.alert("Not found", "No user with that username."); return }
            FirebaseService.shared.addMatch(for: me, opponentUid: opponentUid, p1: p1, p2: p2) { ok in
                if ok { self.navigationController?.popViewController(animated: true) }
                else { self.alert("Error", "Could not save match.") }
            }
        }
    }

    private func alert(_ t: String, _ m: String) {
        let a = UIAlertController(title: t, message: m, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
