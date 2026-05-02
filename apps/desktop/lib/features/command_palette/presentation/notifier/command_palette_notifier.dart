/// CommandPaletteNotifier — lightweight ChangeNotifier driving the Cmd+K palette.
///
/// Holds: open/closed flag, current search query, and the highlighted index.
/// Does not own the command list itself — that is built fresh on each open via
/// [buildCommandRegistry] so closures always capture the live context.
library;

import 'package:flutter/widgets.dart';
import 'package:fluxora_desktop/features/command_palette/domain/command.dart';

class CommandPaletteNotifier extends ChangeNotifier {
  bool _open = false;
  String _query = '';
  int _highlightIndex = 0;

  bool get isOpen => _open;
  String get query => _query;
  int get highlightIndex => _highlightIndex;

  void open() {
    _open = true;
    _query = '';
    _highlightIndex = 0;
    notifyListeners();
  }

  void close() {
    _open = false;
    notifyListeners();
  }

  void toggle() => _open ? close() : open();

  void setQuery(String value) {
    _query = value;
    _highlightIndex = 0;
    notifyListeners();
  }

  void moveHighlight(int delta, int listLength) {
    if (listLength == 0) return;
    _highlightIndex = (_highlightIndex + delta).clamp(0, listLength - 1);
    notifyListeners();
  }

  void setHighlight(int index) {
    _highlightIndex = index;
    notifyListeners();
  }

  /// Returns commands from [all] that case-insensitively contain [query].
  List<Command> filter(List<Command> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((c) => c.label.toLowerCase().contains(q))
        .toList();
  }
}
