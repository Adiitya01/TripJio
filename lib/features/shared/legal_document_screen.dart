import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

const _navy = Color(0xFF003F7D);

/// Renders a plain-text legal document bundled in `assets/legal/`.
/// Lightweight by design — no markdown parser dependency. Headings starting
/// with `#` are styled larger; everything else flows as paragraph text.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  Future<String> _load() => rootBundle.loadString(assetPath);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: FutureBuilder<String>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: _navy));
          }
          if (snap.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load this document. Please try again later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: _LegalBody(text: snap.data ?? ''),
          );
        },
      ),
    );
  }
}

class _LegalBody extends StatelessWidget {
  final String text;
  const _LegalBody({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Text(
            line.substring(2),
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            line.substring(3),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _navy),
          ),
        ));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            line.substring(4),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
        ));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ',
                  style: TextStyle(fontSize: 14, color: Colors.black87)),
              Expanded(
                child: Text(
                  line.substring(2),
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.5),
                ),
              ),
            ],
          ),
        ));
      } else if (line.startsWith('|')) {
        // Render markdown table rows as compact text — no fancy table layout.
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            line.replaceAll('|', ' ').trim(),
            style: const TextStyle(
                fontSize: 13, color: Colors.black54, height: 1.4),
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            line,
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.55),
          ),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
