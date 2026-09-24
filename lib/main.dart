import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'providers/history_provider.dart';
import 'providers/nearby_provider.dart';
import 'providers/pc_share_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transfer_provider.dart';
import 'services/file_service.dart';
import 'services/nearby_service.dart';
import 'services/pc_share_service.dart';
import 'services/permission_service.dart';
import 'services/storage_service.dart';
import 'services/system_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final system = SystemService();
  final nearbyService = NearbyService();
  final fileService = FileService();
  final storage = StorageService(system);
  final permissions = PermissionService(system);

  final settings = SettingsProvider(system);
  final history = HistoryProvider();
  final nearby = NearbyProvider(nearbyService, settings);
  final transfer = TransferProvider(
    nearby: nearby,
    service: nearbyService,
    files: fileService,
    storage: storage,
    history: history,
    system: system,
  );
  final pcShare = PcShareProvider(PcShareService(storage), system, history);

  // Fire and forget: load persisted state and clear leftovers from interrupted transfers.
  settings.load();
  history.load();
  storage.clearStaging();

  runApp(
    MultiProvider(
      providers: [
        Provider<SystemService>.value(value: system),
        Provider<PermissionService>.value(value: permissions),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<HistoryProvider>.value(value: history),
        ChangeNotifierProvider<NearbyProvider>.value(value: nearby),
        ChangeNotifierProvider<TransferProvider>.value(value: transfer),
        ChangeNotifierProvider<PcShareProvider>.value(value: pcShare),
      ],
      child: const NearbyShareApp(),
    ),
  );
}
