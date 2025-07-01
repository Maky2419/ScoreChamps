//
//  Login.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 2025-05-20.
//

import UIKit
import Firebase
import FirebaseDatabase

// Define the User struct


class Login: UIViewController {
    
    let databaseRef = Database.database().reference()
    var usersMap: [String: User] = [:] // Hashmap to store user data
    private var ref: DatabaseReference!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Save user data in dictionary format to Firebase
        databaseRef.child("Accounts").child("0").setValue([
            "name": "Ahsan",
            "username": "akalam",
            "password": "542545"
        ])
        
        databaseRef.child("Accounts").child("1").setValue([
            "name": "Saadia",
            "username": "sawais",
            "password": "722342"
        ])
        
        ref = Database.database().reference()
        
        // Fetch data into a hashmap
        fetchUsersAsMap { usersDictionary in
            self.usersMap = usersDictionary
            
//            // Example: Access user with key "0"
//            if let user = self.usersMap["0"] {
//                print("🔍 User 0: \(user.name), \(user.username)")
//            }
            
            // Print all users in hashmap
            for (key, user) in self.usersMap {
                print("📌 Key: \(key) -> \(user.name), \(user.username), \(user.password)")
            }
        }
    }

    func fetchUsersAsMap(completion: @escaping ([String: User]) -> Void) {
        ref.child("Accounts").observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists() else {
                print("No data found at 'Accounts'")
                completion([:])
                return
            }

            var userMap: [String: User] = [:]

            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot else { continue }

                if let value = childSnapshot.value as? [String: Any],
                   let name = value["name"] as? String,
                   let username = value["username"] as? String,
                   let password = value["password"] as? String {

                    let user = User(name: name, username: username, password: password)
                    userMap[childSnapshot.key] = user
                    print("✅ User added to hashmap: \(childSnapshot.key) -> \(user.name)")
                } else {
                    print("⚠️ Skipped invalid or incomplete entry at \(childSnapshot.key)")
                }
            }

            completion(userMap)
        } withCancel: { error in
            print("Error fetching data: \(error.localizedDescription)")
            completion([:])
        }
    }
    
    
    
    @IBAction func LoginBtnActivated(_ sender: Any) {
        guard let enteredUsername = UsernamesText.text,
                  let enteredPassword = PasswordText.text,
                  !enteredUsername.isEmpty, !enteredPassword.isEmpty else {
                showAlert(title: "Error", message: "Please enter both username and password.")
                return
            }

            var loginSuccess = false

            for (_, user) in usersMap {
                if user.username == enteredUsername && user.password == enteredPassword {
                    loginSuccess = true
                    break
                }
            }

            if loginSuccess {
                performSegue(withIdentifier: "goToNext", sender: self)
                
                // You can perform segue or navigate here
            } else {
                showAlert(title: "Failed", message: "Invalid username or password.")
            }
        
    }
    @IBOutlet weak var UsernamesText: UITextField!
    @IBOutlet weak var PasswordText: UITextField!
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
}

