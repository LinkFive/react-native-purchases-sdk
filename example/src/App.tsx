import * as React from 'react';

import { StyleSheet, View, Text, Button, Alert, Platform } from 'react-native';
import PurchasesSdk from 'react-native-purchases-sdk';

export default function App() {
  const [subscriptions, setSubscriptions] = React.useState<any | undefined>();
  const [receipts, setReceipts] = React.useState<any | undefined>();
  const [launchDetails, setLaunchDetails] = React.useState<string | undefined>();

  function RestoreButton() {
    if (Platform.OS === 'ios') {
      return <Button onPress={async () => {
        const success = await PurchasesSdk.restore();
        console.log(`restore success: ${success}`);
        await fetchReceipts();
      }} title="Restore"></Button>
    }

    return <View/>
  }

  function SubscriptionButtons() {
    if (subscriptions == undefined || subscriptions.length == 0) {
      return <Text> No subscriptions... </Text>
    }

    const buttons = subscriptions.map((subscription: { productId: string; price: number;}) => <Button key={"btn_" + subscription.productId} onPress={async () => {
      const success = await PurchasesSdk.purchase(subscription.productId);
      console.log(`purchase success: ${success}`)
      await fetchReceipts();
    }} title={subscription.productId + " for " + subscription.price}></Button>)

    return buttons;
  }

  function Receipts() {
    if (receipts === undefined) {
      return <Text> No Receipts... </Text>
    }

    const texts = receipts.map((receipt: { sku: string; period: string | null | undefined; purchaseId: string; transactionDate: string; validUntilDate: string; attributes: string | null | undefined; familyName: string | null | undefined; isExpired: string; isTrial: string; }) => <Text key={receipt.sku}> { "sku: " + receipt.sku + "\nperiod: " + (receipt.period || "") + "\npurchaseId: " + receipt.purchaseId + "\ntransactionDate: " + receipt.transactionDate + "\nvalidUntilDate: " + receipt.validUntilDate + "\nattributes: " + (receipt.attributes || "") + "\nfamilyName: " + (receipt.familyName || "") + "\nisExpired: " + receipt.isExpired + "\nisTrial: " + receipt.isTrial}</Text>)
    return texts;
  }

  async function fetchReceipts() {
    try {
      const receipts = await PurchasesSdk.fetchReceiptInfo(false);
      if (receipts !== undefined) {
        setReceipts(receipts);
      }
    } catch (error) {
      console.log(error);
    }
  }

  React.useEffect(() => {
    async function fetch() {
      const launchDetails = await PurchasesSdk.launch("YOUR_API_KEY","STAGING")
      setLaunchDetails(launchDetails)
      console.log("launched")
      try {
        const fetchedSubscriptions = await PurchasesSdk.fetchSubscriptions()
        console.log("fetchedSubscriptions")
        setSubscriptions(fetchedSubscriptions)
        await fetchReceipts()
      } catch (error) {
        console.log(error)
      }
    }

    fetch();
  }, []);

  return (
    <View style={styles.container}>
      <Text style={{textAlignVertical: "center",textAlign: "center",}}> {launchDetails} </Text>

      <SubscriptionButtons />

      <View style={{ height: 20 }} />

      <RestoreButton/>

      <Receipts/>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
