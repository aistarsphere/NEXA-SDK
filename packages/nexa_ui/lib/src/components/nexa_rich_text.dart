import 'package:flutter/material.dart';

/// Direction of [text] from its first strong character (Unicode bidi rule
/// P2/P3), or `null` when it has none (digits, punctuation, emoji only), in
/// which case the ambient direction applies.
///
/// Assistant replies are often in a different language from the UI (an
/// English answer inside the Arabic UI); laying them out in the UI direction
/// moves sentence punctuation to the wrong end.
TextDirection? nexaTextDirectionOf(String text) {
  for (final rune in text.runes) {
    if (_isRtl(rune)) return TextDirection.rtl;
    if (_isLtr(rune)) return TextDirection.ltr;
  }
  return null;
}

bool _isRtl(int c) =>
    (c >= 0x0590 && c <= 0x08FF) || // Hebrew, Arabic, Syriac, Thaana, NKo…
    (c >= 0xFB1D && c <= 0xFDFF) || // Hebrew + Arabic presentation forms A
    (c >= 0xFE70 && c <= 0xFEFF); // Arabic presentation forms B

bool _isLtr(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0xC0 && c <= 0x24F && c != 0xD7 && c != 0xF7) || // Latin-1, Ext-A/B
    (c >= 0x0370 && c <= 0x058F) || // Greek, Cyrillic, Armenian
    (c >= 0x0900 && c <= 0x1FFF) || // Indic, SE Asian, Latin Ext Additional
    (c >= 0x3040 && c <= 0x9FFF) || // Kana, CJK
    (c >= 0xAC00 && c <= 0xD7AF); // Hangul

/// Renders the lightweight Markdown subset assistants commonly produce:
/// headings (`#`…`###`), bullet and numbered lists, fenced code blocks,
/// `**bold**`, `*italic*` and `` `code` ``. Anything else is shown as plain
/// text. Each block takes its own direction from its content.
///
/// [trailing] (e.g. a streaming caret) is appended to the last block.
class NexaRichText extends StatelessWidget {
  const NexaRichText(this.text, {this.style, this.trailing, super.key});

  final String text;
  final TextStyle? style;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final blocks = _parse(text);
    if (blocks.isEmpty) {
      return trailing == null
          ? const SizedBox.shrink()
          : Text.rich(_trailingSpan(), style: base);
    }
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final last = i == blocks.length - 1;
      if (i > 0) children.add(SizedBox(height: b.gapBefore));
      children.add(_buildBlock(context, b, base, last ? trailing : null));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  InlineSpan _trailingSpan() =>
      WidgetSpan(alignment: PlaceholderAlignment.middle, child: trailing!);

  Widget _buildBlock(
    BuildContext context,
    _Block b,
    TextStyle base,
    Widget? tail,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final dir = nexaTextDirectionOf(b.text) ?? Directionality.of(context);
    TextSpan spans(TextStyle s) => TextSpan(
      style: s,
      children: [
        ..._inline(b.text, s, scheme),
        if (tail != null) _trailingSpan(),
      ],
    );
    switch (b.kind) {
      case _Kind.code:
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text.rich(
                TextSpan(
                  text: b.text,
                  children: [if (tail != null) _trailingSpan()],
                ),
                style: base.copyWith(
                  fontFamily: 'monospace',
                  fontSize: (base.fontSize ?? 15) * 0.9,
                  height: 1.45,
                ),
              ),
            ),
          ),
        );
      case _Kind.heading:
        final scale = switch (b.level) {
          1 => 1.25,
          2 => 1.15,
          _ => 1.05,
        };
        return Text.rich(
          spans(
            base.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: (base.fontSize ?? 15) * scale,
            ),
          ),
          textDirection: dir,
        );
      case _Kind.bullet:
      case _Kind.numbered:
        return Directionality(
          textDirection: dir,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: b.kind == _Kind.bullet ? 18 : 26,
                child: Text(
                  b.kind == _Kind.bullet ? '•' : b.marker,
                  style: base.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Expanded(child: Text.rich(spans(base))),
            ],
          ),
        );
      case _Kind.paragraph:
        return Text.rich(spans(base), textDirection: dir);
    }
  }
}

enum _Kind { paragraph, heading, bullet, numbered, code }

final class _Block {
  _Block(
    this.kind,
    this.text, {
    this.level = 0,
    this.marker = '',
    this.gapBefore = 10,
  });
  final _Kind kind;
  final String text;
  final int level;
  final String marker;
  final double gapBefore;
}

final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');
final _numbered = RegExp(r'^\s*(\d{1,3})[.)]\s+(.*)$');
final _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');

List<_Block> _parse(String text) {
  final blocks = <_Block>[];
  final para = <String>[];
  var gap = 0.0;
  void flush() {
    if (para.isEmpty) return;
    blocks.add(_Block(_Kind.paragraph, para.join('\n'), gapBefore: gap));
    para.clear();
    gap = 10;
  }

  final lines = text.replaceAll('\r\n', '\n').split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    if (trimmed.startsWith('```')) {
      flush();
      final code = <String>[];
      i++;
      // An unterminated fence (still streaming) takes the rest of the text.
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        code.add(lines[i]);
        i++;
      }
      blocks.add(_Block(_Kind.code, code.join('\n'), gapBefore: 10));
      continue;
    }
    if (trimmed.isEmpty) {
      flush();
      gap = 10;
      continue;
    }
    if (_rule.hasMatch(trimmed)) {
      flush();
      continue;
    }
    final h = _heading.firstMatch(trimmed);
    if (h != null) {
      flush();
      blocks.add(
        _Block(
          _Kind.heading,
          h.group(2)!.replaceAll(RegExp(r'#+$'), '').trim(),
          level: h.group(1)!.length,
          gapBefore: blocks.isEmpty ? 0 : 14,
        ),
      );
      continue;
    }
    final b = _bullet.firstMatch(line);
    if (b != null) {
      flush();
      blocks.add(_Block(_Kind.bullet, b.group(1)!, gapBefore: 4));
      continue;
    }
    final n = _numbered.firstMatch(line);
    if (n != null) {
      flush();
      blocks.add(
        _Block(
          _Kind.numbered,
          n.group(2)!,
          marker: '${n.group(1)}.',
          gapBefore: 4,
        ),
      );
      continue;
    }
    para.add(line);
  }
  flush();
  if (blocks.isNotEmpty) {
    final first = blocks.first;
    blocks[0] = _Block(
      first.kind,
      first.text,
      level: first.level,
      marker: first.marker,
      gapBefore: 0,
    );
  }
  return blocks;
}

final _inlineToken = RegExp(
  r'(\*\*|__)(.+?)\1|`([^`]+)`|(?<![\w*])\*(?!\s)([^*\n]+?)(?<!\s)\*(?![\w*])',
);

List<InlineSpan> _inline(String text, TextStyle base, ColorScheme scheme) {
  final out = <InlineSpan>[];
  var pos = 0;
  for (final m in _inlineToken.allMatches(text)) {
    if (m.start > pos) out.add(TextSpan(text: text.substring(pos, m.start)));
    if (m.group(2) != null) {
      out.add(
        TextSpan(
          text: m.group(2),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    } else if (m.group(3) != null) {
      out.add(
        TextSpan(
          text: m.group(3),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: scheme.surfaceContainerHigh,
          ),
        ),
      );
    } else {
      out.add(
        TextSpan(
          text: m.group(4),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    pos = m.end;
  }
  if (pos < text.length) out.add(TextSpan(text: text.substring(pos)));
  return out;
}
