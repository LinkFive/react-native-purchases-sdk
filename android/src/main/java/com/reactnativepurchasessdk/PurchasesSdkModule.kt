package com.reactnativepurchasessdk

import android.app.Activity
import android.util.Log
import com.android.billingclient.api.*
import com.facebook.react.bridge.*
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.features.*
import io.ktor.client.features.json.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import kotlinx.coroutines.*
import java.util.*


class PurchasesSdkModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String {
        return "PurchasesSdk"
    }

    // Example method
    // See https://reactnative.dev/docs/native-modules-android
    @ReactMethod
    fun multiply(a: Int, b: Int, promise: Promise) {

      promise.resolve(a * b)
    }

    @ReactMethod
    fun launch(apiKey: String, environment: String, promise: Promise) {
      val environmentType = LinkFiveEnvironment.valueOf(environment)
      val versionName = reactApplicationContext.packageManager.getPackageInfo(reactApplicationContext.packageName, 0).versionName

      reactApplicationContext.currentActivity?.let {
        LinkFivePurchases.launch(apiKey, environment = environmentType, versionName, activity = it)
        promise.resolve("$apiKey $environment")
      } ?: run {
        promise.reject(NoActivityFoundException())
      }
    }

    @ReactMethod
    fun fetchSubscriptions(promise: Promise) {
      Logger.v("Start to fetch subscriptions")
      GlobalScope.launch {

        try {
          LinkFivePurchases.fetchSubscriptions { result ->

            val subscriptions = result.getOrThrow()
            val products = WritableNativeArray()
            subscriptions.forEach {
              val map = Arguments.createMap()
              map.putString("currency", it.currency)
              map.putString("description", it.description)
              map.putString("localizedPrice", it.localizedPrice)
              map.putDouble("price", it.price)
              map.putString("productId", it.productId)
              map.putString("subscriptionPeriod", it.subscriptionPeriod)
              map.putString("title", it.title)
              products.pushMap(map)
            }

            promise.resolve(products)
          }
        } catch (cause: Throwable) {
          promise.reject(cause)
        }
      }
    }

    @ReactMethod
    fun purchase(productId: String, promise: Promise) {
      GlobalScope.launch {
        reactApplicationContext.currentActivity?.let {
          try {
            LinkFivePurchases.purchase(productId, activity = it, callback = { result ->
              val succeeded = result.getOrThrow()
              promise.resolve(succeeded)
            })
          } catch (cause: Throwable) {
            Logger.e(cause.localizedMessage)
            promise.reject(cause)
          }
        } ?: run {
          promise.reject(NoActivityFoundException())
        }
      }
    }

    @ReactMethod
    fun restore(promise: Promise) {
      // Not needed
    }

    @ReactMethod
    fun fetchReceiptInfo(fromCache: Boolean, promise: Promise) {

    }
}

object LinkFivePurchases {

  private lateinit var apiClient: LinkFiveApiClient
  private lateinit var billingClient: BillingClient
  private var skuDetailList: List<SkuDetails> = emptyList()

  private lateinit var fetchSubscriptionsCallback: (Result<List<LinkFiveProduct>>) -> Unit
  private lateinit var purchaseCallback: (Result<Boolean>) -> Unit

