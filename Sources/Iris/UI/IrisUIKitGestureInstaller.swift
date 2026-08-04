//
//  IrisUIKitGestureInstaller.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 04/08/26.
//

#if canImport(UIKit)
import UIKit

@MainActor
enum IrisUIKitGestureInstaller {
    private static var isObservingWindows = false
    
    static func apply(_ gesture: IrisGesture) {
        startObservingWindowsIfNeeded()
        
        for window in visibleWindows() {
            apply(gesture, to: window)
        }
    }
    
    private static func startObservingWindowsIfNeeded() {
        guard !isObservingWindows else {
            return
        }
        
        isObservingWindows = true
        NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? UIWindow else {
                return
            }
            
            Task { @MainActor in
                apply(Iris.selectedGesture(), to: window)
            }
        }
    }
    
    private static func apply(
        _ gesture: IrisGesture,
        to window: UIWindow
    ) {
        removeHoldGesture(from: window)
        
        guard case let .hold(minimumDuration) = gesture else {
            return
        }
        
        let recognizer = IrisHoldGestureRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        window.addGestureRecognizer(recognizer)
    }
    
    private static func removeHoldGesture(from window: UIWindow) {
        window.gestureRecognizers?
            .filter { $0 is IrisHoldGestureRecognizer }
            .forEach { window.removeGestureRecognizer($0) }
    }
    
    private static func visibleWindows() -> [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden }
    }
}

private final class IrisHoldGestureRecognizer: UILongPressGestureRecognizer {
    init() {
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(handleGesture))
    }
    
    @objc private func handleGesture() {
        guard state == .began,
              IrisRuntime.shared.snapshot().isEnabled,
              Iris.selectedGesture().isHold else {
            return
        }
        
        Iris.present()
    }
}

private extension IrisGesture {
    var isHold: Bool {
        if case .hold = self {
            return true
        }
        
        return false
    }
}

extension UIWindow {
    open override func motionEnded(
        _ motion: UIEvent.EventSubtype,
        with event: UIEvent?
    ) {
        guard motion == .motionShake,
              IrisRuntime.shared.snapshot().isEnabled,
              Iris.selectedGesture() == .shake else {
            super.motionEnded(motion, with: event)
            return
        }
        
        Iris.present()
    }
}
#endif
