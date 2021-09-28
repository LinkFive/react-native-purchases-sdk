//
//  LinkFiveAPIClient.swift
//  LinkFivePurchases
//
//  Created by Tan Nghia La on 14.07.21.
//  Copyright © 2021 LinkFive. All rights reserved.
//

import Foundation
import StoreKit

class LinkFiveAPIClient {
    
    //#################################################################################
    // MARK: - Enums
    //#################################################################################
    
    enum HttpMethod: String {
        case GET
        case POST
    }
    
    
    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let apiKey: String
    private let environment: LinkFiveEnvironment
    
    private var header: [String: String] {
        return ["Authorization": "Bearer \(apiKey)",
                "X-Platform": "IOS",
                "X-Country": Locale.current.regionCode ?? "",
                "X-App-Version": (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "NO_APP_VERSION"]
    }
    
    private lazy var decodingDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.000'Z'"
        return dateFormatter
    }()
    
    private lazy var iso8601DateFormatter: ISO8601DateFormatter = {
        let iso8601DateFormatter = ISO8601DateFormatter()
        iso8601DateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso8601DateFormatter
    }()
    
    
    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Initializes the API Client.
    /// - Parameters:
    ///     - apiKey: Your LinkFive API key.
    ///     - environment: Your current environment.
    init(apiKey: String, environment: LinkFiveEnvironment) {
        self.apiKey = apiKey
        self.environment = environment
    }
    
    
    //#################################################################################
    // MARK: - Public API
    //#################################################################################

    /// Fetches and returns the available subscriptions.
    /// - Parameters:
    ///     - completion: The completion of the subscription fetch.
    func fetchSubscriptions(completion: @escaping (Result<LinkFiveSubscriptionList>) -> Void) {
        request(path: "v1/subscriptions", httpMethod: HttpMethod.GET, completion: completion)
    }
    
    /// Verifies the receipt with the given parameters.
    /// - Parameters:
    ///     - receipt: The receipt.
    func verify(receipt: String, completion: @escaping (Result<LinkFiveReceiptInfo>) -> Void) {
        let body = LinkFiveReceiptInfo.Request(receipt: receipt).json
        request(path: "v1/purchases/apple/verify", httpMethod: HttpMethod.POST, body: body, completion: completion)
    }
    
    /// Tells LinkFive that a product has been purchased.
    /// - Parameters:
    ///     - product: The purchased product.
    ///     - transaction: The transaction..
    func purchase(product: SKProduct, transaction: SKPaymentTransaction, completion: @escaping (Result<EmptyResponse>) -> Void) {
        let body = LinkFivePurchase.Request(sku: product.productIdentifier,
                                            country: product.priceLocale.regionCode ?? "",
                                            currency: product.priceLocale.currencyCode ?? "",
                                            price: product.price.doubleValue,
                                            transactionId: transaction.transactionIdentifier ?? "",
                                            originalTransactionId: transaction.original?.transactionIdentifier ?? transaction.transactionIdentifier ?? "",
                                            purchaseDate: iso8601DateFormatter.string(from: (transaction.transactionDate ?? Date()))).json
        
        request(path: "v1/purchases/apple", httpMethod: HttpMethod.POST, body: body, completion: completion)
    }
    
    private func request<M: Codable>(path: String,
                                     httpMethod: HttpMethod,
                                     body: JSON? = nil,
                                     completion: @escaping (Result<M>) -> Void) {
        var request = URLRequest(url: environment.url.appendingPathComponent(path))
        request.httpMethod = httpMethod.rawValue
        request.allHTTPHeaderFields = header
        
        if let body = body {
            request.updateHTTPBody(parameter: body)
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(LinkFivePurchasesAPIError.noData))
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(self.decodingDateFormatter)
            
            if let httpResonse = response as? HTTPURLResponse, httpResonse.statusCode == 201 {
                completion(.success(EmptyResponse() as! M))
                return
            }
            
            do {
                let result = try decoder.decode(M.self, from: data)
                completion(.success(result))
            } catch {
                LinkFiveLogger.debug(error)
                completion(.failure(LinkFivePurchasesAPIError.decoding))
            }
        }.resume()
    }
}


//#################################################################################
// MARK: - LinkFivePurchasesAPIError
//#################################################################################

enum LinkFivePurchasesAPIError: Error {
    
    /// There is no data.
    case noData
    
    /// There was a decoding error.
    case decoding
}


//#################################################################################
// MARK: - Private extensions
//#################################################################################

public typealias JSON = [String: Any]

private extension Encodable {
    
    var json: JSON {
        guard let data = try? JSONEncoder().encode(self),
            let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? JSON else {
                assertionFailure(String(describing: self) + " must be encodable to JSON")
                return JSON()
        }
        return json
    }
}

private extension URLRequest {
    
    mutating func updateHTTPBody(parameter: [String: Any]) {
        guard let jsonData: Data = try? JSONSerialization.data(withJSONObject: parameter, options: []) else {
            assertionFailure("Could not serialize JSON")
            return
        }
        setValue("application/json", forHTTPHeaderField: "Accept")
        setValue("application/json", forHTTPHeaderField: "Content-Type")
        setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
        httpBody = jsonData
    }
}
