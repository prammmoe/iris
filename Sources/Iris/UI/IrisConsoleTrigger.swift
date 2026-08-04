//
//  IrisConsoleTrigger.swift
//  Iris
//
//  Created by Pramuditha Muhammad Ikhwan on 04/08/26.
//

import SwiftUI

public enum IrisGesture: Sendable, Equatable {
    case shake
    case hold(minimumDuration: Double = 0.8)
    case custom
}

#if canImport(UIKit)
import UIKit

public extension View {
    func irisConsoleTrigger(
        _ gesture: IrisGesture? = nil
    ) -> some View {
        modifier(IrisConsoleTriggerModifier(gesture: gesture))
    }
}

private struct IrisConsoleTriggerModifier: ViewModifier {
    let gesture: IrisGesture?
    
    func body(content: Content) -> some View {
        switch gesture ?? Iris.selectedGesture() {
        case .shake:
            content
                .background(IrisShakeDetector())
        case let .hold(minimumDuration):
            content
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: minimumDuration)
                        .onEnded { _ in
                            Task { @MainActor in
                                Iris.present()
                            }
                        }
                )
        case .custom:
            content
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
        guard motion == .motionShake,
              Iris.selectedGesture() == .shake else {
            return
        }
        
        Task { @MainActor in
            Iris.present()
        }
    }
}
#endif
