//
//  AppRouter.swift
//  ScoreChamps
//
//  Created by Ahsan Kalam on 8/27/25.
//

// AppRouter.swift (or paste at bottom of any file)
import UIKit

enum AppRouter {
    static func goToLogin(resetSession: Bool = true) {
        if resetSession {
            FirebaseService.shared.currentUserId = nil  // clear your saved session
        }

        // End any editing to avoid keyboard/window logs
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.endEditing(true) }

        // Find a window to replace
        let window: UIWindow? = {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return scene.windows.first
            } else {
                // Fallback for apps without scenes
                return UIApplication.shared.keyWindow
            }
        }()

        guard let win = window else { return }

        // Recreate the initial VC from Main.storyboard (make sure Login is the entry point)
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let root = sb.instantiateInitialViewController()!  // initial VC should be your Login

        // Swap root with a nice transition (prevents flashing old screen)
        UIView.transition(with: win, duration: 0.3, options: .transitionFlipFromLeft, animations: {
            win.rootViewController = root
            win.makeKeyAndVisible()
        })
    }
}
