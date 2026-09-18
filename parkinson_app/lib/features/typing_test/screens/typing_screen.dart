import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Type hub: structured test, free typing, motor task.
class TypingScreen extends StatelessWidget {
  const TypingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Type')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Structured typing'),
              subtitle: const Text('Type a neutral sentence (~1 minute)'),
              onTap: () => context.go('/type/structured'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Free typing'),
              subtitle: const Text('Type anything — only timing is kept'),
              onTap: () => context.go('/type/free'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.repeat_outlined),
              title: const Text('Motor task'),
              subtitle: const Text('15-second alternating F/J tapping'),
              onTap: () => context.go('/type/motor-task'),
            ),
          ),
        ],
      ),
    );
  }
}
