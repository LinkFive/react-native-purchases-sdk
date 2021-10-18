# react-native-purchases-sdk

LinkFive Subscription Management.

## Installation

```sh
npm install react-native-purchases-sdk
```

## Start example

- Add your applicationId to the `app/build.gradle`
- Add your bundle- and development id to the xcode project
- iOS: yarn example ios
- Android:
  - Change local Java version to lower than 16, for example - `export JAVA_HOME=`/usr/libexec/java_home -v 15.0.2``
  - yarn example android

## Usage

```js
import PurchasesSdk from 'react-native-purchases-sdk';

// ...
// Launch the SDK
await PurchasesSdk.launch('YOUR_API_KEY', 'STAGING');

// Fetch your subscriptions
const fetchedSubscriptions = await PurchasesSdk.fetchSubscriptions();

// Purchase a subscription
const success = await PurchasesSdk.purchase('YOUR_PRODUCT_ID');

// Fetch receipts
const receipts = await PurchasesSdk.fetchReceiptInfo(false);

// Restore (only iOS)
const success = await PurchasesSdk.restore();
```

## License

MIT
