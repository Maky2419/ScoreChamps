//
//  UIViewController+Keyboard.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 8/10/25.
//

// UIViewController+Keyboard.swift
import UIKit

extension UIViewController {
    /// Dismisses the keyboard when you tap anywhere outside an input.
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false   // don't block buttons/table selection
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)              // resigns first responder for any field/searchBar
    }
}
