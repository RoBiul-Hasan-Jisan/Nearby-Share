import 'package:flutter/material.dart';
import '../screens/connection/connection_screen.dart';
import '../screens/discovery/discovery_screen.dart';
import '../screens/file_picker/file_selection_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/receiving/receiving_screen.dart';
import '../screens/sending/sending_screen.dart';
import '../screens/settings/settings_screen.dart';

class Routes {
  Routes._();

  static const String home = '/';
  static const String discovery = '/send/discovery';
  static const String connection = '/send/connection';
  static const String selection = '/send/selection';
  static const String sending = '/send/transfer';
  static const String receive = '/receive';
  static const String history = '/history';
  static const String settings = '/settings';

  static Route<dynamic> generate(RouteSettings s) {
    final Widget page;
    switch (s.name) {
      case discovery:
        page = const DiscoveryScreen();
        break;
      case connection:
        page = const ConnectionScreen();
        break;
      case selection:
        page = const FileSelectionScreen();
        break;
      case sending:
        page = const SendingScreen();
        break;
      case receive:
        page = const ReceiveScreen();
        break;
      case history:
        page = const HistoryScreen();
        break;
      case settings:
        page = const SettingsScreen();
        break;
      default:
        page = const HomeScreen();
    }
    return MaterialPageRoute<void>(settings: s, builder: (_) => page);
  }
}
