//
//  RootViewControllerProbe.swift
//  SakuttoSplit
//
//  Created by masafumi wakugawa on 2026/09/14.
//

import SwiftUI
import UIKit

/// `UIApplication` の windows は探さない。自身が載った window から root を取る
final class RootViewControllerBox {
    weak var view: UIView?

    var rootViewController: UIViewController? {
        view?.window?.rootViewController
    }
}

struct RootViewControllerProbe: UIViewRepresentable {
    let box: RootViewControllerBox

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        box.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        box.view = uiView
    }
}
