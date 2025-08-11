import UIKit
import FirebaseDatabase

// MARK: - Inline Approve/Reject Cell
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
        commonInit()
    }

    private func commonInit() {
        selectionStyle = .none
        textLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        detailTextLabel?.textColor = .secondaryLabel

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
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
    }

    func configure(name: String, username: String) {
        textLabel?.text = name
        detailTextLabel?.text = "@\(username) sent you a friend request"
    }

    @objc private func tapApprove() { onApprove?() }
    @objc private func tapReject()  { onReject?() }
}

// MARK: - Notifications VC
final class NotificationsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var requests: [FriendRequest] = []
    private var handle: DatabaseHandle?
    private var myUid: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 72
        tableView.tableFooterView = UIView()

        guard let me = FirebaseService.shared.currentUserId else { return }
        myUid = me

        // Live updates of incoming requests
        handle = FirebaseService.shared.observeIncomingRequests(for: me) { [weak self] list in
            guard let self else { return }
            self.requests = list
            self.tableView.reloadData()
        }
    }

    deinit {
        if let h = handle { FirebaseService.shared.ref.removeObserver(withHandle: h) }
    }

    // MARK: Actions
    private func accept(_ req: FriendRequest, at indexPath: IndexPath) {
        FirebaseService.shared.acceptFriendRequest(myUid: myUid, from: req) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self else { return }
                if ok, self.requests.indices.contains(indexPath.row) {
                    self.requests.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                } else {
                    self.toast("Could not accept request.")
                }
            }
        }
    }

    private func decline(_ req: FriendRequest, at indexPath: IndexPath) {
        FirebaseService.shared.declineFriendRequest(myUid: myUid, from: req.fromUid) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self else { return }
                if ok, self.requests.indices.contains(indexPath.row) {
                    self.requests.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                } else {
                    self.toast("Could not decline request.")
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

// MARK: - Table
extension NotificationsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        if requests.isEmpty {
            tv.setEmptyMessage("No requests yet")
        } else {
            tv.restore()
        }
        return requests.count
    }

    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "InviteCell") as? InviteCell
            ?? InviteCell(style: .subtitle, reuseIdentifier: "InviteCell")

        let r = requests[indexPath.row]
        cell.configure(name: r.fromName, username: r.fromUsername)

        // wire actions
        cell.onApprove = { [weak self, weak tv] in
            guard let self, let tv else { return }
            self.accept(r, at: indexPath)
        }
        cell.onReject = { [weak self, weak tv] in
            guard let self, let tv else { return }
            self.decline(r, at: indexPath)
        }
        return cell
    }

    // Optional: swipe actions as an alternative to the inline buttons
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {

        let approve = UIContextualAction(style: .normal, title: "Approve") { [weak self] _, _, done in
            guard let self else { return }
            let r = self.requests[indexPath.row]
            self.accept(r, at: indexPath)
            done(true)
        }
        approve.backgroundColor = .systemGreen
        approve.image = UIImage(systemName: "checkmark")

        let reject = UIContextualAction(style: .destructive, title: "Reject") { [weak self] _, _, done in
            guard let self else { return }
            let r = self.requests[indexPath.row]
            self.decline(r, at: indexPath)
            done(true)
        }
        reject.image = UIImage(systemName: "xmark")

        let config = UISwipeActionsConfiguration(actions: [reject, approve])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
}

// MARK: - Helpers (empty state)
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
