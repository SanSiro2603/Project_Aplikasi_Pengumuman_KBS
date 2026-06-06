import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _exitController;
  late final Animation<double> _backgroundOpacity;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _exitOpacity;
  late final Animation<Offset> _exitSlide;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _backgroundOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0, 0.36, curve: Curves.easeOut),
    );
    _logoOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0, 0.36, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.32, 0.73, curve: Curves.easeOutBack),
      ),
    );
    _contentOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.59, 1, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(begin: const Offset(0, 18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.59, 1, curve: Curves.easeOutCubic),
          ),
        );
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );
    _exitSlide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -20))
        .animate(
          CurvedAnimation(
            parent: _exitController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _runSplash();
  }

  Future<void> _runSplash() async {
    await _introController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await _exitController.forward();
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _introController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final logoSize = size.shortestSide.clamp(118.0, 156.0);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF7EF),
      body: AnimatedBuilder(
        animation: Listenable.merge([_introController, _exitController]),
        builder: (context, child) {
          return Opacity(
            opacity: _exitOpacity.value,
            child: Transform.translate(offset: _exitSlide.value, child: child),
          );
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _backgroundOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: _backgroundOpacity.value,
                    child: child,
                  );
                },
                child: const _SplashBackdrop(),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _introController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: child,
                            ),
                          );
                        },
                        child: _LogoMark(size: logoSize),
                      ),
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _introController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _contentOpacity.value,
                            child: Transform.translate(
                              offset: _contentSlide.value,
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              'Pengumuman KBS',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF0F4F2C),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Informasi resmi Kampung Baru Sukaraja',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF3E6B50),
                                height: 1.45,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const _LoadingPill(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SplashBackdropPainter(),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF7EF), Color(0xFFD6F0DE), Color(0xFFBEE5CA)],
          ),
        ),
      ),
    );
  }
}

class _SplashBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.34);
    final upperPath = Path()
      ..moveTo(0, size.height * 0.18)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.09,
        size.width * 0.54,
        size.height * 0.28,
        size.width,
        size.height * 0.12,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(upperPath, paint);

    paint.color = const Color(0xFF6EC48D).withValues(alpha: 0.18);
    final lowerPath = Path()
      ..moveTo(0, size.height * 0.76)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.68,
        size.width * 0.54,
        size.height * 0.88,
        size.width,
        size.height * 0.73,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(lowerPath, paint);

    paint
      ..color = const Color(0xFF1B7A45).withValues(alpha: 0.11)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width * 0.5, size.height * 0.33);
    for (var radius = 32.0; radius <= 62.0; radius += 15) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        4.04,
        1.22,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F4F2C).withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.asset(
          'assets/icon/app_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(
              color: Color(0xFF2E7D32),
              child: Center(
                child: Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 58,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: const LinearProgressIndicator(
        backgroundColor: Colors.transparent,
        color: Color(0xFF2E7D32),
        minHeight: 5,
      ),
    );
  }
}
