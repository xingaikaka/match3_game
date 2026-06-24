import 'package:flutter/material.dart';
import '../theme/game_theme.dart';
import '../models/game_board.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: GameTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 标题
              Column(
                children: [
                  Image.asset('assets/images/strawberry.png', width: 64, height: 64),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF6EC7)],
                    ).createShader(bounds),
                    child: const Text(
                      '消消乐',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '水果大消除',
                    style: TextStyle(
                      color: GameTheme.textMuted,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // 水果预览
              _FruitPreview(),

              const Spacer(),

              // 规则说明
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    _RuleRow(icon: Icons.swap_horiz_rounded, text: '交换相邻水果，消除 3 个及以上相同水果'),
                    const SizedBox(height: 8),
                    _RuleRow(icon: Icons.stars_rounded, text: '目标：${BoardConfig.targetScore} 分通关'),
                    const SizedBox(height: 8),
                    _RuleRow(icon: Icons.bolt_rounded, text: '共 ${BoardConfig.maxMoves} 步，连消得连击加分'),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // 开始按钮
              ScaleTransition(
                scale: _pulseAnim,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (ctx, anim1, anim2) => const GameScreen(),
                      transitionsBuilder: (ctx, anim, secAnim, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                  ),
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6EC7), Color(0xFFFFD700)],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6EC7).withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '开始游戏',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _FruitPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(fruitImages.length, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + i * 100),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Image.asset(fruitImages[i], width: 44, height: 44),
          ),
        );
      }),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _RuleRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: GameTheme.accentGold, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                color: GameTheme.textMuted, fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}
