//
//  LinkFivePurchase.swift
//  
//
//  Created by Tan Nghia La on 21.07.21.
//

import Foundation

struct LinkFivePurchase {
    
    struct Request: Encodable {
        /// The product identifier.
        let sku: String
        
        /// The country of purchase.
        let country: String
        
        /// The currency of purchase.
        let currency: String
        
        /// The price.
        let price: Double
        
        /// The transaction id of the purchase.
        let transactionId: String
        
        /// The original transaction id of the purchase.
        let originalTransactionId: String
        
        /// The date of the purchase.
        let purchaseDate: String
    }
}
