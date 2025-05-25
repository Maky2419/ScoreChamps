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
    
    @IBAction func SignUpAccount(_ sender: Any) {
        
        
        
        func viewDidLoad() {
            super.viewDidLoad()
            ref = Database.database().reference()
            
            
            fetchCommaSeparatedData()
            
        }
        func fetchCommaSeparatedData() {
            ref.child("yourNode").observeSingleEvent(of: .value) { snapshot in
                guard snapshot.exists() else {
                    print("No data found at 'yourNode'")
                    return
                }
                
                
                for child in snapshot.children {
                    if let childSnapshot = child as? DataSnapshot,
                       let csvString = childSnapshot.value as? String {
                        
                        let values = csvString.components(separatedBy: ",")
                        
                        if values.count >= 3 {
                            let user = User(name: values[0], username: values[1], password: values[2])
                            self.users.append(user)
                            print("✅ User added: \(user.name), \(user.username), \(user.password)")
                        } else {
                            print("⚠️ Skipped invalid entry in document \(childSnapshot.key)")
                        }
                    }
                }
                
                print("All users fetched: \(self.users.count)")
            } withCancel: { error in
                print("Error fetching data: \(error.localizedDescription)")
            }
        }
        
        
    }
}
