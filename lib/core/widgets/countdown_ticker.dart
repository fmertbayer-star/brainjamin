import 'dart:async';

import 'package:flutter/material.dart';

import '../services/server_time_service.dart';

/// One-second ticking countdown for absolute wall-clock targets.
///
/// Uses [ServerTimeService.now] — do not use [DateTime.now] for gameplay targets.
///
/// Performance: [Timer.periodic] at 1s on a tab-scoped widget is fine; reuse this
/// on Live quiz / lobby rather than duplicating tickers.
class CountdownTicker extends StatefulWidget {
  const CountdownTicker({
    super.key,
    required this.targetUtc,
    required this.format,
    this.style,
    this.onZeroBuilder,
  });

  /// Target instant (same epoch semantics as [ServerTimeService.now] comparisons).
  final DateTime targetUtc;

  final TextStyle? style;

  /// Formats non-negative remaining duration.
  final String Function(Duration remaining) format;

  /// Optional widget when remaining <= 0 (e.g. "Live now").
  final Widget Function(BuildContext context)? onZeroBuilder;

  /// Default: `"Xh Ym"` if ≥ 1h, else `"Mm Ss"` (minutes and seconds).
  static String formatHoursMinutes(Duration d) {
    var r = d;
    if (r.isNegative) {
      r = Duration.zero;
    }
    if (r.inHours >= 1) {
      return '${r.inHours}h ${r.inMinutes.remainder(60)}m';
    }
    final totalSec = r.inSeconds;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  State<CountdownTicker> createState() => _CountdownTickerState();
}

class _CountdownTickerState extends State<CountdownTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.targetUtc.difference(ServerTimeService.now());
    if (remaining <= Duration.zero && widget.onZeroBuilder != null) {
      return widget.onZeroBuilder!(context);
    }
    final text = widget.format(
      remaining <= Duration.zero ? Duration.zero : remaining,
    );
    return Text(
      text,
      style: widget.style,
    );
  }
}
