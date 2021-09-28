//
//  LinkFiveSubscription.swift
//  LinkFivePurchases
//
//  Created by Tan Nghia La on 14.07.21.
//  Copyright © 2021 LinkFive. All rights reserved.
//

import Foundation
import StoreKit

public struct LinkFiveSubscriptionList: Codable {
    
    /// A List of subscriptions.
    public let subscriptionList: [LinkFiveSubscription]
    
    /// Optional custom attributes.
    public let attributes: String?
    
    private enum CodingKeys: String, CodingKey {
        case data
    }
    
    private enum NestedCodingKeys: String, CodingKey {
        case subscriptionList
        case attributes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nestedContainer = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .data)
        subscriptionList = try nestedContainer.decode([LinkFiveSubscription].self, forKey: .subscriptionList)
        attributes = try nestedContainer.decode(String.self, forKey: .attributes)
    }

    public func encode(to encoder: Encoder) throws {
        assertionFailure("Response encode not implemented yet")
    }
    
    public struct LinkFiveSubscription: Codable {
        
        /// The sku of the subscription.
        public let sku: String
        
        /// Family name of the subscription.
        public let familyName: String?
        
        /// Additional attributes of the subscription.
        public let attributes: String?
    }
}
