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
