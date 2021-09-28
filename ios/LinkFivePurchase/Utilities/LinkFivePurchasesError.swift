//
//  LinkFivePurchasesError.swift
//  LinkFivePurchases
//
//  Created by Tan Nghia La on 14.07.21.
//  Copyright © 2021 LinkFive. All rights reserved.
//

import Foundation

public enum LinkFivePurchasesError: Error {
    
    /// There are no product ids given from LinkFive.
    case noProductIdsFound
    
    /// There are no active products for the given product ids.
    case noProductsFound
    
    /// The device is not able to make payments.
    case cantMakePayments
    
    /// The user cancelled the payment
    case paymentWasCancelled
    
    /// No product found
    case noProductFound
    
    /// There is no receipt info
    case noReceiptInfo
    
    /// The SDK has to be launched first.
    case launchSdkNeeded
}
