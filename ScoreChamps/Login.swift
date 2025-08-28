import UIKit
import Firebase
import FirebaseDatabase

final class Login: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var UsernamesText: UITextField!
    @IBOutlet weak var PasswordText: UITextField!

    private var users: [String: UserModel] = [:] // uid -> user
    private var passwordRaw: String = ""         // real password (we display "*" in the field)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        hideKeyboardWhenTappedAround()

        // Username niceties
        UsernamesText.autocorrectionType = .no
        UsernamesText.autocapitalizationType = .none
        UsernamesText.returnKeyType = .next
        UsernamesText.delegate = self

        // Password: show literal "*" instead of secure dots
        PasswordText.delegate = self
        PasswordText.text = ""
        PasswordText.autocorrectionType = .no
        PasswordText.autocapitalizationType = .none
        PasswordText.textContentType = .password
        PasswordText.clearButtonMode = .whileEditing
        PasswordText.returnKeyType = .done
        // IMPORTANT: do NOT set isSecureTextEntry here, we’re drawing "*" ourselves.

        // Preload users so local validation is instant
        FirebaseService.shared.fetchAllUsers { [weak self] map in
            self?.users = map
            print("Loaded users: \(map.count)")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Auto-skip login if we already have a session
        if let uid = FirebaseService.shared.currentUserId, !uid.isEmpty {
            view.endEditing(true)
            performSegue(withIdentifier: "goToNext", sender: self) // Login -> ScoreList
        }
    }

    // MARK: - Actions
    @IBAction func LoginBtnActivated(_ sender: Any) {
        let u = (UsernamesText.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let p = passwordRaw

        guard !u.isEmpty, !p.isEmpty else {
            alert("Error", "Please enter both username and password.")
            return
        }

        if let hit = users.first(where: { $0.value.username == u && $0.value.password == p }) {
            // Persist session for next launch
            FirebaseService.shared.currentUserId = hit.key
            print("Login success for \(hit.value.username). Friends=\(hit.value.friends.count)")
            view.endEditing(true)
            performSegue(withIdentifier: "goToNext", sender: self) // to ScoreList
        } else {
            alert("Failed", "Invalid username or password.")
        }
    }

    // MARK: - UITextFieldDelegate (asterisk masking + return behavior)
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        // Only custom-handle the password field
        guard textField === PasswordText else { return true }

        // Update the real password using the proposed edit range
        let current = passwordRaw
        if let r = Range(range, in: current) {
            passwordRaw = current.replacingCharacters(in: r, with: string)
        } else {
            // Fallback (rare): append input
            passwordRaw.append(contentsOf: string)
        }

        // Show '*' with same count as real password
        textField.text = String(repeating: "*", count: passwordRaw.count)

        // Keep cursor at end for nicer UX
        if let end = textField.position(from: textField.beginningOfDocument, offset: passwordRaw.count) {
            textField.selectedTextRange = textField.textRange(from: end, to: end)
        }

        // We manually updated the text; prevent default insertion
        return false
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if textField === PasswordText { passwordRaw = "" }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === UsernamesText {
            PasswordText.becomeFirstResponder()
        } else if textField === PasswordText {
            textField.resignFirstResponder()
            LoginBtnActivated(textField)
        }
        return true
    }

    // MARK: - Helpers
    private func alert(_ title: String, _ msg: String) {
        let a = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

