//
//  StateMachine.swift
//  Swoorn
//
//  Created by Peter IJlst | The Mobile Company on 08/05/2019.
//  Copyright © 2019 Peter IJlst. All rights reserved.
//

import Swinject
import SwinjectStoryboard
import SwinjectAutoregistration
import Foundation

// MARK: - Protocol

public protocol StateConfig: Hashable, RawRepresentable {
    var dependencies: [Assembly] { get }
    var storyboardName: String { get }
}

public protocol EventConfig: Hashable {
    var viewController: ViewControllerProvidingClosure { get }
    var transition: TransitionType { get }
}

public protocol Rule {
    var isAllowedToFail: Bool { get }
    var onFailure: (() -> Void)? { get }
    var passes: Bool { get }
}

// MARK: - Typealias

public typealias CompletionBlock = ((TransitionResult) -> Void)
public typealias ViewControllerProvidingClosure = (SwinjectStoryboard, Container) -> UIViewController
public typealias CustomTransitionClosure = (SwinjectStoryboard, Container) -> Void

// MARK: - Enum

public enum TransitionType {
    case showModal
    case dismissModal
    case replaceAnimated(TransitionOptions.Direction)
    case replace
    case custom(CustomTransitionClosure)
}

public enum TransitionResult {
    case success, failure
}

// MARK: - Class

open class SwinjectStateMachine<State: StateConfig, Event: EventConfig> {

    // MARK: - Public Properties

    #if DEBUG
    public var enableLogging: Bool = true
    #else
    public var enableLogging: Bool = false
    #endif

    public var currentState: State {
        return { workingQueue.sync { internalState } }()
    }
    public var restoredState: State? {
        return storage.storedState
    }

    // MARK: - Private Properties

    private var internalState: State
    private var transitionsByEvent: [Event: [Transition<State, Event>]] = [:]
    private let lockQueue: DispatchQueue
    private let workingQueue: DispatchQueue
    private let callbackQueue: DispatchQueue
    private let container: Container
    private let storage = Storage<State>()

    // MARK: - Public Methods

    public init(initialState: State,
                callbackQueue: DispatchQueue? = nil,
                container: Container? = nil) {

        self.internalState = initialState
        self.lockQueue = DispatchQueue(label: "nl.pydev.statemachine.queue.lock")
        self.workingQueue = DispatchQueue(label: "nl.pydev.statemachine.queue.working")
        self.callbackQueue = callbackQueue ?? .main
        self.container = container ?? Container()
    }

    public func storeCurrentState() {
        storage.storedState = currentState
    }

    public func clearStateStorage() {
        storage.storedState = nil
    }

    // swiftlint:disable function_body_length
    public func process(event: Event,
                        callback: CompletionBlock? = nil) {

        var transitions: [Transition<State, Event>]?
        lockQueue.sync { transitions = transitionsByEvent[event] }
        workingQueue.async {

            let performableTransitions = transitions?.filter { $0.source == self.internalState } ?? []
            if performableTransitions.count == 0 {
                self.callbackQueue.async { callback?(.failure) }
                return
            }

            assert(
                performableTransitions.count == 1,
                """
                Found multiple transitions with event '\(event)'\
                and source '\(self.internalState)'.
                """
            )

            let transition = performableTransitions.first!
            if let rules = transition.rules {

                self.log(
                    """
                    Processing rules for transition of '\(event)'
                    """
                )

                let allowedToFail = rules.filter { $0.isAllowedToFail }
                let optionalFailing = allowedToFail.filter { !$0.passes }
                self.callbackQueue.async {
                    optionalFailing.forEach { $0.onFailure?() }
                }
                let notAllowedToFail = rules.filter { !$0.isAllowedToFail }
                let requiredFailing = notAllowedToFail.filter { !$0.passes }

                if requiredFailing.count > 0 {
                    self.callbackQueue.async {
                        callback?(.failure)
                        requiredFailing.forEach { $0.onFailure?() }
                    }
                    return
                }
            }

            self.log(
                """
                Processing event '\(event)'\
                from '\(self.internalState)'
                """
            )

            let previousState = self.internalState
            self.internalState = transition.destination

            self.log(
                """
                Processed state change from '\(previousState)'\
                to '\(transition.destination)'
                """
            )

            self.changedState(state: transition.destination, event: event)
            self.callbackQueue.async { callback?(.success) }

            self.callbackQueue.async {
                let alert = UIAlertController(title: "Changed State",
                                              message: """
                    From: \(previousState)
                    To: \(self.currentState)
                    Event: \(event)
                    Transition: \(event.transition)
                    """,
                    preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
                    alert.dismiss(animated: true, completion: nil)
                }))
                if case TransitionType.showModal = event.transition {
                    let presented = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController
                    presented?.present(alert, animated: true)
                } else {
                    UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true)
                }
            }
        }
    }

    @discardableResult
    public func add(transition: Transition<State, Event>) {
        lockQueue.sync {
            if let transitions = transitionsByEvent[transition.event] {
                assert(
                    transitions.filter { $0.source == transition.source }.count == 0,
                    """
                    Transition with event '\(transition.event)'\
                    and source '\(transition.source)' already existing.
                    """
                )
                transitionsByEvent[transition.event]?.append(transition)
            } else {
                transitionsByEvent[transition.event] = [transition]
            }
        }
    }

    // MARK: - Private Methods

    private func changedState(state: State, event: Event) {
        callbackQueue.async {

            let childContainer = self.createChildContainer(state: state)
            let storyboard = self.createStoryboard(state: state, container: childContainer)
            let initialViewController = event.viewController(storyboard, childContainer)

            self.log(
                """
                Executing \(event.transition) transition
                to '\(state)'
                with event '\(event)'
                """
            )

            switch event.transition {

            case .dismissModal:
                UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true)

            case .showModal:
                if var topController = UIApplication.shared.keyWindow?.rootViewController {
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                    }
                    topController.present(initialViewController, animated: true)
                } else {
                    UIApplication.shared.keyWindow?.rootViewController?.present(
                        initialViewController,
                        animated: true
                    )
                }

            case .replaceAnimated(let direction):
                UIApplication.shared.keyWindow?.setRootViewController(
                    initialViewController,
                    options: TransitionOptions(direction: direction)
                )

            case .replace:
                UIApplication.shared.keyWindow?.rootViewController = initialViewController

            case .custom(let callback):
                callback(storyboard, childContainer)

            default:
                UIApplication.shared.keyWindow?.setRootViewController(
                    initialViewController,
                    options: TransitionOptions(direction: .toLeft)
                )
            }
        }
    }

    private func createChildContainer(state: State) -> Container {
        let childContainer = Container(parent: container)
        state.dependencies.forEach { $0.assemble(container: childContainer) }
        return childContainer
    }

    private func createStoryboard(state: State, container: Container) -> SwinjectStoryboard {
        return SwinjectStoryboard.create(name: state.storyboardName, bundle: nil, container: container)
    }

    private func log(_ message: String) {
        guard enableLogging else { return }
        print("🧩 \(message)")
    }
}
