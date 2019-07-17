//
//  Transition.swift
//  Swoorn
//
//  Created by Peter IJlst | The Mobile Company on 08/05/2019.
//  Copyright © 2019 Peter IJlst. All rights reserved.
//

public struct Transition<State, Event> {

    public let event: Event
    public let source: State
    public let destination: State

    let rules: [Rule]?

    public init(event: Event,
                source: State,
                destination: State,
                rules: [Rule]? = nil) {

        self.event = event
        self.source = source
        self.destination = destination
        self.rules = rules
    }
}
