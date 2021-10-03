import StoreKit

@objc(PurchasesSdk)
class PurchasesSdk: NSObject {

    private let linkfivePurchases = LinkFivePurchases.shared

    @objc(multiply:withB:withResolver:withRejecter:)
    func multiply(a: Float, b: Float, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        resolve(a*b)
    }

    @objc(launch:withEnvironment:withResolver:withRejecter:)
    func launch(apiKey: String, environment: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        let environment = LinkFiveEnvironment(rawValue: environment) ?? .staging
        linkfivePurchases.launch(with: apiKey, environment: environment)
        resolve("\(apiKey) + \(environment)")
    }

    @objc(fetchSubscriptions:withRejecter:)
    func fetchSubscriptions(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        linkfivePurchases.fetchSubscriptions { result in
            switch result {
            case .failure(let error):
                reject("error", error.localizedDescription, error)
            case .success(let products):
                resolve(products.map({ $0.asDictionary }))
            }
        }
    }

   @objc(purchase:withResolver:withRejecter:)
   func purchase(productId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
       linkfivePurchases.purchase(productId: productId) { result in
           switch result {
           case .failure(let error):
               reject("error", error.localizedDescription, error)
           case .success(let succeeded):
               resolve(succeeded)
           }
       }
   }

   @objc(restore:withRejecter:)
   func restore(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
       linkfivePurchases.restore { result in
           switch result {
           case .failure(let error):
               reject("error", error.localizedDescription, error)
           case .success(let succeeded):
               resolve(succeeded)
           }
       }
   }

   @objc(fetchReceiptInfo:withResolver:withRejecter:)
   func purchase(fromCache: Bool, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
       linkfivePurchases.fetchReceiptInfo(fromCache: fromCache) { result in
           switch result {
           case .failure(let error):
               reject("error", error.localizedDescription, error)
           case .success(let receipts):
               resolve(receipts.map({ $0.asDictionary }))
           }
       }
   }
}

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

public enum LinkFiveEnvironment: String {
    case production = "PRODUCTION"
    case staging = "STAGING"

    /// The url for the environment.
    var url: URL {
        switch self {
        case .production:
            return URL(string: "https://api.linkfive.io/api/")!
        case .staging:
            return URL(string: "https://api.staging.linkfive.io/api/")!
        }
    }
}

public enum Result<T> {

    case success(T)
    case failure(Error)

    /// The value of the result.
    public var value: T? {
        switch self {
        case .success(let value):
            return value
        default:
            return nil
        }
    }

    /// The error of the result.
    public var error: Error? {
        switch self {
        case .failure(let error):
            return error
        default:
            return nil
        }
    }
}

struct LinkFiveLogger {

    /// Prints the given `object` only in debug mode.
    /// - Parameters:
    ///     - object: The object to print.
    static func debug(_ object: Any) {
        #if DEBUG
            debugPrint(object)
        #endif
    }
}

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

struct EmptyResponse: Codable {}

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
    
    private static var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return dateFormatter
    }
    
    /// Returns the receipt as dictionary
    var asDictionary: [String: Any?] {
        return [
            "sku": sku,
            "purchaseId": purchaseId,
            "transactionDate": LinkFiveReceipt.dateFormatter.string(from: transactionDate),
            "validUntilDate": LinkFiveReceipt.dateFormatter.string(from: validUntilDate),
            "isExpired": isExpired,
            "isTrial": isTrial,
            "period": period,
            "familyName": familyName,
            "attributes": attributes
        ]
    }
}

extension SKProduct {

    /// Returns the product as dictionary
    var asDictionary: [String: Any?] {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceLocale

        let localizedPrice = formatter.string(from: price)
        let numOfUnits = UInt(subscriptionPeriod?.numberOfUnits ?? 0)
        let unit = subscriptionPeriod?.unit
        var periodUnitIOS = "M"
        if unit == .year {
            periodUnitIOS = "Y"
        } else if unit == .month {
            periodUnitIOS = "M"
        } else if unit == .week {
            periodUnitIOS = "W"
        } else if unit == .day {
            periodUnitIOS = "D"
        }

        return [
            "productId" : productIdentifier,
            "price" : "\(price)",
            "currency" : priceLocale.currencyCode,
            "title" : localizedTitle,
            "description" : localizedDescription,
            "localizedPrice" : localizedPrice,
            "subscriptionPeriod" : "P\(numOfUnits)\(periodUnitIOS)"
        ]
    }
}
