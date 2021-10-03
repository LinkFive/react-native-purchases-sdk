package com.reactnativepurchasessdk

import android.util.Log
import com.facebook.react.bridge.*
import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.features.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import java.util.*
import com.google.gson.Gson;
import com.facebook.react.bridge.WritableMap






class PurchasesSdkModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
/*
    private val purchasesUpdatedListener =
    PurchasesUpdatedListener { billingResult, purchases ->
        // To be implemented in a later section.
    }

    private var billingClient = BillingClient.newBuilder(activity)
      .setListener(purchasesUpdatedListener)
      .enablePendingPurchases()
      .build()
*/
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
      Log.d("TAG", environmentType.url)
      Log.d("TAG", apiKey)
      val versionName = reactApplicationContext.packageManager.getPackageInfo(reactApplicationContext.packageName, 0).versionName
      LinkFivePurchases.launch(apiKey, environment = environmentType, versionName)

      promise.resolve("$apiKey $environment")
    }

    @ReactMethod
    fun fetchSubscriptions(promise: Promise) {
      Log.d("TAG", "fetchSubscriptions")
      val subscriptions = LinkFivePurchases.fetchSubscriptions()
      Log.d("TAG", subscriptions.toString())

      val result = WritableNativeArray()

      subscriptions.forEach {
        val map = Arguments.createMap()
        map.putString("countryCode", it.countryCode)
        map.putString("currency", it.currency)
        map.putString("description", it.description)
        map.putString("localizedPrice", it.localizedPrice)
        map.putDouble("price", it.price)
        map.putString("productId", it.productId)
        map.putString("subscriptionPeriod", it.subscriptionPeriod)
        map.putString("title", it.title)
        result.pushMap(map)
      }

      promise.resolve(result)
    }

    @ReactMethod
    fun purchase(productId: String, promise: Promise) {

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

  fun launch(apiKey: String, environment: LinkFiveEnvironment, versionName: String) {
    apiClient = LinkFiveApiClient(apiKey, environment, versionName);
  }

  fun fetchSubscriptions(): Array<LinkFiveProduct> {
    Log.d("Tag", "LinkFivePurchases fetchSubscriptions")
    if (!::apiClient.isInitialized) {
      throw LaunchSdkNeededException()
    }
/*
    val response = apiClient.fetchSubscriptions()
    Log.d("Log", response.toString())
*/

    return arrayOf(LinkFiveProduct("abc", 5.0, "euro", "de", "test", "test subscription", "5€", "1pm"))
  }
}

class LinkFiveApiClient(private val apiKey: String, private val environment: LinkFiveEnvironment, private val versionName: String) {
  private val client = HttpClient(CIO) {
    defaultRequest {
      header("Authorization", " Bearer $apiKey")
      header("X-Platform", "GOOGLE")
      header("X-Country", Locale.getDefault().country)
      header("X-App-Version", versionName)
    }
  }

  suspend fun fetchSubscriptions(): HttpResponse {
    val response: HttpResponse = client.get("${environment.url}/v1/subscriptions")
    Log.d("TAG", response.toString())
    
    return response
  }

  suspend fun verify() {
    val response: HttpResponse = client.get("${environment.url}/purchases/apple/verify")
  }

  suspend fun purchase() {
    val response: HttpResponse = client.get("${environment.url}/v1/purchases/google")
  }
}

enum class LinkFiveEnvironment(val url: String) {
  STAGING("https://api.staging.linkfive.io/api"), PRODUCTION("https://api.linkfive.io/api")
}

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
  val countryCode: String,
  val title: String,
  val description: String,
  val localizedPrice: String,
  val subscriptionPeriod: String
)

class LaunchSdkNeededException(message: String = "Launch SDK needed.") : Exception(message)
class NoProductIdsFoundException(message: String) : Exception(message)
class NoProductsFoundException(message: String) : Exception(message)
class CantMakePaymentsException(message: String) : Exception(message)
