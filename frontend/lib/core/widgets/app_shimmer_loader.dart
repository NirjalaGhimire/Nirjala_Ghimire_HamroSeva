import 'package:flutter/material.dart';

/// App-wide shimmer loader used as a replacement for spinner indicators.
///
/// This widget intentionally mirrors commonly used progress-indicator
/// constructor arguments so existing call-sites can be swapped safely.
class AppShimmerLoader extends StatefulWidget {
  const AppShimmerLoader({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.strokeWidth = 4.0,
    this.semanticsLabel,
    this.semanticsValue,
    this.strokeCap,
    this.trackGap,
    this.padding,
    this.constraints,
    this.year2023,
  });

  final double? value;
  final Color? backgroundColor;
  final Color? color;
  final Animation<Color>? valueColor;
  final double strokeWidth;
  final String? semanticsLabel;
  final String? semanticsValue;
  final StrokeCap? strokeCap;
  final double? trackGap;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final bool? year2023;

  @override
  State<AppShimmerLoader> createState() => _AppShimmerLoaderState();
}

class _AppShimmerLoaderState extends State<AppShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wrapped = Semantics(
      label: widget.semanticsLabel,
      value: widget.semanticsValue,
      child: Padding(
        padding: widget.padding ?? EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: widget.constraints ??
              const BoxConstraints.tightFor(width: 26, height: 12),
          child: _ShimmerBlock(
            animation: _controller,
            baseColor: widget.backgroundColor,
            highlightColor: widget.color ?? widget.valueColor?.value,
            borderRadius: 999,
          ),
        ),
      ),
    );

    return wrapped;
  }
}

class AppPageShimmer extends StatefulWidget {
  const AppPageShimmer({
    super.key,
    this.itemCount = 3,
    this.showHeader = true,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final bool showHeader;
  final EdgeInsetsGeometry padding;

  @override
  State<AppPageShimmer> createState() => _AppPageShimmerState();
}

class _AppPageShimmerState extends State<AppPageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surface;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return ListView(
            padding: widget.padding,
            children: [
              if (widget.showHeader)
                _ShimmerHeaderComposite(
                  animation: _controller,
                  compact: compact,
                  surface: surface,
                ),
              if (widget.showHeader) const SizedBox(height: 24),
              ...List.generate(
                widget.itemCount,
                (index) => Padding(
                  padding: EdgeInsets.only(
                      bottom: index == widget.itemCount - 1 ? 0 : 16),
                  child: _ShimmerContentComposite(
                    animation: _controller,
                    compact: compact,
                    surface: surface,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShimmerHeaderComposite extends StatelessWidget {
  const _ShimmerHeaderComposite({
    required this.animation,
    required this.compact,
    required this.surface,
  });

  final Animation<double> animation;
  final bool compact;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final card = BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(14),
    );
    final miniCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(
                animation: animation,
                height: 54,
                width: 54,
                borderRadius: 999,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(
                      animation: animation,
                      height: 12,
                      borderRadius: 999,
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.58,
                      child: _ShimmerBox(
                        animation: animation,
                        height: 10,
                        borderRadius: 999,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ShimmerBox(animation: animation, height: 10, borderRadius: 999),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.82,
            child: _ShimmerBox(
                animation: animation, height: 10, borderRadius: 999),
          ),
        ],
      ),
    );

    final tiles = compact
        ? Column(
            children: [
              miniCard,
              const SizedBox(height: 12),
              miniCard,
              const SizedBox(height: 12),
              miniCard,
            ],
          )
        : Row(
            children: [
              Expanded(child: miniCard),
              const SizedBox(width: 12),
              Expanded(child: miniCard),
              const SizedBox(width: 12),
              Expanded(child: miniCard),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tiles,
        const SizedBox(height: 16),
        _ShimmerBox(animation: animation, height: 12, borderRadius: 999),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.65,
          child:
              _ShimmerBox(animation: animation, height: 12, borderRadius: 999),
        ),
      ],
    );
  }
}

class _ShimmerContentComposite extends StatelessWidget {
  const _ShimmerContentComposite({
    required this.animation,
    required this.compact,
    required this.surface,
  });

  final Animation<double> animation;
  final bool compact;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 108,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(animation: animation, height: 9, borderRadius: 999),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.8,
            child:
                _ShimmerBox(animation: animation, height: 9, borderRadius: 999),
          ),
          const Spacer(),
          _ShimmerBox(animation: animation, height: 48, borderRadius: 8),
        ],
      ),
    );

    final cards = compact
        ? Column(
            children: [
              card,
              const SizedBox(height: 10),
              card,
            ],
          )
        : Row(
            children: [
              Expanded(child: card),
              const SizedBox(width: 10),
              Expanded(child: card),
            ],
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(
                animation: animation,
                height: 36,
                width: 36,
                borderRadius: 999,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(
                        animation: animation, height: 10, borderRadius: 999),
                    const SizedBox(height: 7),
                    FractionallySizedBox(
                      widthFactor: 0.45,
                      child: _ShimmerBox(
                          animation: animation, height: 9, borderRadius: 999),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          cards,
          const SizedBox(height: 10),
          _ShimmerBox(animation: animation, height: 10, borderRadius: 999),
          const SizedBox(height: 7),
          FractionallySizedBox(
            widthFactor: 0.72,
            child: _ShimmerBox(
                animation: animation, height: 10, borderRadius: 999),
          ),
        ],
      ),
    );
  }
}

class AiMessageShimmer extends StatefulWidget {
  const AiMessageShimmer({super.key});

  @override
  State<AiMessageShimmer> createState() => _AiMessageShimmerState();
}

class _AiMessageShimmerState extends State<AiMessageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBox(animation: _controller, height: 12, borderRadius: 999),
            const SizedBox(height: 8),
            _ShimmerBox(animation: _controller, height: 12, borderRadius: 999),
            const SizedBox(height: 8),
            FractionallySizedBox(
              widthFactor: 0.62,
              child: _ShimmerBox(
                  animation: _controller, height: 12, borderRadius: 999),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.animation,
    required this.height,
    this.width,
    this.borderRadius = 8,
  });

  final Animation<double> animation;
  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: _ShimmerBlock(
        animation: animation,
        borderRadius: borderRadius,
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.animation,
    this.baseColor,
    this.highlightColor,
    this.borderRadius = 8,
  });

  final Animation<double> animation;
  final Color? baseColor;
  final Color? highlightColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base =
        baseColor ?? colorScheme.surfaceContainerHighest.withOpacity(0.7);
    final highlight = highlightColor ?? Colors.white.withOpacity(0.85);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment(-1.6 + (animation.value * 2.8), -0.2),
                end: Alignment(-0.6 + (animation.value * 2.8), 0.2),
                colors: [
                  base,
                  highlight,
                  base,
                ],
                stops: const [0.1, 0.45, 0.9],
              ).createShader(rect);
            },
            blendMode: BlendMode.srcATop,
            child: Container(color: base),
          ),
        );
      },
    );
  }
}
