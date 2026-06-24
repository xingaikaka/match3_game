import 'dart:math';

/// 棋盘大小及元素种类
class BoardConfig {
  static const int rows = 8;
  static const int cols = 8;
  static const int numTypes = 6; // 水果种类数
  static const int targetScore = 2000; // 过关目标分
  static const int maxMoves = 25; // 可用步数
}

/// 单个格子的状态
class Cell {
  int type; // 0-5 = 水果类型, -1 = 空格
  bool isSelected;
  bool isMatched;
  bool isNew; // 新生成的格子（用于入场动画）

  Cell({
    required this.type,
    this.isSelected = false,
    this.isMatched = false,
    this.isNew = false,
  });

  Cell copy() => Cell(
        type: type,
        isSelected: isSelected,
        isMatched: isMatched,
        isNew: isNew,
      );
}

/// 水果图片路径
const List<String> fruitImages = [
  'assets/images/apple.png',
  'assets/images/orange.png',
  'assets/images/grape.png',
  'assets/images/banana.png',
  'assets/images/strawberry.png',
  'assets/images/watermelon.png',
];

/// 水果名称（调试/显示用）
const List<String> fruitNames = [
  '苹果', '橙子', '葡萄', '香蕉', '草莓', '西瓜',
];

class GameBoard {
  final int rows = BoardConfig.rows;
  final int cols = BoardConfig.cols;

  late List<List<Cell>> grid;
  int score = 0;
  int movesLeft = BoardConfig.maxMoves;
  int highScore = 0;

  final _rng = Random();

  GameBoard() {
    _initBoard();
  }

  /// 重置棋盘
  void reset() {
    score = 0;
    movesLeft = BoardConfig.maxMoves;
    _initBoard();
  }

  // ─── 初始化 ───────────────────────────────────────────────

  void _initBoard() {
    // 先用占位格子初始化，使 grid 变量可被 _randomTypeNoMatch 访问
    grid = List.generate(rows, (_) => List.generate(cols, (_) => Cell(type: 0)));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        grid[r][c] = Cell(type: _randomTypeNoMatch(r, c));
      }
    }
  }

  /// 生成不会立即产生消除的随机类型
  int _randomTypeNoMatch(int r, int c) {
    // 已经放置的行/列
    final excluded = <int>{};
    if (c >= 2 &&
        grid[r][c - 1].type == grid[r][c - 2].type &&
        grid[r][c - 1].type != -1) {
      excluded.add(grid[r][c - 1].type);
    }
    if (r >= 2 &&
        grid[r - 1][c].type == grid[r - 2][c].type &&
        grid[r - 1][c].type != -1) {
      excluded.add(grid[r - 1][c].type);
    }
    int t;
    do {
      t = _rng.nextInt(BoardConfig.numTypes);
    } while (excluded.contains(t));
    return t;
  }

  // ─── 匹配检测 ──────────────────────────────────────────────

  /// 返回所有匹配格子的 (row, col) 集合
  Set<(int, int)> findMatches() {
    final matched = <(int, int)>{};

    // 横向（≥3 连续相同）
    for (int r = 0; r < rows; r++) {
      int c = 0;
      while (c < cols) {
        final t = grid[r][c].type;
        if (t == -1) { c++; continue; }
        int end = c;
        while (end + 1 < cols && grid[r][end + 1].type == t) { end++; }
        if (end - c >= 2) {
          for (int k = c; k <= end; k++) {
            matched.add((r, k));
          }
        }
        c = end + 1;
      }
    }

    // 纵向（≥3 连续相同）
    for (int c = 0; c < cols; c++) {
      int r = 0;
      while (r < rows) {
        final t = grid[r][c].type;
        if (t == -1) { r++; continue; }
        int end = r;
        while (end + 1 < rows && grid[end + 1][c].type == t) { end++; }
        if (end - r >= 2) {
          for (int k = r; k <= end; k++) {
            matched.add((k, c));
          }
        }
        r = end + 1;
      }
    }

    return matched;
  }

  /// 标记匹配格子
  void markMatches(Set<(int, int)> matched) {
    for (final (r, c) in matched) {
      grid[r][c].isMatched = true;
    }
  }

  /// 清除匹配格子，返回本轮得分
  int clearMatches(Set<(int, int)> matched, {int cascadeLevel = 1}) {
    int pts = 0;
    for (final (r, c) in matched) {
      grid[r][c].type = -1;
      grid[r][c].isMatched = false;
      pts += 10;
    }
    // 连击加成
    pts = (pts * cascadeLevel).clamp(0, 99999);
    score += pts;
    if (score > highScore) highScore = score;
    return pts;
  }

  // ─── 重力 & 填充 ───────────────────────────────────────────

  /// 将格子向下沉降（重力）
  void applyGravity() {
    for (int c = 0; c < cols; c++) {
      int writeRow = rows - 1;
      for (int r = rows - 1; r >= 0; r--) {
        if (grid[r][c].type != -1) {
          if (writeRow != r) {
            grid[writeRow][c] = grid[r][c].copy();
            grid[r][c] = Cell(type: -1);
          }
          writeRow--;
        }
      }
    }
  }

  /// 从顶部填充空格
  void fillEmpty() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c].type == -1) {
          grid[r][c] = Cell(type: _rng.nextInt(BoardConfig.numTypes), isNew: true);
        }
      }
    }
  }

  /// 清除所有 isNew 标记
  void clearNewFlags() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        grid[r][c].isNew = false;
      }
    }
  }

  // ─── 交换 ─────────────────────────────────────────────────

  /// 尝试交换两个相邻格子，返回是否有效（产生匹配）
  bool trySwap(int r1, int c1, int r2, int c2) {
    if (!_isAdjacent(r1, c1, r2, c2)) return false;

    _swap(r1, c1, r2, c2);

    if (findMatches().isEmpty) {
      _swap(r1, c1, r2, c2); // 还原
      return false;
    }

    movesLeft--;
    return true;
  }

  void _swap(int r1, int c1, int r2, int c2) {
    final tmp = grid[r1][c1].copy();
    grid[r1][c1] = grid[r2][c2].copy();
    grid[r2][c2] = tmp;
    // 保持选中/匹配状态干净
    grid[r1][c1].isSelected = false;
    grid[r2][c2].isSelected = false;
  }

  bool _isAdjacent(int r1, int c1, int r2, int c2) =>
      (r1 - r2).abs() + (c1 - c2).abs() == 1;

  // ─── 状态查询 ──────────────────────────────────────────────

  bool get isGameOver => movesLeft <= 0 && score < BoardConfig.targetScore;
  bool get isWin => score >= BoardConfig.targetScore;

  /// 当前局面是否还有有效交换（提示用）
  bool hasValidMoves() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // 试右
        if (c + 1 < cols) {
          _swap(r, c, r, c + 1);
          final m = findMatches().isNotEmpty;
          _swap(r, c, r, c + 1);
          if (m) return true;
        }
        // 试下
        if (r + 1 < rows) {
          _swap(r, c, r + 1, c);
          final m = findMatches().isNotEmpty;
          _swap(r, c, r + 1, c);
          if (m) return true;
        }
      }
    }
    return false;
  }
}
