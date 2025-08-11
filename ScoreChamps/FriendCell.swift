import UIKit

class FriendCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var viewButton: UIButton!

    var onViewTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }

    func configure(name: String, username: String) {
        nameLabel.text = name
        usernameLabel.text = "@\(username)"
    }

    @IBAction func viewTapped(_ sender: Any) {
        onViewTapped?()
    }
}
