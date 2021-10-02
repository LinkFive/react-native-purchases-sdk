# react-native-purchases-sdk

LinkFive Subscription Management.

## Installation

```sh
npm install react-native-purchases-sdk
```

## Start example

- iOS: yarn example ios
- Android:
  - Change local Java version to 15 - `export JAVA_HOME=`/usr/libexec/java_home -v 15.0.2``
  - yarn example android

## Usage

```js
import PurchasesSdk from "react-native-purchases-sdk";

// ...

const result = await PurchasesSdk.multiply(3, 7);
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
