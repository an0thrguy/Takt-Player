import 'package:flutter/material.dart';

import '../playback/sleep_timer.dart';
import 'glass.dart';

class SleepTimerDialog extends StatefulWidget {
  final SleepTimer timer;
  final bool english, dark;
  const SleepTimerDialog({
    super.key,
    required this.timer,
    required this.english,
    required this.dark,
  });
  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  final minutes = TextEditingController(text: '30');
  bool fade = false, exit = false, busy = false;
  String t(String ru, String en) => widget.english ? en : ru;
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.timer.addListener(refresh);
  }

  @override
  void dispose() {
    widget.timer.removeListener(refresh);
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: GlassSurface(
      dark: widget.dark,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t('Таймер сна', 'Sleep timer'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.timer.active)
                    Text(
                      t(
                        'Осталось: ${widget.timer.remaining.inMinutes + 1} мин',
                        'Remaining: ${widget.timer.remaining.inMinutes + 1} min',
                      ),
                    ),
                  TextField(
                    key: const Key('sleep-minutes'),
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: t('Минуты (1-240)', 'Minutes (1-240)'),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in [15, 30, 60])
                        ActionChip(
                          label: Text('$n'),
                          onPressed: () => setState(() => minutes.text = '$n'),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    title: Text(
                      t(
                        'Плавно снижать громкость за 15 секунд',
                        'Fade volume over the last 15 seconds',
                      ),
                    ),
                    value: fade,
                    onChanged: (v) => setState(() => fade = v),
                  ),
                  SwitchListTile(
                    title: Text(
                      t(
                        'Полностью закрыть после остановки',
                        'Quit after pausing',
                      ),
                    ),
                    value: exit,
                    onChanged: (v) => setState(() => exit = v),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.timer.active)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  await widget.timer.cancel();
                                  if (context.mounted) Navigator.pop(context);
                                },
                          child: Text(t('Отключить', 'Cancel timer')),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('Отмена', 'Cancel')),
                      ),
                      FilledButton(
                        key: const Key('sleep-start'),
                        onPressed:
                            busy ||
                                (int.tryParse(minutes.text) ?? 0) < 1 ||
                                (int.tryParse(minutes.text) ?? 241) > 240
                            ? null
                            : () async {
                                setState(() => busy = true);
                                try {
                                  await widget.timer.start(
                                    Duration(minutes: int.parse(minutes.text)),
                                    fade: fade,
                                    exitWhenDone: exit,
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => busy = false);
                                }
                              },
                        child: Text(t('Запустить', 'Start')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
