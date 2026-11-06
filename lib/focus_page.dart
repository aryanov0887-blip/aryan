import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// تایمر تمرکز؛ با بستن صفحه، ثانیه‌های تمرکز واقعی برگردانده می‌شود.
class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  int minutes = 25;
  bool running = false;
  int baseElapsed = 0;
  DateTime? runStart;
  Timer? timer;

  int get total => minutes * 60;

  int get elapsed {
    final r = runStart;
    final live = (running && r != null) ? DateTime.now().difference(r).inSeconds : 0;
    return baseElapsed + live;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _start() {
    runStart = DateTime.now();
    running = true;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (elapsed >= total) {
        _finish();
      } else if (mounted) {
        setState(() {});
      }
    });
    setState(() {});
  }

  void _pause() {
    baseElapsed = elapsed;
    running = false;
    runStart = null;
    timer?.cancel();
    setState(() {});
  }

  void _finish() {
    timer?.cancel();
    final secs = elapsed > total ? total : elapsed;
    if (mounted) Navigator.of(context).pop(secs);
  }

  @override
  Widget build(BuildContext context) {
    final left = (total - elapsed) < 0 ? 0 : total - elapsed;
    final canChange = !running && baseElapsed == 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تمرکز'),
          leading: IconButton(
            onPressed: _finish,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [15, 25, 45, 60])
                    ChoiceChip(
                      label: Text('$m دقیقه'),
                      selected: minutes == m,
                      showCheckmark: false,
                      selectedColor: kAccent,
                      backgroundColor: kChip,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: minutes == m ? kOnAccent : kText,
                      ),
                      onSelected: canChange
                          ? (_) => setState(() => minutes = m)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(
                        value: total == 0 ? 0 : elapsed / total,
                        strokeWidth: 10,
                        backgroundColor: kTrack,
                        color: kAccent,
                      ),
                    ),
                    Text(
                      '${two(left ~/ 60)}:${two(left % 60)}',
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w300,
                        color: kText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: running ? _pause : _start,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    label: Text(running ? 'توقف' : (baseElapsed > 0 ? 'ادامه' : 'شروع')),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _finish,
                    child: const Text('پایان و ثبت'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'برای دقیق‌بودن زمان، برنامه را باز نگه دار.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kDim, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
