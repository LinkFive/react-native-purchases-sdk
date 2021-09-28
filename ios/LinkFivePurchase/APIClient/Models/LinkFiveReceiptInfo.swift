//
//  LinkFiveReceiptInfo.swift
//  LinkFivePurchases
//
//  Created by Tan Nghia La on 14.07.21.
//  Copyright © 2021 LinkFive. All rights reserved.
//

import Foundation

struct LinkFiveReceiptInfo: Codable {
    let data: DataClass
    
    struct DataClass: Codable {
        let purchases: [LinkFiveReceipt]
    }
    
    struct Request: Encodable {
        
        /// The receipt to send for the verification.
        let receipt: String
    }
}

public struct LinkFiveReceipt: Codable {
    
    /// The identifier.
    public let sku: String
    
    /// The purchase id.
    public let purchaseId: String
    
    /// The transaction date.
    public let transactionDate: Date
    
    /// The expiration date.
    public let validUntilDate: Date
    
    /// Whether the receipt is expired.
    public let isExpired: Bool
    
    /// Whether the receipt is still in trial phase.
    public let isTrial: Bool
    
    /// The period of the subscription.
    public let period: String?
    
    /// The (optional) family name of the subscription.
    public let familyName: String?
    
    /// Optional custom attributes.
    public let attributes: String?
}
