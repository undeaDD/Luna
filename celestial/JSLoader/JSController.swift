//
//  JSController.swift
//  celestial
//
//  Created by Francesco on 07/08/25.
//

import AVKit
import SwiftUI
import Foundation
import AVFoundation
import JavaScriptCore

class JSController: NSObject, ObservableObject {
    static let shared = JSController()
    var context: JSContext
    
    override init() {
        self.context = JSContext()
        super.init()
        setupContext()
    }
    
    func setupContext() {
        context.setupJavaScriptEnvironment()
    }
    
    func loadScript(_ script: String) {
        context = JSContext()
        context.setupJavaScriptEnvironment()
        context.evaluateScript(script)
        if let exception = context.exception {
            Logger.shared.log("Error loading script: \(exception)", type: "Error")
        }
    }
}
