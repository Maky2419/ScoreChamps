//
//  SignUp.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 2025-05-21.
//

import Foundation
import UIKit
import Firebase
import FirebaseDatabase
class SignUp: UIViewController {
    private var ref: DatabaseReference!
    var users: [User] = []
    
    @IBOutlet weak var Dname: UITextField!
    @IBOutlet weak var Username: UITextField!
    @IBOutlet weak var Password: UITextField!
    
    override func viewDidLoad() {
            super.viewDidLoad()
            ref = Database.database().reference() // Initialize Firebase reference
        }
        
        @IBAction func SignUpAccount(_ sender: Any) {
            guard let name = Dname.text, !name.isEmpty,
                  let username = Username.text, !username.isEmpty,
                  let password = Password.text, !password.isEmpty else {
                showAlert(title: "Missing Info", message: "Please fill in all fields.")
                return
            }
            
            // Create a unique key for the new user
            let newUserRef = ref.child("Accounts").childByAutoId()
            
            // Save user as dictionary (hashtable)
            let userData: [String: Any] = [
                "name": name,
                "username": username,
                "password": password
            ]
            
            newUserRef.setValue(userData) { error, _ in
                if let error = error {
                    self.showAlert(title: "Error", message: "Failed to create account: \(error.localizedDescription)")
                } else {
                    self.showAlert(title: "Success", message: "Account created successfully!")
                    // Optionally: self.dismiss(animated: true)
                }
            }
        }
        
        // Reusable alert function
        func showAlert(title: String, message: String) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    
    
}
