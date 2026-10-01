import 'package:flutter/material.dart';

/// A sleek, self-contained POS-style calculator. No external packages
/// or expression parsing: it follows the classic calculator state
/// machine (current display value, a pending operator, and the first
/// operand), which keeps it simple, predictable and impossible to break
/// with malformed expressions.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String? _expressionPreview; // small line above the display, e.g. "12 +"
  double? _firstOperand;
  String? _pendingOperation; // '+', '-', '×', '÷'
  bool _shouldResetDisplay = false;
  bool _hasError = false;

  static const _primary = Color(0xFF1565C0);

  void _inputDigit(String digit) {
    setState(() {
      if (_hasError || _shouldResetDisplay) {
        _display = digit;
        _shouldResetDisplay = false;
        _hasError = false;
      } else if (_display == '0') {
        _display = digit;
      } else {
        _display = _display + digit;
      }
    });
  }

  void _inputDecimal() {
    setState(() {
      if (_hasError || _shouldResetDisplay) {
        _display = '0.';
        _shouldResetDisplay = false;
        _hasError = false;
        return;
      }
      if (!_display.contains('.')) {
        _display = '$_display.';
      }
    });
  }

  void _toggleSign() {
    setState(() {
      if (_hasError) return;
      if (_display == '0') return;
      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else {
        _display = '-$_display';
      }
    });
  }

  void _inputPercent() {
    setState(() {
      if (_hasError) return;
      final value = double.tryParse(_display);
      if (value == null) return;
      _display = _formatNumber(value / 100);
    });
  }

  void _backspace() {
    setState(() {
      if (_hasError || _shouldResetDisplay) {
        _clearAll();
        return;
      }
      if (_display.length <= 1 || (_display.length == 2 && _display.startsWith('-'))) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _display = '0';
      _expressionPreview = null;
      _firstOperand = null;
      _pendingOperation = null;
      _shouldResetDisplay = false;
      _hasError = false;
    });
  }

  void _chooseOperation(String op) {
    setState(() {
      if (_hasError) return;

      if (_pendingOperation != null && !_shouldResetDisplay) {
        _calculate();
        if (_hasError) return;
      } else {
        _firstOperand = double.tryParse(_display);
      }

      _pendingOperation = op;
      _expressionPreview = '${_formatNumber(_firstOperand ?? 0)} $op';
      _shouldResetDisplay = true;
    });
  }

  void _calculate() {
    if (_pendingOperation == null || _firstOperand == null) return;

    final second = double.tryParse(_display);
    if (second == null) {
      _hasError = true;
      _display = 'خطأ';
      return;
    }

    double result;
    switch (_pendingOperation) {
      case '+':
        result = _firstOperand! + second;
        break;
      case '-':
        result = _firstOperand! - second;
        break;
      case '×':
        result = _firstOperand! * second;
        break;
      case '÷':
        if (second == 0) {
          _hasError = true;
          _display = 'خطأ';
          _expressionPreview = null;
          _pendingOperation = null;
          _firstOperand = null;
          _shouldResetDisplay = true;
          return;
        }
        result = _firstOperand! / second;
        break;
      default:
        return;
    }

    if (result.isNaN || result.isInfinite) {
      _hasError = true;
      _display = 'خطأ';
      _expressionPreview = null;
      _pendingOperation = null;
      _firstOperand = null;
      _shouldResetDisplay = true;
      return;
    }

    _display = _formatNumber(result);
    _firstOperand = result;
  }

  void _pressEquals() {
    setState(() {
      if (_pendingOperation == null || _hasError) return;
      _expressionPreview =
          '${_formatNumber(_firstOperand ?? 0)} $_pendingOperation ${_display} =';
      _calculate();
      _pendingOperation = null;
      _shouldResetDisplay = true;
    });
  }

  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) return 'خطأ';
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    String s = value.toStringAsFixed(8);
    // Trim trailing zeros, then a trailing dot if left bare.
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.calculate_outlined),
            SizedBox(width: 10),
            Text('حاسبة', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Compact FIKRA logo, neatly embedded at the top of
                  // the calculator card.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      height: 40,
                      child: Image.asset(
                        'assets/images/fikra_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // ---------- Display ----------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 18,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _expressionPreview ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _display,
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: _hasError ? Colors.red.shade700 : const Color(0xFF0D47A1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------- Buttons ----------
                  _CalcRow(
                    buttons: [
                      _CalcButtonSpec.action('C', onTap: _clearAll, color: Colors.red.shade50, textColor: Colors.red.shade700),
                      _CalcButtonSpec.action('±', onTap: _toggleSign, color: Colors.grey.shade100, textColor: Colors.black87),
                      _CalcButtonSpec.action('%', onTap: _inputPercent, color: Colors.grey.shade100, textColor: Colors.black87),
                      _CalcButtonSpec.operator('÷', onTap: () => _chooseOperation('÷')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CalcRow(
                    buttons: [
                      _CalcButtonSpec.digit('7', onTap: () => _inputDigit('7')),
                      _CalcButtonSpec.digit('8', onTap: () => _inputDigit('8')),
                      _CalcButtonSpec.digit('9', onTap: () => _inputDigit('9')),
                      _CalcButtonSpec.operator('×', onTap: () => _chooseOperation('×')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CalcRow(
                    buttons: [
                      _CalcButtonSpec.digit('4', onTap: () => _inputDigit('4')),
                      _CalcButtonSpec.digit('5', onTap: () => _inputDigit('5')),
                      _CalcButtonSpec.digit('6', onTap: () => _inputDigit('6')),
                      _CalcButtonSpec.operator('-', onTap: () => _chooseOperation('-')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CalcRow(
                    buttons: [
                      _CalcButtonSpec.digit('1', onTap: () => _inputDigit('1')),
                      _CalcButtonSpec.digit('2', onTap: () => _inputDigit('2')),
                      _CalcButtonSpec.digit('3', onTap: () => _inputDigit('3')),
                      _CalcButtonSpec.operator('+', onTap: () => _chooseOperation('+')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CalcRow(
                    buttons: [
                      _CalcButtonSpec.action(
                        '⌫',
                        onTap: _backspace,
                        color: Colors.grey.shade100,
                        textColor: Colors.black87,
                      ),
                      _CalcButtonSpec.digit('0', onTap: () => _inputDigit('0')),
                      _CalcButtonSpec.action('.', onTap: _inputDecimal, color: Colors.grey.shade100, textColor: Colors.black87),
                      _CalcButtonSpec.action(
                        '=',
                        onTap: _pressEquals,
                        color: Colors.green,
                        textColor: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Describes one calculator button: its label, tap handler, and colors.
class _CalcButtonSpec {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;

  const _CalcButtonSpec({
    required this.label,
    required this.onTap,
    required this.color,
    required this.textColor,
  });

  factory _CalcButtonSpec.digit(String label, {required VoidCallback onTap}) {
    return _CalcButtonSpec(
      label: label,
      onTap: onTap,
      color: Colors.white,
      textColor: Colors.black87,
    );
  }

  factory _CalcButtonSpec.operator(String label, {required VoidCallback onTap}) {
    return _CalcButtonSpec(
      label: label,
      onTap: onTap,
      color: const Color(0xFF1565C0),
      textColor: Colors.white,
    );
  }

  factory _CalcButtonSpec.action(
    String label, {
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
  }) {
    return _CalcButtonSpec(label: label, onTap: onTap, color: color, textColor: textColor);
  }
}

/// A single row of evenly-sized, evenly-spaced calculator buttons.
class _CalcRow extends StatelessWidget {
  final List<_CalcButtonSpec> buttons;

  const _CalcRow({required this.buttons});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: buttons
          .map(
            (spec) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _CalcButton(spec: spec),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CalcButton extends StatelessWidget {
  final _CalcButtonSpec spec;

  const _CalcButton({required this.spec});

  @override
  Widget build(BuildContext context) {
    final bool isNeutral = spec.color == Colors.white || spec.color == Colors.grey.shade100;

    return Material(
      color: spec.color,
      borderRadius: BorderRadius.circular(14),
      elevation: isNeutral ? 0 : 1,
      child: InkWell(
        onTap: spec.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isNeutral ? Border.all(color: Colors.grey.shade200) : null,
          ),
          child: Text(
            spec.label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: spec.textColor,
            ),
          ),
        ),
      ),
    );
  }
}