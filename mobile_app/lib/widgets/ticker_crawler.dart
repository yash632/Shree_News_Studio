import 'package:flutter/material.dart';

class TickerCrawler extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double speed; // pixels per second

  const TickerCrawler({
    super.key,
    required this.text,
    this.style,
    this.speed = 45.0,
  });

  @override
  State<TickerCrawler> createState() => _TickerCrawlerState();
}

class _TickerCrawlerState extends State<TickerCrawler> with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..addListener(_scroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final durationSecs = (maxScroll / widget.speed).clamp(5.0, 60.0);
    _animController.duration = Duration(milliseconds: (durationSecs * 1000).toInt());
    _animController.repeat();
  }

  void _scroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      _scrollController.jumpTo(_animController.value * maxScroll);
    }
  }

  @override
  void didUpdateWidget(TickerCrawler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startScrolling();
      });
    }
  }

  @override
  void dispose() {
    _animController.removeListener(_scroll);
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = widget.style ??
        const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Hind',
        );

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(widget.text, style: effectiveStyle),
            const SizedBox(width: 80),
            Text(widget.text, style: effectiveStyle),
          ],
        ),
      ),
    );
  }
}

