import { NativeModules } from 'react-native';

type PurchasesSdkType = {
  multiply(a: number, b: number): Promise<number>;
  launch(apiKey: string, environment: string): Promise<string>;
  fetchSubscriptions(): Promise<any>;
};

const { PurchasesSdk } = NativeModules;

export default PurchasesSdk as PurchasesSdkType;
