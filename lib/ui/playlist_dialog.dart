import 'package:flutter/material.dart';

import 'glass.dart';

Future<String?> showPlaylistDialog({
  required BuildContext context,
  required bool dark,
  required bool glass,
  required bool english,
}) => showTaktDialog<String>(
  context: context,
  builder: (_) => _PlaylistDialog(dark: dark, glass: glass, english: english),
);

class _PlaylistDialog extends StatefulWidget {
  final bool dark, glass, english;
  const _PlaylistDialog({
    required this.dark,
    required this.glass,
    required this.english,
  });
  @override
  State<_PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<_PlaylistDialog> {
  final name = TextEditingController();
  String tr(String ru, String en) => widget.english ? en : ru;
  void submit() {
    final value = name.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: GlassSurface(
        dark: widget.dark,
        enabled: widget.glass,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Новый плейлист', 'New playlist'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('playlist-create'),
                controller: name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: tr('Название плейлиста', 'Playlist name'),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('Отмена', 'Cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: name.text.trim().isEmpty ? null : submit,
                    child: Text(tr('Создать', 'Create')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
