import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../providers/nearby_provider.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/verification_view.dart';

/// Sender side: connecting -> verification code -> confirmed -> file selection.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late final NearbyProvider _nearby;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _nearby = context.read<NearbyProvider>();
    _nearby.addListener(_onChange);
  }

  @override
  void dispose() {
    _nearby.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!_navigated && mounted && _nearby.phase == LinkPhase.connected) {
      _navigated = true;
      Navigator.pushReplacementNamed(context, Routes.selection);
    }
  }

  Future<void> _leave({bool reject = false}) async {
    _navigated = true; // stop reacting to further changes
    final navigator = Navigator.of(context);
    navigator.pop();
    await _nearby.abandonConnection(reject: reject);
  }

  @override
  Widget build(BuildContext context) {
    final nearby = context.watch<NearbyProvider>();
    final peer = nearby.peerName ?? 'the other device';

    Widget body;
    switch (nearby.phase) {
      case LinkPhase.connecting:
        body = _Loading(title: 'Connecting to $peer…', subtitle: 'Waiting for $peer to respond');
        break;
      case LinkPhase.verifying:
        body = VerificationView(
          code: nearby.verificationCode ?? '',
          peerName: peer,
          onAccept: nearby.acceptVerification,
          onReject: () => _leave(reject: true),
        );
        break;
      case LinkPhase.finalizing:
        body = VerificationView(
          code: nearby.verificationCode ?? '',
          peerName: peer,
          waiting: true,
          onAccept: () {},
          onReject: () {},
        );
        break;
      case LinkPhase.rejected:
      case LinkPhase.failed:
      case LinkPhase.disconnected:
        body = EmptyState(
          icon: Icons.link_off_rounded,
          color: AppColors.danger,
          title: 'Connection failed',
          message: nearby.errorMessage ?? 'The connection with $peer was lost.',
          actionLabel: 'Back to devices',
          onAction: _leave,
        );
        break;
      default:
        body = const _Loading(title: 'Connected', subtitle: 'Opening file selection…');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connect'),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _leave),
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(title, style: AppTypography.title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTypography.secondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
