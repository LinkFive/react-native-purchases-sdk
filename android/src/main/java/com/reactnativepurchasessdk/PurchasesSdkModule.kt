package com.reactnativepurchasessdk

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise

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
      LinkFivePurchases.launch(apiKey, environment = environmentType)
    }

    @ReactMethod
    fun purchase(productId: String, promise: Promise) {

    }

    @ReactMethod
    fun restore(promise: Promise) {
      // Not needed
    }

    @ReactMethod
    fun fetchReceiptInfo(promise: Promise) {

    }
}

object LinkFivePurchases {

  private lateinit var apiClient: LinkFiveApiClient

  fun launch(apiKey: String, environment: LinkFiveEnvironment) {
    apiClient = LinkFiveApiClient(apiKey, environment);
  }

  suspend fun fetchSubscriptions() {
    if (!::apiClient.isInitialized) {
      throw LaunchSdkNeededException()
    }
  }
}

class LinkFiveApiClient(apiKey: String, environment: LinkFiveEnvironment) {
  private val apiKey = apiKey;
  private val environment = environment;

  suspend fun fetchSubscriptions() {

  }

  suspend fun verify() {

  }

  suspend fun purchase() {

  }
}

enum class LinkFiveEnvironment(val url: String) {
  STAGING("https://api.staging.linkfive.io/api/"), PRODUCTION("https://api.linkfive.io/api/")
}

data class LinkFiveSubscriptionList(
  val platform: String,
  val attributes: String?,
  val subscriptionList: List<LinkFiveSubscription>
)

data class LinkFiveSubscription(
  val sku: String
)

class LaunchSdkNeededException(message: String = "Launch SDK needed.") : Exception(message)
class NoProductIdsFoundException(message: String) : Exception(message)
class NoProductsFoundException(message: String) : Exception(message)
class CantMakePaymentsException(message: String) : Exception(message)
