//
//  StateStorage.swift
//  SwinjectStateMachine
//
//  Created by Peter IJlst | The Mobile Company on 05/07/2019.
//

// MARK: - Enum
enum StorageKeys {
    static let state = "STATE"
}

// MARK: - Class
class Storage<State: RawRepresentable> {
    public var storedState: State? {
        get {
            guard let value = UserDefaults.standard
                .value(forKey: StorageKeys.state) as? State.RawValue else {
                    return nil
            }

            return State(rawValue: value)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue ?? nil, forKey: StorageKeys.state)
        }
    }
}
