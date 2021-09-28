import { NativeModules } from 'react-native';

type PurchasesSdkType = {
  multiply(a: number, b: number): Promise<number>;
};

const { PurchasesSdk } = NativeModules;

export default PurchasesSdk as PurchasesSdkType;
