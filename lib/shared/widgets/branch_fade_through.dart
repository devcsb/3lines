import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Animates one active navigation branch without mounting two shell keys.
class BranchFadeThrough extends StatefulWidget {
  const BranchFadeThrough({
    super.key,
    required this.transitionKey,
    required this.child,
  });

  final Object transitionKey;
  final Widget child;

  @override
  State<BranchFadeThrough> createState() => _BranchFadeThroughState();
}

class _BranchFadeThroughState extends State<BranchFadeThrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  var _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.standard,
      value: 1.0,
      vsync: this,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standardCurve,
    );
    _opacity = curved;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.015),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduceMotion(context);
    if (_reduceMotion) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant BranchFadeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionKey == widget.transitionKey) return;
    if (_reduceMotion) {
      _controller.value = 1.0;
    } else {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: const ValueKey<String>('branch-fade-through'),
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
