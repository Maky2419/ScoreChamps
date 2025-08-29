//
//  ScoreList.swift
//  ScoreChamps
//

import UIKit

final class ScoreList: UIViewController {

    // MARK: - UI (programmatic)
    private let menuButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
        b.tintColor = .label
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        b.accessibilityLabel = "Menu"
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Scores"
        l.font = .systemFont(ofSize: 32, weight: .semibold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let newScoreButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("New Score", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .systemBlue
        b.layer.cornerRadius = 10
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.tableFooterView = UIView()
        tv.estimatedRowHeight = 60
        tv.rowHeight = UITableView.automaticDimension
        return tv
    }()

    // Side menu
    private let overlayView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        v.alpha = 0
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let sideMenu: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private var menuLeading: NSLayoutConstraint!
    private let menuWidth: CGFloat = 280
    private var isMenuOpen = false

    // Menu content
    private let menuTitle: UILabel = {
        let l = UILabel()
        l.text = "Menu"
        l.font = .systemFont(ofSize: 28, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let accountButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Account", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 20, weight: .regular)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let friendsButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Friends", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 20, weight: .regular)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let notificationsButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Notifications", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 20, weight: .regular)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let logoutButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Log Out", for: .normal)
        b.setTitleColor(.systemRed, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Data
    private var matches: [Match] = []
    private var usersCache: [String: UserModel] = [:]

    private var currentUserId: String {
        FirebaseService.shared.currentUserId ?? ""
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Background color #EBE4DB
        view.backgroundColor = UIColor(red: 235/255, green: 228/255, blue: 219/255, alpha: 1)

        buildHeader()
        buildTable()
        buildMenu()

        tableView.dataSource = self
        tableView.delegate   = self

        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = rc

        menuButton.addTarget(self, action: #selector(menuTapped),       for: .touchUpInside)
        newScoreButton.addTarget(self, action: #selector(newScoreTapped), for: .touchUpInside)

        accountButton.addTarget(self, action: #selector(openAccount),        for: .touchUpInside)
        friendsButton.addTarget(self, action: #selector(openFriends),        for: .touchUpInside)
        notificationsButton.addTarget(self, action: #selector(openNotifications), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(logOutTapped),        for: .touchUpInside)

        loadMatches()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMatches()
    }

    // MARK: - UI builders
    private func buildHeader() {
        view.addSubview(menuButton)
        view.addSubview(titleLabel)
        view.addSubview(newScoreButton)

        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: g.topAnchor, constant: 16),

            menuButton.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            menuButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: menuButton.trailingAnchor, constant: 12),

            newScoreButton.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            newScoreButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])
    }

    private func buildTable() {
        view.addSubview(tableView)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 8),
            tableView.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -8),
            tableView.bottomAnchor.constraint(equalTo: g.bottomAnchor)
        ])
    }

    private func buildMenu() {
        // overlay
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        overlayView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hideMenu)))

        // container
        view.addSubview(sideMenu)
        menuLeading = sideMenu.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -menuWidth)
        NSLayoutConstraint.activate([
            menuLeading,
            sideMenu.topAnchor.constraint(equalTo: view.topAnchor),
            sideMenu.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sideMenu.widthAnchor.constraint(equalToConstant: menuWidth)
        ])

        // content
        sideMenu.addSubview(menuTitle)
        sideMenu.addSubview(accountButton)
        sideMenu.addSubview(friendsButton)
        sideMenu.addSubview(notificationsButton)
        sideMenu.addSubview(logoutButton)

        let mg = sideMenu.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            menuTitle.topAnchor.constraint(equalTo: mg.topAnchor, constant: 16),
            menuTitle.leadingAnchor.constraint(equalTo: mg.leadingAnchor, constant: 16),

            accountButton.topAnchor.constraint(equalTo: menuTitle.bottomAnchor, constant: 24),
            accountButton.leadingAnchor.constraint(equalTo: mg.leadingAnchor, constant: 16),

            friendsButton.topAnchor.constraint(equalTo: accountButton.bottomAnchor, constant: 20),
            friendsButton.leadingAnchor.constraint(equalTo: mg.leadingAnchor, constant: 16),

            notificationsButton.topAnchor.constraint(equalTo: friendsButton.bottomAnchor, constant: 20),
            notificationsButton.leadingAnchor.constraint(equalTo: mg.leadingAnchor, constant: 16),

            logoutButton.topAnchor.constraint(equalTo: notificationsButton.bottomAnchor, constant: 28),
            logoutButton.leadingAnchor.constraint(equalTo: mg.leadingAnchor, constant: 16)
        ])
    }

    // MARK: - Actions
    @objc private func refreshPulled() { loadMatches() }

    @objc private func menuTapped() { isMenuOpen ? hideMenu() : showMenu() }

    private func showMenu() {
        overlayView.isHidden = false
        view.layoutIfNeeded()
        menuLeading.constant = 0
        UIView.animate(withDuration: 0.25) {
            self.overlayView.alpha = 1
            self.view.layoutIfNeeded()
        }
        isMenuOpen = true
    }

    @objc private func hideMenu() {
        menuLeading.constant = -menuWidth
        UIView.animate(withDuration: 0.25, animations: {
            self.overlayView.alpha = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.overlayView.isHidden = true
        })
        isMenuOpen = false
    }

    @objc private func newScoreTapped() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "NewScoreViewController") as? NewScoreViewController else {
            assertionFailure("Storyboard ID mismatch for NewScoreViewController")
            return
        }
        vc.onSaved  = { [weak self] in self?.loadMatches() }
        vc.onClosed = { [weak self] in self?.loadMatches() }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func openAccount() {
        hideMenu()
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "AccountViewController") as? AccountViewController else {
            assertionFailure("Storyboard ID 'AccountViewController' missing")
            return
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func openFriends() {
        hideMenu()
        let sb = UIStoryboard(name: "Main", bundle: nil)
        // The class file is Friends.swift → class Friends
        // Make sure the storyboard ID is set to "Friends" (or change the string below).
        guard let vc = sb.instantiateViewController(withIdentifier: "Friends") as? Friends else {
            assertionFailure("Storyboard ID 'Friends' missing or class mismatch (Friends.swift)")
            return
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func openNotifications() {
        hideMenu()
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "NotificationsViewController") as? NotificationsViewController else {
            assertionFailure("Storyboard ID 'NotificationsViewController' missing or class mismatch")
            return
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func logOutTapped() {
        hideMenu()
        AppRouter.goToLogin(resetSession: true)
    }

    // MARK: - Data
    private func loadMatches() {
        guard !currentUserId.isEmpty else {
            tableView.refreshControl?.endRefreshing()
            return
        }

        FirebaseService.shared.fetchMatches(for: currentUserId) { [weak self] list in
            guard let self = self else { return }
            self.matches = list
            DispatchQueue.main.async {
                self.tableView.refreshControl?.endRefreshing()
                self.tableView.reloadData()
            }
        }
    }

    private func user(for uid: String, completion: @escaping (UserModel?) -> Void) {
        if let cached = usersCache[uid] { completion(cached); return }
        FirebaseService.shared.fetchUser(byUserId: uid) { [weak self] u in
            if let u = u { self?.usersCache[uid] = u }
            completion(u)
        }
    }

    private func showEditor(for match: Match) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "EditMatchViewController") as? EditMatchViewController else {
            assertionFailure("Storyboard ID 'EditMatchViewController' missing")
            return
        }
        vc.match = match
        vc.onSaved  = { [weak self] in self?.loadMatches() }
        vc.onClosed = { [weak self] in self?.loadMatches() }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
}

// MARK: - UITableView
extension ScoreList: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { matches.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ScoreCell")

        let m = matches[indexPath.row]

        if let title = m.title, !title.isEmpty {
            cell.textLabel?.text = "\(title) — vs. …"
        } else {
            cell.textLabel?.text = "vs. …"
        }
        cell.detailTextLabel?.text = "You \(m.player1) – \(m.player2)"
        cell.accessoryType = .disclosureIndicator

        user(for: m.opponentUserId) { [weak tableView] user in
            DispatchQueue.main.async {
                guard
                    let tableView = tableView,
                    let currentIndex = tableView.indexPath(for: cell),
                    currentIndex == indexPath
                else { return }

                let nameText: String
                if let u = user {
                    nameText = !u.name.isEmpty ? u.name : (!u.username.isEmpty ? "@\(u.username)" : u.userId)
                } else {
                    nameText = "(unknown)"
                }

                if let title = m.title, !title.isEmpty {
                    cell.textLabel?.text = "\(title) — vs. \(nameText)"
                } else {
                    cell.textLabel?.text = "vs. \(nameText)"
                }
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showEditor(for: matches[indexPath.row])
    }
}
