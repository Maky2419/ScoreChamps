//
//  Login.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 2025-05-20.
//

import AuthenticationServices
import Firebase
import FirebaseDatabase



class Login: UIViewController {
    
    let databaseRef = Database.database().reference()
    var userKeys: [String] = []   // Declare the userKeys array
    var k: String = ""            // Declare the variable 'k'
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Writing data to Firebase (create "A" and "S" keys under "name")
        databaseRef.child("yourNode").child("0").setValue("Ahsan,Kalam,Quereshi")
        databaseRef.child("yourNode").child("1").setValue("Emaan,Kashif,Amber")
        databaseRef.child("yourNode").child("2").setValue("Jayati,Didi,Rohan")
        
        
        
        // Observe the "name" node to get all child keys
        databaseRef.child("name").observe(.childAdded) { snapshot in
            // Get the key of each child node
            let userKey = snapshot.key
            print("User Key: \(userKey)")  // Print the key
            
            // Append the key to the userKeys array
            self.userKeys.append(userKey)
            
            // Update 'k' by appending the userKey
            //self.k = self.k + " " + userKey
            
            // Print userKeys and k after the array is updated
            print("userKeys: \(self.userKeys)") // Print the keys array
            // print("k: \(self.k)")               // Print the string 'k'
            
        }
    }
       
        
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        appleBtn.addTarget(self, action: #selector(appleSignInTapped), for: .touchUpInside)
//    }
//    
//    @objc func appleSignInTapped() {
//        let alert = UIAlertController(
//            title: "Sign in",
//            message: "Would you like to sign in with your Apple ID?",
//            preferredStyle: .alert
//        )
//
//        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
//            self.startSignInWithAppleFlow()
//        }))
//
//        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
//
//        present(alert, animated: true)
//    }





}

