import 'package:flutter/material.dart';
import '../models/game_board.dart';
import '../theme/game_theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameBoard board;
  int? selRow, selCol;
  bool isProcessing = false;

  // 当前正在消除的格子（显示消除动画）
  Set<(int, int)> matchedCells = {};

  // 上次得分弹出
  int? lastPoints;

  // 连击数
  int _cascade = 0;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    board = GameBoard();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── 游戏循环 ──────────────────────────────────────────────

  Future<void> _processBoard() async {
    isProcessing = true;
    _cascade = 0;

    while (true) {
      final matches = board.findMatches();
      if (matches.isEmpty) break;

      _cascade++;

      // 1. 标记消除动画
      setState(() => matchedCells = Set.from(matches));
      await Future.delayed(const Duration(milliseconds: 320));

      // 2. 清除格子
      final pts = board.clearMatches(matches, cascadeLevel: _cascade);
      setState(() {
        matchedCells = {};
        lastPoints = pts;
      });
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. 重力
      board.applyGravity();
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));

      // 4. 填充新格子
      board.fillEmpty();
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));
    }

    board.clearNewFlags();
    isProcessing = false;
    setState(() {});

    // 无有效步数 → 打乱
    if (!board.hasValidMoves()) {
      await Future.delayed(const Duration(milliseconds: 500));
      _shuffleBoard();
    }

    // 判断胜负
    if (board.isWin) {
      await Future.delayed(const Duration(milliseconds: 400));
      _showResultDialog(win: true);
    } else if (board.isGameOver) {
      await Future.delayed(const Duration(milliseconds: 400));
      _showResultDialog(win: false);
    }
  }

  void _shuffleBoard() {
    board.reset();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('没有可消除的组合，棋盘已重新洗牌 🔀'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF6A1B9A),
      ),
    );
  }

  // ── 点击处理 ─────────────────────────────────────────────

  void _onCellTap(int r, int c) {
    if (isProcessing) return;
    if (board.grid[r][c].type == -1) return;

    // 第一次点击：选中
    if (selRow == null) {
      setState(() {
        selRow = r;
        selCol = c;
        board.grid[r][c].isSelected = true;
      });
      return;
    }

    // 再次点击同一格：取消选中
    if (selRow == r && selCol == c) {
      setState(() {
        board.grid[r][c].isSelected = false;
        selRow = null;
        selCol = null;
      });
      return;
    }

    final pr = selRow!;
    final pc = selCol!;

    // 取消之前选中状态
    board.grid[pr][pc].isSelected = false;
    selRow = null;
    selCol = null;

    // 尝试交换
    final ok = board.trySwap(pr, pc, r, c);
    if (ok) {
      setState(() {});
      _processBoard();
    } else {
      // 不相邻或无消除 → 抖动提示
      setState(() {});
      _shakeCtrl.forward(from: 0);
    }
  }

  // ── 对话框 ───────────────────────────────────────────────

  void _showResultDialog({required bool win}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        win: win,
        score: board.score,
        highScore: board.highScore,
        onRestart: () {
          Navigator.pop(context);
          setState(() {
            board.reset();
            selRow = null;
            selCol = null;
            matchedCells = {};
            lastPoints = null;
          });
        },
        onHome: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── 构建 UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boardSize = size.width - 16;
    final cellSize = boardSize / 8;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: GameTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressBar(),
              const SizedBox(height: 8),
              // 棋盘
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(_shakeAnim.value, 0),
                      child: child,
                    ),
                    child: _buildBoard(boardSize, cellSize),
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 返回
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
          const Spacer(),
          // 分数
          _ScoreBox(
            label: '得分',
            value: board.score.toString(),
            accent: GameTheme.accentGold,
          ),
          const SizedBox(width: 10),
          // 目标
          _ScoreBox(
            label: '目标',
            value: BoardConfig.targetScore.toString(),
            accent: GameTheme.accentGreen,
          ),
          const Spacer(),
          // 步数
          _ScoreBox(
            label: '步数',
            value: board.movesLeft.toString(),
            accent: board.movesLeft <= 5
                ? GameTheme.accentRed
                : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress =
        (board.score / BoardConfig.targetScore).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          backgroundColor: GameTheme.barBg,
          valueColor: AlwaysStoppedAnimation(
            progress >= 1.0 ? GameTheme.accentGreen : GameTheme.accentGold,
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(double boardSize, double cellSize) {
    return Container(
      width: boardSize,
      height: boardSize,
      decoration: GameTheme.boardDecoration,
      padding: const EdgeInsets.all(4),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: 64,
        itemBuilder: (_, idx) {
          final r = idx ~/ 8;
          final c = idx % 8;
          return _buildCell(r, c, cellSize);
        },
      ),
    );
  }

  Widget _buildCell(int r, int c, double size) {
    final cell = board.grid[r][c];
    final isSelected = selRow == r && selCol == c;
    final isMatched = matchedCells.contains((r, c));

    Widget content;
    if (cell.type == -1) {
      content = const SizedBox.expand();
    } else {
      content = Padding(
        padding: const EdgeInsets.all(3),
        child: Image.asset(
          fruitImages[cell.type],
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      child: AnimatedOpacity(
        opacity: isMatched ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 280),
        child: AnimatedScale(
          scale: isMatched ? 1.4 : (isSelected ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? GameTheme.cellSelected
                  : Colors.white.withValues(alpha: cell.isNew ? 0.0 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: GameTheme.accentGold, width: 2)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: GameTheme.accentGold.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final pts = lastPoints;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (pts != null && pts > 0)
            TweenAnimationBuilder<double>(
              key: ValueKey(pts),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(
                opacity: v < 0.7 ? 1.0 : (1.0 - (v - 0.7) / 0.3).clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, -20 * v),
                  child: child,
                ),
              ),
              child: Text(
                '+$pts',
                style: TextStyle(
                  color: _cascade > 1
                      ? GameTheme.accentGreen
                      : GameTheme.accentGold,
                  fontSize: _cascade > 1 ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                ),
              ),
            )
          else
            Text(
              _cascade > 1 ? '$_cascade 连击！' : '选中一个水果，再选相邻水果进行交换',
              style: TextStyle(
                color: _cascade > 1
                    ? GameTheme.accentGreen
                    : GameTheme.textMuted,
                fontSize: 13,
                fontWeight: _cascade > 1 ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}

// ── 分数方块 ─────────────────────────────────────────────────

class _ScoreBox extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _ScoreBox({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: GameTheme.textMuted, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ── 结果对话框 ───────────────────────────────────────────────

class _ResultDialog extends StatelessWidget {
  final bool win;
  final int score;
  final int highScore;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  const _ResultDialog({
    required this.win,
    required this.score,
    required this.highScore,
    required this.onRestart,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: win
                ? [const Color(0xFF1A5E3B), const Color(0xFF2E7D52)]
                : [const Color(0xFF4A1528), const Color(0xFF7B2044)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (win ? GameTheme.accentGreen : GameTheme.accentRed)
                .withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(win ? '🎉' : '😢',
                style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            Text(
              win ? '恭喜通关！' : '游戏结束',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _Row(label: '本局得分', value: score.toString()),
            const SizedBox(height: 6),
            _Row(label: '最高分', value: highScore.toString()),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onHome,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('返回'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onRestart,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          win ? GameTheme.accentGreen : GameTheme.accentGold,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('再来一局',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: GameTheme.textMuted, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
