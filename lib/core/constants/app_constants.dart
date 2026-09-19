class AppConstants {
  AppConstants._();

  static const String appName = 'Nearby Share';
  static const String tagline = 'Fast file sharing. No internet required.';

  /// Both phones must use the same service id to see each other.
  static const String serviceId = 'com.nearbyshare.nearby_share';

  static const String receivedFolderLabel = 'Downloads/Nearby Share/Received';

  static const int maxFilesPerTransfer = 200; // keeps the offer under the 32 KB bytes-payload limit
  static const int maxHistoryItems = 200;

  static const Duration scanHintDelay = Duration(seconds: 10);
  static const Duration connectTimeout = Duration(seconds: 25);
  static const Duration verifyTimeout = Duration(seconds: 90);
  static const Duration offerTimeout = Duration(seconds: 90);
  static const Duration ackTimeout = Duration(seconds: 20);

  static const String prefsHistoryKey = 'transfer_history_v1';
  static const String prefsDeviceNameKey = 'custom_device_name';
}
