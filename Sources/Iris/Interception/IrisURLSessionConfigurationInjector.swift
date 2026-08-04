//
//  IrisURLSessionConfigurationInjector.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 04/08/26.
//

import Foundation

#if canImport(ObjectiveC)
import ObjectiveC
#endif

enum IrisURLSessionConfigurationInjector {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var hasImplemented = false
    
    static func implement() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !hasImplemented else {
            return
        }
        
        hasImplemented = true
        URLSessionConfiguration.irisImplementAutoInjection()
    }
}

@objc
private extension URLSessionConfiguration {
    static func irisImplementAutoInjection() {
        swizzleProtocolClassesSetter()
        swizzleDefaultConfiguration()
        swizzleEphemeralConfiguration()
    }
    
    static func swizzleProtocolClassesSetter() {
        let instance = URLSessionConfiguration.default
        
        guard
            let targetClass = object_getClass(instance),
            let originalMethod = class_getInstanceMethod(
                targetClass,
                #selector(setter: URLSessionConfiguration.protocolClasses)
            ),
            let swizzledMethod = class_getInstanceMethod(
                targetClass,
                #selector(setter: URLSessionConfiguration.iris_protocolClasses)
            )
        else {
            assertionFailure("Iris failed to swizzle URLSessionConfiguration.protocolClasses.")
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    static func swizzleDefaultConfiguration() {
        guard
            let targetClass = object_getClass(URLSessionConfiguration.self),
            let originalMethod = class_getClassMethod(
                targetClass,
                #selector(getter: URLSessionConfiguration.default)
            ),
            let swizzledMethod = class_getClassMethod(
                targetClass,
                #selector(getter: URLSessionConfiguration.iris_default)
            )
        else {
            assertionFailure("Iris failed to swizzle URLSessionConfiguration.default.")
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    static func swizzleEphemeralConfiguration() {
        guard
            let targetClass = object_getClass(URLSessionConfiguration.self),
            let originalMethod = class_getClassMethod(
                targetClass,
                #selector(getter: URLSessionConfiguration.ephemeral)
            ),
            let swizzledMethod = class_getClassMethod(
                targetClass,
                #selector(getter: URLSessionConfiguration.iris_ephemeral)
            )
        else {
            assertionFailure("Iris failed to swizzle URLSessionConfiguration.ephemeral.")
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    var iris_protocolClasses: [AnyClass]? {
        get {
            self.iris_protocolClasses
        }
        set {
            guard let newValue else {
                self.iris_protocolClasses = nil
                return
            }
            
            var deduplicated: [AnyClass] = []
            
            for protocolClass in newValue {
                let identifier = ObjectIdentifier(protocolClass)
                
                guard !deduplicated.contains(where: { ObjectIdentifier($0) == identifier }) else {
                    continue
                }
                
                deduplicated.append(protocolClass)
            }
            
            self.iris_protocolClasses = deduplicated
        }
    }
    
    class var iris_default: URLSessionConfiguration {
        let configuration = self.iris_default
        configuration.protocolClasses = Iris.protocolClassesByInjectingIris(
            into: configuration.protocolClasses
        )
        
        return configuration
    }
    
    class var iris_ephemeral: URLSessionConfiguration {
        let configuration = self.iris_ephemeral
        configuration.protocolClasses = Iris.protocolClassesByInjectingIris(
            into: configuration.protocolClasses
        )
        
        return configuration
    }
}
