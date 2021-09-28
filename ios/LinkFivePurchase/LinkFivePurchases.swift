//
//  Result.swift
//  LinkFivePurchases
//
//  Created by Tan Nghia La on 14.07.21.
//  Copyright © 2021 LinkFive. All rights reserved.
//

import Foundation
import StoreKit

public final class LinkFivePurchases: NSObject {
    
    //#################################################################################
    // MARK: - Properties
    //#################################################################################
    
    public static let shared = LinkFivePurchases()
        
    private var apiClient: LinkFiveAPIClient?

    private var totalRestoredPurchases: Int = 0
    private var fetchProductsCompletion: ((Result<[SKProduct]>) -> Void)?
    private var buyProductCompletion: ((Result<Bool>) -> Void)?
    
    private var products: [SKProduct] = []
    
    private var userDefaults = LinkFiveUserDefaults.shared
    
    private var receipt: String? {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else { return nil }
        
        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            let receiptString = receiptData.base64EncodedString(options: [])
            return receiptString
        }
        catch {
            LinkFiveLogger.debug("Couldn't read receipt data with error: " + error.localizedDescription)
            return nil
        }
    }
    
    private var productToPurchase: SKProduct?
    
    
    //#################################################################################
    // MARK: - Initialization
    //#################################################################################
    
    private override init() {}
    
    
    //#################################################################################
    // MARK: - Public API
    //#################################################################################
    
    /// Initializes the SDK.
    /// - Parameters:
    ///     - apiKey: Your LinkFive API key.
    ///     - environment: Your current environment.
    public func launch(with apiKey: String,
                       environment: LinkFiveEnvironment = .production) {
        self.apiClient = LinkFiveAPIClient(apiKey: apiKey, environment: environment)
        
        SKPaymentQueue.default().add(self)
        
        if let _ = receipt {
            verifyReceipt()
        }
    }
    
    /// Fetches and returns the available subscriptions.
    /// - Parameters:
    ///     - completion: The completion of the subscription fetch.
    public func fetchSubscriptions(completion: @escaping (Result<[SKProduct]>) -> Void) {
        guard let apiClient = apiClient else {
            completion(.failure(LinkFivePurchasesError.launchSdkNeeded))
            return
        }
        
        fetchProductsCompletion = completion
        
        apiClient.fetchSubscriptions(completion: { [weak self] result in
            switch result {
            case .failure(let error):
                self?.fetchProductsCompletion?(.failure(error))
            case .success(let response):
                let productIds = response.subscriptionList.compactMap({ $0.sku })
                if productIds.isEmpty {
                    self?.fetchProductsCompletion?(.failure(LinkFivePurchasesError.noProductIdsFound))
                } else {
                    let request = SKProductsRequest(productIdentifiers: Set(productIds))
                    request.delegate = self
                    request.start()
                }
            }
        })
    }
    
    /// Purchases the given `product`.
    /// - Parameters:
    ///     - product: The product to purchase
    ///     - completion: The completion of the payment.
    public func purchase(product: SKProduct, completion: @escaping (Result<Bool>) -> Void) {
        buyProductCompletion = completion
        guard SKPaymentQueue.canMakePayments() else {
            buyProductCompletion?(.failure(LinkFivePurchasesError.cantMakePayments))
            return
        }
        
        productToPurchase = product
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    /// Purchases the product for given `productId`.
    /// - Parameters:
    ///     - product: The product to purchase
    ///     - completion: The completion of the payment.
    public func purchase(productId: String, completion: @escaping (Result<Bool>) -> Void) {
        buyProductCompletion = completion
        guard SKPaymentQueue.canMakePayments() else {
            buyProductCompletion?(.failure(LinkFivePurchasesError.cantMakePayments))
            return
        }
        
        guard let product = products.first(where: { $0.productIdentifier == productId }) else {
            buyProductCompletion?(.failure(LinkFivePurchasesError.noProductFound))
            return
        }
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    /// Restores any purchases if available.
    /// - Parameters:
    ///     - completion: The completion of the restore. Returns whether the restore was successful.
    public func restore(completion: @escaping (Result<Bool>) -> Void) {
        buyProductCompletion = completion
        totalRestoredPurchases = 0
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    /// Fetches the receipt info from cache or from the server, depending on given `fromCache`.
    /// - Parameters:
    ///     - fromCache: Whether to get the receipt info from cache or from the server.
    ///     - completion: The completion of the receiptInfo call. Returns a `LinkFiveReceiptInfo`.
    public func fetchReceiptInfo(fromCache: Bool = true, completion: @escaping (Result<[LinkFiveReceipt]>) -> Void) {
        if fromCache, let receipts = LinkFiveUserDefaults.shared.receipts {
            completion(.success(receipts))
        } else {
            verifyReceipt(completion: completion)
        }
    }
    
    private func verifyReceipt(completion: ((Result<[LinkFiveReceipt]>) -> Void)? = nil) {
        guard let apiClient = apiClient else {
            completion?(.failure(LinkFivePurchasesError.launchSdkNeeded))
            return
        }
        
        guard let receipt = receipt else {
            completion?(.failure(LinkFivePurchasesError.noReceiptInfo))
            return
        }
        
        apiClient.verify(receipt: receipt, completion: { [weak self] result in
            switch result {
            case .success(let response):
                let receipts = response.data.purchases
                self?.userDefaults.receipts = receipts
                completion?(.success(receipts))
            case .failure(let error):
                LinkFiveLogger.debug(error)
            }
        })
    }
    
    private func logPurchaseToLinkFive(transaction: SKPaymentTransaction) {
        guard let product = productToPurchase else { return }
        
        apiClient?.purchase(product: product, transaction: transaction, completion: { result in
            switch result {
            case .failure(let error):
                LinkFiveLogger.debug(error)
            case .success:
                self.productToPurchase = nil
            }
        })
    }
}


//#################################################################################
// MARK: - SKProductsRequestDelegate
//#################################################################################

extension LinkFivePurchases: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        guard !response.products.isEmpty else {
            fetchProductsCompletion?(.failure(LinkFivePurchasesError.noProductsFound))
            return
        }
        
        products = response.products

        fetchProductsCompletion?(.success(response.products))
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        fetchProductsCompletion?(.failure(error))
    }
}


//#################################################################################
// MARK: - SKPaymentTransactionObserver
//#################################################################################

extension LinkFivePurchases: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        transactions.forEach { transaction in
            switch transaction.transactionState {
            case .purchased:
                logPurchaseToLinkFive(transaction: transaction)
                buyProductCompletion?(.success(true))
                SKPaymentQueue.default().finishTransaction(transaction)
                verifyReceipt()
            case .restored:
                totalRestoredPurchases += 1
                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed:
                if let error = transaction.error as? SKError {
                    if error.code != .paymentCancelled {
                        buyProductCompletion?(.failure(error))
                    } else {
                        buyProductCompletion?(.failure(LinkFivePurchasesError.paymentWasCancelled))
                    }
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        if totalRestoredPurchases != 0 {
            buyProductCompletion?(.success(true))
        } else {
            buyProductCompletion?(.success(false))
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        if let error = error as? SKError {
            if error.code != .paymentCancelled {
                buyProductCompletion?(.failure(error))
            } else {
                buyProductCompletion?(.failure(LinkFivePurchasesError.paymentWasCancelled))
            }
        }
    }
}
