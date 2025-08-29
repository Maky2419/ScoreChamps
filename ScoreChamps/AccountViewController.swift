//
//  AccountViewController.swift
//  ScoreChamps
//

import UIKit
import FirebaseDatabase

final class AccountViewController: UIViewController {

    // MARK: - UI
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()

    private let nameTitle = UILabel()
    private let nameValue = UILabel()

    private let userTitle = UILabel()
    private let userValue = UILabel()

    private let matchesTitle = UILabel()
    private let matchesValue = UILabel()

    private let friendsTitle = UILabel()
    private let friendsValue = UILabel()

    private let changePasswordButton = UIButton(type: .system)
    private let deleteAccountButton  = UIButton(type: .system)

    // MARK: - Shortcuts
    private var uid: String { FirebaseService.shared.currentUserId ?? "" }
    private var db: DatabaseReference { FirebaseService.shared.ref }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureUI()
        loadProfile()
        loadStats()
    }

    // MARK: - UI Setup
    private func configureUI() {
        // Header row
        backButton.setTitle("Back", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        titleLabel.text = "Account"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [backButton, UIView(), titleLabel, UIView()])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8

        // Info rows
        [nameTitle, userTitle, matchesTitle, friendsTitle].forEach {
            $0.font = .systemFont(ofSize: 15, weight: .regular)
            $0.textColor = .secondaryLabel
        }
        nameTitle.text = "Display Name"
        userTitle.text = "Username"
        matchesTitle.text = "Total Matches"
        friendsTitle.text = "Friends"

        [nameValue, userValue, matchesValue, friendsValue].forEach {
            $0.font = .systemFont(ofSize: 18, weight: .semibold)
            $0.textColor = .label
            $0.numberOfLines = 1
        }

        let nameRow    = row(title: nameTitle, value: nameValue)
        let userRow    = row(title: userTitle, value: userValue)
        let matchesRow = row(title: matchesTitle, value: matchesValue)
        let friendsRow = row(title: friendsTitle, value: friendsValue)

        // Buttons
        stylePrimary(changePasswordButton, title: "Change Password")
        changePasswordButton.addTarget(self, action: #selector(changePasswordTapped), for: .touchUpInside)

        styleDestructive(deleteAccountButton, title: "Delete Account")
        deleteAccountButton.addTarget(self, action: #selector(deleteAccountTapped), for: .touchUpInside)

        // Main stack
        let stack = UIStackView(arrangedSubviews: [
            header,
            spacer(12),
            nameRow,
            userRow,
            matchesRow,
            friendsRow,
            spacer(20),
            changePasswordButton,
            spacer(8),
            deleteAccountButton
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }

    private func row(title: UILabel, value: UILabel) -> UIStackView {
        let s = UIStackView(arrangedSubviews: [title, UIView(), value])
        s.axis = .horizontal
        s.alignment = .center
        return s
    }

    private func stylePrimary(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    }

    private func styleDestructive(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(.systemRed, for: .normal)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
    }

    private func spacer(_ h: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: h).isActive = true
        return v
    }

    // MARK: - Data
    private func loadProfile() {
        guard !uid.isEmpty else { return }
        FirebaseService.shared.fetchUser(byUserId: uid) { [weak self] u in
            DispatchQueue.main.async {
                self?.nameValue.text = u?.name.isEmpty == false ? u?.name : "—"
                self?.userValue.text = u?.username.isEmpty == false ? u?.username : "—"
            }
        }
    }

    private func loadStats() {
        guard !uid.isEmpty else { return }
        FirebaseService.shared.fetchMatches(for: uid) { [weak self] list in
            DispatchQueue.main.async { self?.matchesValue.text = "\(list.count)" }
        }
        FirebaseService.shared.fetchFriends(for: uid) { [weak self] friends in
            DispatchQueue.main.async { self?.friendsValue.text = "\(friends.count)" }
        }
    }

    // MARK: - Actions
    @objc private func backTapped() {
        dismiss(animated: true) // return to ScoreList
    }

    @objc private func changePasswordTapped() {
        guard !uid.isEmpty else { return }

        let alert = UIAlertController(title: "Change Password",
                                      message: "Enter a new password.",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "New password"
            tf.isSecureTextEntry = true
        }
        alert.addTextField { tf in
            tf.placeholder = "Confirm password"
            tf.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let p1 = alert.textFields?.first?.text ?? ""
            let p2 = alert.textFields?.last?.text ?? ""

            guard !p1.isEmpty, p1 == p2 else {
                self.toast("Passwords don’t match.")
                return
            }

            // Are you sure?
            let confirm = UIAlertController(title: "Confirm",
                                            message: "Are you sure you want to change your password?",
                                            preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "No", style: .cancel))
            confirm.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
                // Update `/Accounts/{uid}/password`
                self.db.child("Accounts").child(self.uid).child("password")
                    .setValue(p1) { err, _ in
                        DispatchQueue.main.async {
                            if let err = err {
                                self.toast("Failed: \(err.localizedDescription)")
                            } else {
                                self.toast("Password changed.")
                                // ✅ Return to ScoreList (do NOT log out)
                                self.dismiss(animated: true)
                            }
                        }
                    }
            }))
            self.present(confirm, animated: true)
        }))

        present(alert, animated: true)
    }

    @objc private func deleteAccountTapped() {
        guard !uid.isEmpty else { return }

        let a = UIAlertController(title: "Delete Account",
                                  message: "This will permanently remove your account and local session.",
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        a.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.confirmDelete()
        }))
        present(a, animated: true)
    }

    private func confirmDelete() {
        let b = UIAlertController(title: "Are you absolutely sure?",
                                  message: "This action cannot be undone.",
                                  preferredStyle: .alert)
        b.addAction(UIAlertAction(title: "No", style: .cancel))
        b.addAction(UIAlertAction(title: "Yes, delete", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            // Remove your /Accounts/{uid} node.
            self.db.child("Accounts").child(self.uid).removeValue { err, _ in
                DispatchQueue.main.async {
                    if let err = err {
                        self.toast("Failed: \(err.localizedDescription)")
                    } else {
                        // Clear session & go to login
                        AppRouter.goToLogin(resetSession: true)
                    }
                }
            }
        }))
        present(b, animated: true)
    }

    // MARK: - Helpers
    private func toast(_ msg: String) {
        let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
