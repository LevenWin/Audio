//
//  AppDelegate.swift
//  Audio
//
//  Created by leven on 2020/7/13.
//  Copyright © 2020 leven. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {


    struct Person {
        var name: String
        var age: Int
    }

    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        self.window = UIWindow()
        self.window?.rootViewController = ViewController()
        self.window?.makeKeyAndVisible()
        
        var p = Person(name: "leven,leven", age: 17)
        
        let size = MemoryLayout<Person>.size
        let stride = MemoryLayout<Person>.stride
        let aligment = MemoryLayout<Person>.alignment
        
        
        let size_p = MemoryLayout<Person>.size(ofValue: p)
        let stride_p = MemoryLayout<Person>.stride(ofValue: p)
        let aligment_p = MemoryLayout<Person>.alignment(ofValue: p)
        print(p.name)
        
        let p_Ptr = withUnsafePointer(to: &p) {
            return UnsafeMutableRawPointer(mutating: $0).bindMemory(to: Int8.self, capacity: MemoryLayout<Person>.stride)
        }
        
        
        var rawPtr = UnsafeMutableRawPointer(p_Ptr)
        var rawPtr2 = rawPtr.advanced(by: 0).assumingMemoryBound(to: String.self)
        print(rawPtr2.pointee)
        rawPtr2.initialize(to: "hello, Leven")
        print(rawPtr2.pointee)
        var rawPtr3 = rawPtr.advanced(by: MemoryLayout<String>.stride).assumingMemoryBound(to: Int.self)
        
        print(rawPtr3.pointee)
        rawPtr3.initialize(to: 20)
        print(rawPtr3.pointee)


        
        
        return true
    }


}

