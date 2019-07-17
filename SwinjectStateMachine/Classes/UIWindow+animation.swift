//
//  UIWindow+animation.swift
//  SwinjectStateMachine
//
//  Created by Peter IJlst | The Mobile Company on 04/07/2019.
//

import UIKit

public struct TransitionOptions {

    public enum Curve {
        case linear
        case easeIn
        case easeOut
        case easeInOut

        internal var function: CAMediaTimingFunction {
            let key: String
            switch self {
            case .linear: key = CAMediaTimingFunctionName.linear.rawValue
            case .easeIn: key = CAMediaTimingFunctionName.easeIn.rawValue
            case .easeOut: key = CAMediaTimingFunctionName.easeOut.rawValue
            case .easeInOut: key = CAMediaTimingFunctionName.easeInEaseOut.rawValue
            }
            return CAMediaTimingFunction(name: CAMediaTimingFunctionName(rawValue: key))
        }
    }

    public enum Direction {
        case fade
        case toTop
        case toBottom
        case toLeft
        case toRight

        internal var transition: CATransition {
            let transition = CATransition()
            transition.type = .push
            switch self {
            case .fade:
                transition.type = .fade
                transition.subtype = nil
            case .toLeft:
                transition.subtype = .fromLeft
            case .toRight:
                transition.subtype = .fromRight
            case .toTop:
                transition.subtype = .fromTop
            case .toBottom:
                transition.subtype = .fromBottom
            }
            return transition
        }
    }

    public var duration: TimeInterval = 0.20
    public var direction: TransitionOptions.Direction = .toRight
    public var style: TransitionOptions.Curve = .linear
    public var backgroundColor: UIColor = .white

    internal var animation: CATransition {
        let transition = direction.transition
        transition.duration = duration
        transition.timingFunction = style.function
        return transition
    }

    public init(direction: TransitionOptions.Direction = .toRight,
                style: TransitionOptions.Curve = .linear) {
        self.direction = direction
        self.style = style
    }

    public init() { }
}

public extension UIWindow {

    public func setRootViewController(_ controller: UIViewController,
                                      options: TransitionOptions = TransitionOptions()) {

        let transitionWindow = UIWindow(frame: UIScreen.main.bounds)
        transitionWindow.backgroundColor = options.backgroundColor
        transitionWindow.makeKeyAndVisible()

        layer.add(options.animation, forKey: kCATransition)
        rootViewController = controller
        makeKeyAndVisible()

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1 + options.duration,
            execute: { transitionWindow.removeFromSuperview() }
        )
    }
}

internal extension UIViewController {

    static func newController(withView view: UIView, frame: CGRect) -> UIViewController {
        let controller = UIViewController()
        view.frame = frame
        controller.view = view
        return controller
    }
}
