import 'package:flutter/material.dart';

class PatternLock extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(String) onPatternComplete;
  final bool isVerifyMode;
  final String? expectedPattern;

  const PatternLock({
    super.key,
    this.title = '绘制图案',
    this.subtitle = '请连接至少4个点',
    required this.onPatternComplete,
    this.isVerifyMode = false,
    this.expectedPattern,
  });

  @override
  State<PatternLock> createState() => _PatternLockState();
}

class _PatternLockState extends State<PatternLock> {
  final List<int> _selectedDots = [];
  Offset? _currentPoint;
  final int _gridSize = 3;
  final double _dotSize = 80.0;
  final double _dotSpacing = 40.0;

  List<Offset> _dotPositions = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateDotPositions();
  }

  void _calculateDotPositions() {
    _dotPositions = [];
    final totalSize = _gridSize * _dotSize + (_gridSize - 1) * _dotSpacing;
    final startX = (MediaQuery.of(context).size.width - totalSize) / 2;
    final startY = 160.0;

    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final x = startX + col * (_dotSize + _dotSpacing) + _dotSize / 2;
        final y = startY + row * (_dotSize + _dotSpacing) + _dotSize / 2;
        _dotPositions.add(Offset(x, y));
      }
    }
  }

  int? _getDotAtPosition(Offset pos) {
    for (int i = 0; i < _dotPositions.length; i++) {
      final center = _dotPositions[i];
      final distance = (pos - center).distance;
      if (distance < _dotSize / 2) {
        return i;
      }
    }
    return null;
  }

  void _onPanStart(DragStartDetails details) {
    _onPanUpdate(DragUpdateDetails(globalPosition: details.globalPosition));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pos = details.localPosition;
    final dotIndex = _getDotAtPosition(pos);
    if (dotIndex != null && !_selectedDots.contains(dotIndex)) {
      setState(() {
        _selectedDots.add(dotIndex);
        _currentPoint = pos;
      });
    } else {
      setState(() {
        _currentPoint = pos;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_selectedDots.length >= 4) {
      final pattern = _selectedDots.join('-');
      widget.onPatternComplete(pattern);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少连接4个点')),
      );
    }
    setState(() {
      _selectedDots.clear();
      _currentPoint = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a2a6c),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: CustomPaint(
          painter: _PatternPainter(
            dotPositions: _dotPositions,
            selectedDots: _selectedDots,
            currentPoint: _currentPoint,
            dotSize: _dotSize,
          ),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                widget.subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: _gridSize * _dotSize + (_gridSize - 1) * _dotSpacing + 200),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final List<Offset> dotPositions;
  final List<int> selectedDots;
  final Offset? currentPoint;
  final double dotSize;

  _PatternPainter({
    required this.dotPositions,
    required this.selectedDots,
    required this.currentPoint,
    required this.dotSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw dots
    for (int i = 0; i < dotPositions.length; i++) {
      final center = dotPositions[i];
      final isSelected = selectedDots.contains(i);

      final dotPaint = Paint()
        ..color = isSelected ? const Color(0xFF409eff) : Colors.white24
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, isSelected ? 16 : 12, dotPaint);

      if (isSelected) {
        final ringPaint = Paint()
          ..color = const Color(0xFF409eff).withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, dotSize / 2, ringPaint);
      }
    }

    // Draw lines
    if (selectedDots.length > 1) {
      final linePaint = Paint()
        ..color = const Color(0xFF409eff)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < selectedDots.length - 1; i++) {
        canvas.drawLine(
          dotPositions[selectedDots[i]],
          dotPositions[selectedDots[i + 1]],
          linePaint,
        );
      }
    }

    // Draw line to current point
    if (selectedDots.isNotEmpty && currentPoint != null) {
      final linePaint = Paint()
        ..color = const Color(0xFF409eff).withValues(alpha: 0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        dotPositions[selectedDots.last],
        currentPoint!,
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return true;
  }
}
