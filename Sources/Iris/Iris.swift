//
//  Iris.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 03/08/26.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public enum Iris {
    private static let registrationLock = NSLock()
    nonisolated(unsafe) private static var isURLProtocolRegistered = false
    
    public static func start(
        configuration: IrisConfiguration = IrisConfiguration(),
        autoInject: Bool = true
    ) {
        if autoInject {
            IrisURLSessionConfigurationInjector.implement()
            registerURLProtocolIfNeeded()
        }
        
        IrisRuntime.shared.start(configuration: configuration)
    }
    
    public static func stop() {
        IrisRuntime.shared.stop()
        unregisterURLProtocolIfNeeded()
    }
    
    @discardableResult
    public static func instrument(
        _ configuration: URLSessionConfiguration = .default
    ) -> URLSessionConfiguration {
        guard configuration.identifier == nil else {
            assertionFailure("Iris does not support background URLSession.")
            return configuration
        }
        
        var protocolClasses = configuration.protocolClasses ?? []
        let irisIdentifier = ObjectIdentifier(IrisURLProtocol.self)
        let alreadyRegistered = protocolClasses.contains {
            ObjectIdentifier($0) == irisIdentifier
        }
        
        if !alreadyRegistered {
            protocolClasses.insert(IrisURLProtocol.self, at: 0)
        }
        
        configuration.protocolClasses = protocolClasses
        
        return configuration
    }
    
    static func protocolClassesByInjectingIris(
        into protocolClasses: [AnyClass]?
    ) -> [AnyClass] {
        var protocolClasses = protocolClasses ?? []
        let irisIdentifier = ObjectIdentifier(IrisURLProtocol.self)
        let alreadyRegistered = protocolClasses.contains {
            ObjectIdentifier($0) == irisIdentifier
        }
        
        if !alreadyRegistered {
            protocolClasses.insert(IrisURLProtocol.self, at: 0)
        }
        
        return protocolClasses
    }
    
    private static func registerURLProtocolIfNeeded() {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        
        guard !isURLProtocolRegistered else {
            return
        }
        
        URLProtocol.registerClass(IrisURLProtocol.self)
        isURLProtocolRegistered = true
    }
    
    private static func unregisterURLProtocolIfNeeded() {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        
        guard isURLProtocolRegistered else {
            return
        }
        
        URLProtocol.unregisterClass(IrisURLProtocol.self)
        isURLProtocolRegistered = false
    }
    
    public static func clear() {
        Task {
            await IrisStore.shared.clear()
        }
    }
    
    public static func transactions() async -> [IrisTransaction] {
        await IrisStore.shared.snapshot()
    }
    
    public static func consoleView() -> some View {
        IrisConsoleView()
    }
    
    #if canImport(UIKit)
    @MainActor
    public static func makeConsoleViewController() -> UIViewController {
        UIHostingController(rootView: IrisConsoleView())
    }
    
    @MainActor
    public static func present(from presenter: UIViewController) {
        let controller = makeConsoleViewController()
        controller.modalPresentationStyle = .pageSheet
        
        presenter.present(controller, animated: true)
    }
    
    @MainActor
    public static func present() {
        guard let presenter = topMostViewController() else {
            return
        }
        
        present(from: presenter)
    }
    
    @MainActor
    private static func topMostViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        
        let rootViewController = windowScene?.windows
            .first { $0.isKeyWindow }?
            .rootViewController
        
        return topMostViewController(from: rootViewController)
    }
    
    @MainActor
    private static func topMostViewController(
        from controller: UIViewController?
    ) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topMostViewController(from: navigationController.visibleViewController)
        }
        
        if let tabBarController = controller as? UITabBarController {
            return topMostViewController(from: tabBarController.selectedViewController)
        }
        
        if let presentedController = controller?.presentedViewController {
            return topMostViewController(from: presentedController)
        }
        
        return controller
    }
    #endif
}