  private val purchasesUpdatedListener =
    PurchasesUpdatedListener { billingResult, purchases ->
      Logger.d("Billing update: ", billingResult, purchases)

      if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && !purchases.isNullOrEmpty()) {

        GlobalScope.launch {
          // TODO: Send purchase to linkfive server
          apiClient.verify()
        }
        purchaseCallback(Result.success(true))
      } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
        purchaseCallback(Result.failure(UserCancelledPaymentException()))
      } else {
        purchaseCallback(Result.failure(CantMakePaymentsException()))
      }

    }

  fun launch(apiKey: String, environment: LinkFiveEnvironment, versionName: String, activity: Activity) {
    apiClient = LinkFiveApiClient(apiKey, environment, versionName)
    billingClient = BillingClient.newBuilder(activity)
      .setListener(purchasesUpdatedListener)
      .enablePendingPurchases()
      .build()
  }

  suspend fun purchase(productId: String, activity: Activity, callback: (Result<Boolean>) -> Unit) {
    this.purchaseCallback = callback

    skuDetailList.find { it.sku == productId }?.let {
      val flowParams = BillingFlowParams.newBuilder()
        .setSkuDetails(it)
        .build()

      val responseCode = billingClient.launchBillingFlow(activity, flowParams).responseCode
      Logger.v("Billing ResponseCode: $responseCode")
    } ?: run {
      purchaseCallback(Result.failure(ProductIdNotFoundException()))
    }
  }

  suspend fun fetchSubscriptions(callback: (Result<List<LinkFiveProduct>>) -> Unit) {
    Log.d("Tag", "LinkFivePurchases fetchSubscriptions")
    if (!::apiClient.isInitialized) {
      throw LaunchSdkNeededException()
    }

    val response = apiClient.fetchSubscriptions()
    val skus = response.subscriptionList.map { it.sku }
    fetchSubscriptionsCallback = callback

    billingClient.startConnection(object : BillingClientStateListener {
      override fun onBillingSetupFinished(billingResult: BillingResult) {
        if (billingResult.responseCode ==  BillingClient.BillingResponseCode.OK) {
          Logger.v("Google Billing connected")

          GlobalScope.launch {
            val products = fetchLinkFiveProducts(skus)

            if (products.isEmpty()) {
              fetchSubscriptionsCallback(Result.failure(NoProductsFoundException()))
            } else {
              fetchSubscriptionsCallback(Result.success(products))
            }
          }
        } else {
          fetchSubscriptionsCallback(Result.failure(DeviceNotSupportedException()))
        }
      }
      override fun onBillingServiceDisconnected() {
        // Try to restart the connection on the next request to
        // Google Play by calling the startConnection() method.
        Logger.v("Google Billing disconnected.")
      }
    })
  }

  private suspend fun fetchLinkFiveProducts(skus: List<String>): List<LinkFiveProduct> {
    val params = SkuDetailsParams.newBuilder()
    params.setSkusList(skus).setType(BillingClient.SkuType.SUBS)

    val skuDetailsResult = billingClient.querySkuDetails(params.build())

    skuDetailsResult.skuDetailsList?.let { skuDetailList ->
      this.skuDetailList = skuDetailList
      return skuDetailList.map { LinkFiveProduct(currency = it.priceCurrencyCode, description = it.description, localizedPrice = it.price, price = it.priceAmountMicros.toDouble() / 1000000, title = it.title, productId = it.sku, subscriptionPeriod = it.subscriptionPeriod) }
    } ?: run {
      this.skuDetailList = emptyList()
      return emptyList()
    }

  }
}

class LinkFiveApiClient(private val apiKey: String, private val environment: LinkFiveEnvironment, private val versionName: String) {
  private val client = HttpClient(CIO) {
    install(JsonFeature) {
      serializer = GsonSerializer() {
        setPrettyPrinting()
        disableHtmlEscaping()
      }
    }
    defaultRequest {
      header("Authorization", " Bearer $apiKey")
      header("X-Platform", "GOOGLE")
      header("X-Country", Locale.getDefault().country)
      header("X-App-Version", versionName)
    }
  }

  suspend fun fetchSubscriptions(): LinkFiveSubscriptionList {
    try {
      val url = "${environment.url}/v1/subscriptions"
      Log.d("TAG", url)
      val response: LinkFiveSubscriptionListResponse = client.get(url)
      Log.d("TAG", response.toString())

      return response.data
    } catch (cause: Throwable) {
      Log.d("TAG", cause.localizedMessage)
      throw cause
    }
  }

  suspend fun verify() {
    val response: HttpResponse = client.post("${environment.url}/v1/purchases/google/verify")
  }
}

enum class LinkFiveEnvironment(val url: String) {
  STAGING("https://api.staging.linkfive.io/api"), PRODUCTION("https://api.linkfive.io/api")
}

data class LinkFiveSubscriptionListResponse(
  val data: LinkFiveSubscriptionList
)

data class LinkFiveSubscriptionList(
  val platform: String,
  val attributes: String?,
  val subscriptionList: List<LinkFiveSubscription>
)

data class LinkFiveSubscription(
  val sku: String
)

data class LinkFiveProduct(
  val productId: String,
  val price: Double,
  val currency: String,
  val title: String,
  val description: String,
  val localizedPrice: String,
  val subscriptionPeriod: String
)

class LaunchSdkNeededException(message: String = "Launch SDK needed.") : Exception(message)
class NoActivityFoundException(message: String = "No activity found.") : Exception(message)
class ProductIdNotFoundException(message: String = "Given product id does not exist") : Exception(message)
class NoProductsFoundException(message: String = "No products found") : Exception(message)
class CantMakePaymentsException(message: String = "Payment went wrong") : Exception(message)
class DeviceNotSupportedException(message: String = "Device not supported.") : Exception(message)
class UserCancelledPaymentException(message: String = "User cancelled payment.") : Exception(message)

object Logger {

  fun d(vararg msg: Any?) {
    msg.forEach {
      Log.d("LinkFive", it.toString())
    }
  }

  fun v(vararg msg: Any?) {
    msg.forEach {
      Log.v("LinkFive", it.toString())
    }
  }

  fun e(vararg msg: Any?) {
    msg.forEach {
      Log.e("LinkFive", it.toString())
    }
  }
}
