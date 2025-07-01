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
          
        }
        
        
        
    }
}
