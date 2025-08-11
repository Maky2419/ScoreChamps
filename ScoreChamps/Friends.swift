import UIKit

// Simple model used for display
struct FriendProfile {
    let userId: String
    let username: String
    let displayName: String
}

class Friends: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIButton!   // the blue "+" next to the search bar

    // MARK: - State
    private var all: [FriendProfile] = []
    private var filtered: [FriendProfile] = []

    // Reuse ID for the simple built-in cell
    private let cellID = "FriendCellBasic"

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Friends"

        // table
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag

        // search
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no

        // "+" button styling (safe even if already styled in storyboard)
        addButton.setImage(UIImage(systemName: "person.badge.plus"), for: .normal)
        addButton.tintColor = .white
        addButton.backgroundColor = view.tintColor

        // tap anywhere to dismiss keyboard (if you added the extension I shared)
        hideKeyboardWhenTappedAround()

        loadFriends()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // make the + button circular
        addButton.layer.cornerRadius = addButton.bounds.height / 2
        addButton.clipsToBounds = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // refresh when returning from Add Friend etc.
        loadFriends()
    }

    // MARK: - Actions
    @IBAction func addFriendTapped(_ sender: Any) {
        // requires a storyboard scene with Storyboard ID: "AddFriendVC"
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "AddFriendVC")
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .pageSheet
            present(nav, animated: true)
        }
    }

    @objc private func viewFriendButtonTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard filtered.indices.contains(idx) else { return }
        let f = filtered[idx]
        // TODO: push a friend detail / scores screen and pass f.userId
        print("View friend:", f.username)
    }

    // MARK: - Data
    private func loadFriends() {
        guard let me = FirebaseService.shared.currentUserId else { return }

        FirebaseService.shared.fetchUser(byUserId: me) { [weak self] user in
            guard let self, let user = user else { return }

            var profiles: [FriendProfile] = []
            let group = DispatchGroup()

            // friends is stored as: [friendUid: friendUsername]
            for (friendUid, friendUsername) in user.friends {
                group.enter()
                FirebaseService.shared.fetchUser(byUserId: friendUid) { u in
                    let display = u?.name ?? friendUsername
                    profiles.append(FriendProfile(userId: friendUid,
                                                  username: friendUsername,
                                                  displayName: display))
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.all = profiles.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                self.filtered = self.all
                self.tableView.reloadData()
                self.updateEmptyState()
            }
        }
    }

    // Optional: empty state
    private func updateEmptyState() {
        if filtered.isEmpty {
            let label = UILabel()
            label.text = "No friends yet.\nTap  +  to add someone."
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            label.font = .systemFont(ofSize: 16)
            tableView.backgroundView = label
            tableView.separatorStyle = .none
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }
    }
}

// MARK: - Table
extension Friends: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        updateEmptyState()
        return filtered.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // use a safe built-in .subtitle cell; no IBOutlets required
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellID)

        let f = filtered[indexPath.row]
        cell.textLabel?.text = f.displayName
        cell.detailTextLabel?.text = "@\(f.username)"
        cell.selectionStyle = .none

        // accessory "View" button
        let btn = UIButton(type: .system)
        btn.setTitle("View", for: .normal)
        btn.tag = indexPath.row
        btn.addTarget(self, action: #selector(viewFriendButtonTapped(_:)), for: .touchUpInside)
        btn.sizeToFit()
        cell.accessoryView = btn

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // you can also open on row tap if you like
        tableView.deselectRow(at: indexPath, animated: true)
        let f = filtered[indexPath.row]
        print("Selected friend:", f.username)
    }
}

// MARK: - Search
extension Friends: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            filtered = all
        } else {
            filtered = all.filter {
                $0.displayName.localizedCaseInsensitiveContains(q) ||
                $0.username.localizedCaseInsensitiveContains(q)
            }
        }
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}


