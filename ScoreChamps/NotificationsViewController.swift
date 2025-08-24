//
//  NotificationsViewController.swift
//  ScoreChamps
//

import UIKit
import FirebaseDatabase

// MARK: - Inline action cell (Friend Requests)
final class InviteCell: UITableViewCell {
    let approve = UIButton(type: .system)
    let reject  = UIButton(type: .system)

    var onApprove: (() -> Void)?
    var onReject:  (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        textLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        detailTextLabel?.textColor = .secondaryLabel
        commonInit()
    }

    private func commonInit() {
        selectionStyle = .none
        textLabel?.numberOfLines = 1
        detailTextLabel?.numberOfLines = 2

        approve.setTitle("Approve", for: .normal)
        reject.setTitle("Reject", for: .normal)

        approve.addTarget(self, action: #selector(tapApprove), for: .touchUpInside)
        reject.addTarget(self, action: #selector(tapReject), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [approve, reject])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor)
        ])
    }

    func configure(name: String, username: String) {
        textLabel?.text = name
        detailTextLabel?.text = "@\(username) sent you a friend request"
    }

    @objc private func tapApprove() { onApprove?() }
    @objc private func tapReject()  { onReject?() }
}

// MARK: - Inline action cell (Delete Requests)
final class DeleteRequestCell: UITableViewCell {
    let accept = UIButton(type: .system)
    let decline = UIButton(type: .system)

    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        selectionStyle = .none
        textLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        detailTextLabel?.textColor = .secondaryLabel
        textLabel?.numberOfLines = 1
        detailTextLabel?.numberOfLines = 2

        accept.setTitle("Accept", for: .normal)
        decline.setTitle("Decline", for: .normal)
        decline.setTitleColor(.systemRed, for: .normal)

        accept.addTarget(self, action: #selector(tapAccept), for: .touchUpInside)
        decline.addTarget(self, action: #selector(tapDecline), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [accept, decline])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor)
        ])
    }

    /// Call after you resolve the sender’s display (or pass a placeholder first).
    func configure(title: String?, senderDisplay: String) {
        if let t = title, !t.isEmpty {
            textLabel?.text = "Delete “\(t)”?"
        } else {
            textLabel?.text = "Delete this match?"
        }
        detailTextLabel?.text = "\(senderDisplay) requested deletion"
    }

    @objc private func tapAccept()  { onAccept?() }
    @objc private func tapDecline() { onDecline?() }
}

// MARK: - Notifications VC (Friend + Delete requests)
final class NotificationsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private enum Section: Int, CaseIterable {
        case deleteRequests = 0
        case friendRequests = 1

