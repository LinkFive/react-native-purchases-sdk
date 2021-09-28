//
//  LinkFiveUserDefaults.swift
//  LinkFivePurchases
//
//  Created by Tan Nghia La on 14.07.21.
//  Copyright © 2021 LinkFive. All rights reserved.
//

import Foundation

struct LinkFiveUserDefaults {
    
    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Keys {
        static let receiptInfo = "linkFive.userdefaults.receiptInfo"
    }
    
    
    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    
    /// Shared instance of the `LinkFiveUserDefaults`.
    static let shared = LinkFiveUserDefaults()
    
    private let userDefaults = UserDefaults.standard
    
    /// The current receipts.
    var receipts: [LinkFiveReceipt]? {
        get {
            return codable(for: Keys.receiptInfo)
        }
        set {
            saveCodable(newValue, key: Keys.receiptInfo)
        }
    }
    
    
    //#################################################################################
    // MARK: - Helpers
    //#################################################################################

    private func saveCodable<T: Encodable>(_ codable: T?, key: String) {
        guard let codable = codable else {
            userDefaults.removeObject(forKey: key)
            return
        }
        
        if let encoded = try? JSONEncoder().encode(codable) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    private func codable<T: Decodable>(for key: String) -> T? {
        guard let codable = userDefaults.object(forKey: key) as? Data else { return nil }

        return try? JSONDecoder().decode(T.self, from: codable)
    }
}
