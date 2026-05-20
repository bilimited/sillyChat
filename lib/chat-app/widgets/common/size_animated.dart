import 'package:flutter/material.dart';

class SizeAnimatedWidget extends StatefulWidget {
  final Widget child;
  final bool visible;
  final Duration duration;
  final Curve curve;

  const SizeAnimatedWidget({
    Key? key,
    required this.child,
    required this.visible,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutQuint,
  }) : super(key: key);

  @override
  State<SizeAnimatedWidget> createState() => _SizeAnimatedWidgetState();
}

class _SizeAnimatedWidgetState extends State<SizeAnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
    if (widget.visible) {
      _isVisible = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SizeAnimatedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        setState(() => _isVisible = true);
        _controller.forward();
      } else {
        _controller.reverse().then((value) {
          setState(() => _isVisible = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
