import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'io.bililive.mobile',
  appName: 'biliLive Tools',
  webDir: 'www',
  bundledWebRuntime: false,
  loggingBehavior: 'production',
  ios: {
    contentInset: 'automatic',
    backgroundColor: '#0b1020',
    scrollEdgeAppearance: 'dark',
    limitsNavigationsToAppBoundDomains: false,
    preferredContentMode: 'mobile',
    // 强制按已嵌入的 webview 走 https 协议
    allowsArbitraryLoads: true,
  },
  android: {
    backgroundColor: '#0b1020',
    allowMixedContent: true,
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 600,
      backgroundColor: '#0b1020',
      androidSplashResourceName: 'splash',
      showSpinner: false,
    },
  },
};

export default config;
