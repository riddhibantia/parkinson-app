import 'package:flutter/material.dart';

/// Passive notepad area (Stage 2.4). Displays text for the user, but the
/// text itself is never stored or sent — only timing data captured by the
/// session-scoped listener is retained.
class NotepadArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const NotepadArea({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        hintText: 'Type anything freely…',
        border: OutlineInputBorder(),
      ),
    );
  }
}
