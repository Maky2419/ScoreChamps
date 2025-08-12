import UIKit
import FirebaseDatabase

class SignUp: UIViewController {
    private var ref: DatabaseReference!

    @IBOutlet weak var Dname: UITextField!
    @IBOutlet weak var Username: UITextField!
    @IBOutlet weak var Password: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        hideKeyboardWhenTappedAround()
        ref = Database.database().reference()
    }

    @IBAction func SignUpAccount(_ sender: Any) {
        guard
            let name = Dname.text, !name.isEmpty,
            let username = Username.text, !username.isEmpty,
            let password = Password.text, !password.isEmpty
        else { print("Fill all fields"); return }

        FirebaseService.shared.createUser(name: name, username: username, password: password) { uid in
            if let uid { print("User created \(uid)") } else { print("Sign up failed") }
        }
    }
}
