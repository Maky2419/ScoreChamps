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
    var k: String = ""
    private var ref: DatabaseReference!
    var users: [User] = []    // Declare the variable 'k'
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Writing data to Firebase (create "A" and "S" keys under "name")
        //("DisplayName,UserName,Password")
        
        databaseRef.child("Accounts").child("0").setValue("Ahsan,akalam,542545")
        databaseRef.child("Accounts").child("1").setValue("Saadia,sawais,722342")
        //databaseRef.child("Accounts").child("2").setValue("Jayati,Didi,Rohan")
        
        
        
//        // Observe the "name" node to get all child keys
//        databaseRef.child("name").observe(.childAdded) { snapshot in
//            // Get the key of each child node
//            let userKey = snapshot.key
//            print("User Key: \(userKey)")  // Print the key
//            
//            // Append the key to the userKeys array
//            self.userKeys.append(userKey)
//            
//            // Update 'k' by appending the userKey
//            //self.k = self.k + " " + userKey
//            
//            // Print userKeys and k after the array is updated
//            print("userKeys: \(self.userKeys)") // Print the keys array
//            // print("k: \(self.k)")               // Print the string 'k'
//            
//        }
//        
        ref = Database.database().reference()
        fetchCommaSeparatedData { users in
               self.users = users  // ✅ Save to the class property
               
               // Example: Accessing saved users
               if let firstUser = self.users.first {
                   print("First saved user: \(firstUser.name), \(firstUser.username)")
               }
           }
        
    }
    func fetchCommaSeparatedData(completion: @escaping ([User]) -> Void) {
        ref.child("Accounts").observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists() else {
                print("No data found at 'Accounts'")
                completion([]) // Return empty array if no data
                return
            }
            
            var fetchedUsers: [User] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let csvString = childSnapshot.value as? String {
                    
                    let values = csvString.components(separatedBy: ",")
                    
                    if values.count >= 3 {
                        let user = User(name: values[0], username: values[1], password: values[2])
                        fetchedUsers.append(user)
                        print("✅ User added: \(user.name), \(user.username), \(user.password)")
                    } else {
                        print("⚠️ Skipped invalid entry in document \(childSnapshot.key)")
                    }
                }
            }
            
            print("All users fetched: \(fetchedUsers.count)")
            completion(fetchedUsers) // Return the array via callback
            
        } withCancel: { error in
            print("Error fetching data: \(error.localizedDescription)")
            completion([]) // Return empty array on error
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


