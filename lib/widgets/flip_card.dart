import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A 3D card flip: rotates around the Y axis with a perspective entry on the
/// matrix, so the front and back faces trade places as the animation runs.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.flipped,
    required this.front,
    required this.back,
    this.height = 224,
    this.onTap,
  });

  /// True while the back face is shown.
  final bool flipped;
  final Widget front;
  final Widget back;
  final double height;
  final VoidCallback? onTap;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    if (widget.flipped) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flipped == oldWidget.flipped) return;
    if (widget.flipped) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double angle = _controller.value * math.pi;
            final bool showFront = angle < math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(showFront ? 0 : math.pi),
                child: showFront ? widget.front : widget.back,
              ),
            );
          },
        ),
      ),
    );
  }
}