        var title: String {
            switch self {
            case .deleteRequests: return "Delete Requests"
            case .friendRequests: return "Friend Requests"
            }
        }
    }

    // Data
    private var friendRequests: [FriendRequest] = []
    private var deleteRequests: [DeleteRequest] = []

    // Observers
    private var friendHandle: DatabaseHandle?
    private var deleteHandle: DatabaseHandle?

    // Cache for user displays (for delete requests’ sender)
    private var userCache: [String: UserModel] = [:]

    private var myUid: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 80
        tableView.tableFooterView = UIView()

        // Register cells (even if you use prototypes, this is safe)
        tableView.register(InviteCell.self, forCellReuseIdentifier: "InviteCell")
        tableView.register(DeleteRequestCell.self, forCellReuseIdentifier: "DeleteCell")

        guard let me = FirebaseService.shared.currentUserId else {
            setEmptyStateIfNeeded()
            return
        }
        myUid = me

        // Observe Friend Requests
        friendHandle = FirebaseService.shared.observeIncomingRequests(for: me) { [weak self] list in
            guard let self = self else { return }
            self.friendRequests = list
            self.setEmptyStateIfNeeded()
            self.tableView.reloadData()
        }

        // Observe Delete Requests
        deleteHandle = FirebaseService.shared.observeIncomingDeleteRequests(for: me) { [weak self] list in
            guard let self = self else { return }
            self.deleteRequests = list
            self.setEmptyStateIfNeeded()
            self.tableView.reloadData()
        }
    }

    deinit {
        if let h = friendHandle, !myUid.isEmpty {
            FirebaseService.shared.removeIncomingFriendRequestsObserver(h, for: myUid)
        }
        if let h = deleteHandle, !myUid.isEmpty {
            FirebaseService.shared.removeIncomingDeleteRequestsObserver(h, for: myUid)
        }
    }

    // MARK: - Actions: Friend Requests
    private func acceptFriend(_ req: FriendRequest, at indexPath: IndexPath) {
        FirebaseService.shared.acceptFriendRequest(myUid: myUid, from: req) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if ok, self.friendRequests.indices.contains(indexPath.row) {
                    self.friendRequests.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    self.setEmptyStateIfNeeded()
                } else {
                    self.toast("Could not accept request.")
                }
            }
        }
    }

    private func declineFriend(_ req: FriendRequest, at indexPath: IndexPath) {
        FirebaseService.shared.declineFriendRequest(myUid: myUid, from: req.fromUid) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if ok, self.friendRequests.indices.contains(indexPath.row) {
                    self.friendRequests.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    self.setEmptyStateIfNeeded()
                } else {
                    self.toast("Could not decline request.")
                }
            }
        }
    }

    // MARK: - Actions: Delete Requests
    private func acceptDelete(_ req: DeleteRequest, at indexPath: IndexPath) {
        FirebaseService.shared.respondToDeleteRequest(
            responderUid: myUid,
            requestId: req.id,
            accept: true
        ) { [weak self] ok, msg in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if ok, self.deleteRequests.indices.contains(indexPath.row) {
                    self.deleteRequests.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    self.setEmptyStateIfNeeded()
                } else {
                    self.toast(msg ?? "Could not accept delete request.")
                }
            }
        }
    }

    private func declineDelete(_ req: DeleteRequest, at indexPath: IndexPath) {
        FirebaseService.shared.respondToDeleteRequest(
            responderUid: myUid,
            requestId: req.id,
            accept: false
        ) { [weak self] ok, msg in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if ok, self.deleteRequests.indices.contains(indexPath.row) {
                    self.deleteRequests.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    self.setEmptyStateIfNeeded()
                } else {
                    self.toast(msg ?? "Could not decline delete request.")
                }
            }
        }
    }

    // MARK: - Helpers
    private func senderDisplay(for uid: String, completion: @escaping (String) -> Void) {
        if let cached = userCache[uid] {
            completion(cached.name.isEmpty ? (cached.username.isEmpty ? cached.userId : "@\(cached.username)") : cached.name)
            return
        }
        FirebaseService.shared.fetchUser(byUserId: uid) { [weak self] user in
            guard let self = self, let u = user else { completion(uid); return }
            self.userCache[uid] = u
            completion(u.name.isEmpty ? (u.username.isEmpty ? u.userId : "@\(u.username)") : u.name)
        }
    }

    private func setEmptyStateIfNeeded() {
        if friendRequests.isEmpty && deleteRequests.isEmpty {
            tableView.setEmptyMessage("No notifications yet")
        } else {
            tableView.restore()
        }
    }

    private func toast(_ msg: String) {
        let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

// MARK: - Table
extension NotificationsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sec = Section(rawValue: section) else { return nil }
        switch sec {
        case .deleteRequests:
            return deleteRequests.isEmpty ? nil : sec.title
        case .friendRequests:
            return friendRequests.isEmpty ? nil : sec.title
        }
    }

    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        switch sec {
        case .deleteRequests: return deleteRequests.count
        case .friendRequests: return friendRequests.count
        }
    }

    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sec = Section(rawValue: indexPath.section) else { return UITableViewCell() }

        switch sec {
        case .friendRequests:
            let cell = tv.dequeueReusableCell(withIdentifier: "InviteCell") as? InviteCell
                ?? InviteCell(style: .subtitle, reuseIdentifier: "InviteCell")

            let r = friendRequests[indexPath.row]
            cell.configure(name: r.fromName, username: r.fromUsername)

            // Use cell's current indexPath at tap time
            cell.onApprove = { [weak self, weak tv, weak cell] in
                guard let self, let tv, let cell, let ip = tv.indexPath(for: cell) else { return }
                self.acceptFriend(self.friendRequests[ip.row], at: ip)
            }
            cell.onReject = { [weak self, weak tv, weak cell] in
                guard let self, let tv, let cell, let ip = tv.indexPath(for: cell) else { return }
                self.declineFriend(self.friendRequests[ip.row], at: ip)
            }
            return cell

        case .deleteRequests:
            let cell = tv.dequeueReusableCell(withIdentifier: "DeleteCell") as? DeleteRequestCell
                ?? DeleteRequestCell(style: .subtitle, reuseIdentifier: "DeleteCell")

            let req = deleteRequests[indexPath.row]
            // Set a quick placeholder first
            cell.configure(title: req.title, senderDisplay: "…")
            // Resolve sender name asynchronously & update only if still visible
            senderDisplay(for: req.fromUid) { [weak tv] display in
                DispatchQueue.main.async {
                    guard let tv = tv,
                          let visible = tv.cellForRow(at: indexPath) as? DeleteRequestCell else { return }
                    visible.configure(title: req.title, senderDisplay: display)
                }
            }

            cell.onAccept = { [weak self, weak tv, weak cell] in
                guard let self, let tv, let cell, let ip = tv.indexPath(for: cell) else { return }
                self.acceptDelete(self.deleteRequests[ip.row], at: ip)
            }
            cell.onDecline = { [weak self, weak tv, weak cell] in
                guard let self, let tv, let cell, let ip = tv.indexPath(for: cell) else { return }
                self.declineDelete(self.deleteRequests[ip.row], at: ip)
            }
            return cell
        }
    }

    // Optional: swipe actions
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {

        guard let sec = Section(rawValue: indexPath.section) else { return nil }

        switch sec {
        case .friendRequests:
            let approve = UIContextualAction(style: .normal, title: "Approve") { [weak self] _, _, done in
                guard let self else { return }
                let r = self.friendRequests[indexPath.row]
                self.acceptFriend(r, at: indexPath)
                done(true)
            }
            approve.backgroundColor = .systemGreen
            approve.image = UIImage(systemName: "checkmark")

            let reject = UIContextualAction(style: .destructive, title: "Reject") { [weak self] _, _, done in
                guard let self else { return }
                let r = self.friendRequests[indexPath.row]
                self.declineFriend(r, at: indexPath)
                done(true)
            }
            reject.image = UIImage(systemName: "xmark")

            let config = UISwipeActionsConfiguration(actions: [reject, approve])
            config.performsFirstActionWithFullSwipe = false
            return config

        case .deleteRequests:
            let accept = UIContextualAction(style: .normal, title: "Accept") { [weak self] _, _, done in
                guard let self else { return }
                let r = self.deleteRequests[indexPath.row]
                self.acceptDelete(r, at: indexPath)
                done(true)
            }
            accept.backgroundColor = .systemGreen
            accept.image = UIImage(systemName: "trash")

            let decline = UIContextualAction(style: .destructive, title: "Decline") { [weak self] _, _, done in
                guard let self else { return }
                let r = self.deleteRequests[indexPath.row]
                self.declineDelete(r, at: indexPath)
                done(true)
            }
            decline.image = UIImage(systemName: "xmark")

            let config = UISwipeActionsConfiguration(actions: [decline, accept])
            config.performsFirstActionWithFullSwipe = false
            return config
        }
    }
}

// MARK: - Empty state helpers
private extension UITableView {
    func setEmptyMessage(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16)
        ])
        backgroundView = container
        separatorStyle = .none
    }

    func restore() {
        backgroundView = nil
        separatorStyle = .singleLine
    }
}
