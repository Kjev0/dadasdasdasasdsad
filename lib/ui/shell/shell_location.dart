import 'package:flutter/widgets.dart';

/// The current router location, provided by the app shell so chrome widgets
/// (sidebar, rail, player bar) can highlight the active destination.
class ShellLocation extends InheritedWidget {
  const ShellLocation({super.key, required this.uri, required super.child});

  final Uri uri;

  /// Null outside the shell.
  static Uri? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellLocation>()?.uri;

  @override
  bool updateShouldNotify(ShellLocation oldWidget) => oldWidget.uri != uri;
}
