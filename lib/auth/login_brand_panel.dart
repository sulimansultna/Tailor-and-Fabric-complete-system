import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

const _navy = Color(0xff102a43);
const _teal = Color(0xff087f8c);
const _ivory = Color(0xfff7f5f0);
const _gold = Color(0xffc6a15b);

class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({
    super.key,
    required this.appName,
    required this.compact,
  });

  final String appName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [_navy, Color(0xff123a50), _teal],
        ),
        borderRadius: BorderRadius.circular(compact ? 24 : 32),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: .16),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 24 : 32),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -110,
              top: -140,
              child: _glow(320, Colors.white.withValues(alpha: .045)),
            ),
            PositionedDirectional(
              start: -100,
              bottom: -150,
              child: _glow(330, _gold.withValues(alpha: .09)),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 20 : 36),
              child: compact
                  ? _compactContent(context, strings)
                  : _fullContent(context, strings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fullContent(BuildContext context, AppLocalizations strings) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final imageSize = math.min(
            300.0,
            math.max(150.0, constraints.maxHeight * .42),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _brandHeader(context),
              const Spacer(),
              _enter(
                context,
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.loginBrandHeading,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 370),
                      child: Text(
                        strings.loginBrandMessage,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: .78),
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: AnimatedTailorIllustration(
                  size: imageSize,
                  semanticsLabel: strings.loginArtworkDescription,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 17, color: _gold),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      strings.loginOfflineNote,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: .82),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );

  Widget _compactContent(BuildContext context, AppLocalizations strings) => Row(
    children: [
      _logo(size: 52),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              strings.loginBrandHeading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.white.withValues(alpha: .82)),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      const Icon(Icons.wifi_off_rounded, size: 19, color: _gold),
    ],
  );

  Widget _brandHeader(BuildContext context) => Row(
    children: [
      _logo(size: 50),
      const SizedBox(width: 13),
      Expanded(
        child: Text(
          appName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );

  Widget _logo({required double size}) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .18)),
    ),
    child: Image.asset(
      'assets/images/tailoricon.png',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.content_cut_rounded, color: Colors.white, size: 30),
    ),
  );

  Widget _enter(BuildContext context, Widget Function() child) {
    final noMotion = MediaQuery.disableAnimationsOf(context);
    final travel = Directionality.of(context) == TextDirection.rtl
        ? 12.0
        : -12.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: noMotion ? 1 : 0, end: 1),
      duration: Duration(milliseconds: noMotion ? 0 : 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(travel * (1 - value), 0),
          child: child,
        ),
      ),
      child: child(),
    );
  }

  Widget _glow(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

class AnimatedTailorIllustration extends StatefulWidget {
  const AnimatedTailorIllustration({
    super.key,
    required this.size,
    required this.semanticsLabel,
  });

  final double size;
  final String semanticsLabel;

  @override
  State<AnimatedTailorIllustration> createState() =>
      _AnimatedTailorIllustrationState();
}

class _AnimatedTailorIllustrationState extends State<AnimatedTailorIllustration>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _reducedMotion = false;
  bool _active = true;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _syncAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (!mounted) return;
    if (_active && !_reducedMotion) {
      if (!_float.isAnimating) _float.repeat(reverse: true);
    } else {
      _float.stop();
    }
  }

  void _hover(PointerEvent event) {
    if (_reducedMotion) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return;
    final dx = (event.localPosition.dx / box.size.width - .5) * 2;
    final dy = (event.localPosition.dy / box.size.height - .5) * 2;
    setState(() {
      _tiltY = dx.clamp(-1, 1) * .035;
      _tiltX = -dy.clamp(-1, 1) * .025;
    });
  }

  void _resetTilt() => setState(() {
    _tiltX = 0;
    _tiltY = 0;
  });

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: _hover,
    onExit: (_) => _resetTilt(),
    child: AnimatedBuilder(
      animation: _float,
      child: Semantics(
        image: true,
        label: widget.semanticsLabel,
        child: Image.asset(
          'assets/images/tailoricon.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Icon(
            Icons.content_cut_rounded,
            size: widget.size * .62,
            color: _ivory,
          ),
        ),
      ),
      builder: (context, child) {
        final floatY = _reducedMotion
            ? 0.0
            : math.sin(_float.value * math.pi) * 5;
        final perspective = Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateX(_reducedMotion ? 0 : _tiltX)
          ..rotateY(_reducedMotion ? 0 : _tiltY);
        return Transform.translate(
          offset: Offset(0, floatY),
          child: AnimatedContainer(
            duration: Duration(milliseconds: _reducedMotion ? 0 : 180),
            curve: Curves.easeOut,
            transform: perspective,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.size * .22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .22),
                    blurRadius: 30,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: _teal.withValues(alpha: .22),
                    blurRadius: 40,
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    ),
  );
}
