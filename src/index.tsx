import { NativeModules } from 'react-native';

type PurchasesSdkType = {
  launch(apiKey: string, environment: string): Promise<string>;
  fetchSubscriptions(): Promise<any[]>;
  purchase(productId: string): Promise<boolean>;
  restore(): Promise<boolean>;
  fetchReceiptInfo(fromCache: boolean): Promise<any[]>;
};

const { PurchasesSdk } = NativeModules;

export default PurchasesSdk as PurchasesSdkType;
