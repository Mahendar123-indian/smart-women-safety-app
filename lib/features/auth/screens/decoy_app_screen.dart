// lib/features/auth/screens/decoy_app_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// DECOY APP SCREEN — Fully functional fake calculator
// Shown when decoy PIN is entered
// Looks completely real — hides SafeHer from snooping eyes
// Secret: enter real PIN in calculator → navigates to SafeHer
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/decoy_service.dart';
import '../../../core/theme/app_colors.dart';

class DecoyAppScreen extends StatefulWidget {
  const DecoyAppScreen({super.key});
  @override
  State<DecoyAppScreen> createState() => _DecoyAppScreenState();
}

class _DecoyAppScreenState extends State<DecoyAppScreen>
    with SingleTickerProviderStateMixin {
  String _display    = '0';
  String _expression = '';
  double _result     = 0;
  bool   _newNum     = true;
  String _operator   = '';
  double _prevNum    = 0;
  String _secretPin  = '';

  late AnimationController _btnCtrl;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    // Force status bar to look like real phone
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:            Colors.transparent,
      statusBarIconBrightness:   Brightness.dark,
    ));
  }

  @override
  void dispose() { _btnCtrl.dispose(); super.dispose(); }

  // ─── BUTTON HANDLERS ─────────────────────────────────────────────
  void _onBtn(String val) async {
    if (val == 'AC') {
      setState(() {
        _display    = '0';
        _expression = '';
        _result     = 0;
        _newNum     = true;
        _operator   = '';
        _prevNum    = 0;
        _secretPin  = '';
      });
      return;
    }

    if (val == '⌫') {
      setState(() {
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
          if (_secretPin.isNotEmpty) {
            _secretPin = _secretPin.substring(0, _secretPin.length - 1);
          }
        } else {
          _display = '0';
          _newNum  = true;
        }
      });
      return;
    }

    if (val == '=') {
      _calculate();
      // Check if entered digits match real PIN
      await _checkSecretPin();
      return;
    }

    if (['+', '-', '×', '÷'].contains(val)) {
      setState(() {
        _prevNum    = double.tryParse(_display) ?? 0;
        _operator   = val;
        _expression = '$_display $val';
        _newNum     = true;
      });
      return;
    }

    if (val == '%') {
      setState(() {
        final n  = double.tryParse(_display) ?? 0;
        _display = _fmt(n / 100);
      });
      return;
    }

    if (val == '+/-') {
      setState(() {
        final n  = double.tryParse(_display) ?? 0;
        _display = _fmt(-n);
      });
      return;
    }

    if (val == '.') {
      if (_display.contains('.')) return;
      setState(() { _display = '$_display.'; });
      return;
    }

    // Number digit
    setState(() {
      if (_newNum || _display == '0') {
        _display = val;
        _newNum  = false;
      } else {
        if (_display.length < 12) _display = '$_display$val';
      }
      // Track digit presses for secret PIN detection
      _secretPin += val;
      if (_secretPin.length > 8) _secretPin = _secretPin.substring(_secretPin.length - 8);
    });
  }

  void _calculate() {
    final curr = double.tryParse(_display) ?? 0;
    double res  = 0;
    switch (_operator) {
      case '+': res = _prevNum + curr; break;
      case '-': res = _prevNum - curr; break;
      case '×': res = _prevNum * curr; break;
      case '÷': res = curr != 0 ? _prevNum / curr : 0; break;
      default:  res = curr;
    }
    setState(() {
      _expression = '$_expression $_display =';
      _display    = _fmt(res);
      _result     = res;
      _newNum     = true;
      _operator   = '';
    });
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  Future<void> _checkSecretPin() async {
    // Check every contiguous substring of entered digits as potential PIN
    for (int len = 4; len <= _secretPin.length; len++) {
      for (int i = 0; i <= _secretPin.length - len; i++) {
        final sub  = _secretPin.substring(i, i + len);
        final type = await DecoyService.instance.checkPin(sub);
        if (type == PinType.real) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context, '/home', (_) => false,
            );
          }
          return;
        }
      }
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(children: [
          // ── Display ───────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              width:   double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child:   Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment:  MainAxisAlignment.end,
                children: [
                  if (_expression.isNotEmpty)
                    Text(_expression,
                        style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 20,
                            fontFamily: 'SF Pro Display')),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit:   BoxFit.scaleDown,
                    child: Text(_display,
                        style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   72,
                            fontWeight: FontWeight.w200,
                            fontFamily: 'SF Pro Display')),
                  ),
                ],
              ),
            ),
          ),

          // ── Buttons ───────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child:   Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRow(['AC', '+/-', '%', '÷']),
                  _buildRow(['7',  '8',   '9', '×']),
                  _buildRow(['4',  '5',   '6', '-']),
                  _buildRow(['1',  '2',   '3', '+']),
                  _buildRow(['⌫',  '0',   '.', '=']),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRow(List<String> btns) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: btns.map((b) => _CalcBtn(
      label:    b,
      onTap:    () => _onBtn(b),
      isOrange: ['÷', '×', '-', '+', '='].contains(b),
      isGray:   ['AC', '+/-', '%'].contains(b),
    )).toList(),
  );
}

class _CalcBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isOrange;
  final bool isGray;
  const _CalcBtn({required this.label, required this.onTap,
    this.isOrange = false, this.isGray = false});
  @override
  State<_CalcBtn> createState() => _CalcBtnState();
}

class _CalcBtnState extends State<_CalcBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.of(context).size.width - 80) / 4;
    final bg   = widget.isOrange
        ? (_pressed ? Colors.white : const Color(0xFFFF9F0A))
        : widget.isGray
        ? (_pressed ? Colors.white : const Color(0xFF636366))
        : (_pressed ? Colors.white24 : const Color(0xFF333336));
    final fg = widget.isOrange && !_pressed ? Colors.white
        : widget.isOrange && _pressed ? const Color(0xFFFF9F0A)
        : Colors.white;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width:  size,
        height: size,
        decoration: BoxDecoration(
          color:  bg,
          shape:  BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:  Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(widget.label,
              style: TextStyle(
                  color:      fg,
                  fontSize:   widget.label.length > 1 ? 20 : 28,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'SF Pro Display')),
        ),
      ),
    );
  }
}