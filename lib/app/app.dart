import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import 'routes.dart';
import 'theme.dart';

class NearbyShareApp extends StatelessWidget {
  const NearbyShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: Routes.home,
      onGenerateRoute: Routes.generate,
    );
  }
}
