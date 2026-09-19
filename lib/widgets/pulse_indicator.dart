import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Radar-style animation used while scanning / waiting for a sender.
class PulseIndicator extends StatefulWidget {
  const PulseIndicator({super.key, required this.icon, this.colors = AppColors.receiveGradient, this.size = 200});

  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _PulsePainter(_controller.value, widget.colors.last),
          child: Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: widget.colors),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 36),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.value, this.color);

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    const minRadius = 38.0;
    for (var i = 0; i < 3; i++) {
      final t = (value + i / 3) % 1;
      final paint = Paint()
        ..color = color.withOpacity((1 - t) * 0.28)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, minRadius + (maxRadius - minRadius) * t, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.value != value || old.color != color;
}
