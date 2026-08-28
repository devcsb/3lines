import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration interval;

  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.interval = AppMotion.micro,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.entrance,
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standardCurve),
    );
    _offset = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _controller, curve: AppMotion.standardCurve),
        );

    // 지연은 index 에 비례하되, 검색 결과처럼 항목이 많을 때 뒤쪽이 오래
    // 안 보이는 것을 막으려 상한을 둔다(최대 480ms). Timer 는 dispose 시 취소해
    // 이탈 후 콜백이 State 를 붙잡지 않게 한다.
    final cappedIndex = widget.index.clamp(0, 4);
    _delayTimer = Timer(widget.interval * cappedIndex, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // reduce-motion(동작 줄이기): 지연/페이드 없이 최종 상태로 즉시 표시.
    if (AppMotion.reduceMotion(context)) {
      _delayTimer?.cancel();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
