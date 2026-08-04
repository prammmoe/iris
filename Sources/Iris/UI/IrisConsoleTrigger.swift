//
//  IrisConsoleTrigger.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 04/08/26.
//

import SwiftUI

public enum IrisConsoleTrigger: Sendable, Equatable {
    case shake
    case longPress(minimumDuration: Double = 0.8)
}

#if canImport(UIKit)
import UIKit

public extension View {
    func irisConsoleTrigger(
        _ trigger: IrisConsoleTrigger = .shake
    ) -> some View {
        modifier(IrisConsoleTriggerModifier(trigger: trigger))
    }
}

private struct IrisConsoleTriggerModifier: ViewModifier {
    let trigger: IrisConsoleTrigger
    
    func body(content: Content) -> some View {
        switch trigger {
        case .shake:
            content
                .background(IrisShakeDetector())
        case let .longPress(minimumDuration):
            content
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: minimumDuration)
                        .onEnded { _ in
                            Task { @MainActor in
                                Iris.present()
                            }
                        }
                )
        }
    }
}

private struct IrisShakeDetector: UIViewRepresentable {
    func makeUIView(context: Context) -> ShakeDetectingView {
        ShakeDetectingView()
    }
    
    func updateUIView(_ uiView: ShakeDetectingView, context: Context) {
        uiView.activate()
    }
}

private final class ShakeDetectingView: UIView {
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        activate()
    }
    
    func activate() {
        guard window != nil,
              !isFirstResponder else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.becomeFirstResponder()
        }
    }
    
    override func motionEnded(
        _ motion: UIEvent.EventSubtype,
        with event: UIEvent?
    ) {
        guard motion == .motionShake else {
            return
        }
        
        Task { @MainActor in
            Iris.present()
        }
    }
}
#endif
