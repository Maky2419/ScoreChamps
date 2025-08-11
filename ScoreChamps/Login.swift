import UIKit
import Firebase
import FirebaseDatabase

class Login: UIViewController {
    @IBOutlet weak var UsernamesText: UITextField!
    @IBOutlet weak var PasswordText: UITextField!

    private var users: [String: UserModel] = [:] // uid -> user

    override func viewDidLoad() {
        super.viewDidLoad()
        hideKeyboardWhenTappedAround()
        FirebaseService.shared.fetchAllUsers { [weak self] map in
            self?.users = map
            print("Loaded users: \(map.count)")
        }
    }

    @IBAction func LoginBtnActivated(_ sender: Any) {
        guard let u = UsernamesText.text, let p = PasswordText.text, !u.isEmpty, !p.isEmpty else {
            alert("Error", "Please enter both username and password.")
            return
        }

        if let hit = users.first(where: { $0.value.username == u && $0.value.password == p }) {
            FirebaseService.shared.currentUserId = hit.key
            print("Login success for \(hit.value.username). Friends=\(hit.value.friends.count)")
            performSegue(withIdentifier: "goToNext", sender: self) // to ScoreList or Home
        } else {
            alert("Failed", "Invalid username or password.")
        }
    }

    private func alert(_ title: String, _ msg: String) {
        let a = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
