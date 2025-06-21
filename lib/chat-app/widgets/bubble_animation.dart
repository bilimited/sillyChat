import 'package:flutter/material.dart';

class BubbleAnimation extends StatefulWidget {
  final Widget child;

  const BubbleAnimation({Key? key, required this.child}) : super(key: key);

  @override
  State<BubbleAnimation> createState() => _BubbleAnimationState();
}

class _BubbleAnimationState extends State<BubbleAnimation> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: widget.child,
    );
  }
}
