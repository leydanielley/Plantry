import 'package:flutter/material.dart';
import 'package:growlog_app/theme/design_tokens.dart';

/// Einheitlicher Scaffold-Wrapper für alle Plantry-Screens.
///
/// Erzwingt DT.canvas Background, konsistentes AppBar-Styling
/// und optionale FAB/Actions. Kein Screen soll Scaffold direkt nutzen.
class PlantryScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final Widget? fab;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? titleWidget;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? bottom;

  const PlantryScaffold({
    super.key,
    this.title,
    required this.body,
    this.fab,
    this.actions,
    this.onBack,
    this.showBack = true,
    this.titleWidget,
    this.bottomNavigationBar,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: DT.canvas,
      appBar: (title != null || titleWidget != null)
          ? AppBar(
              title: titleWidget ?? Text(title!),
              leading: (showBack && canPop)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onBack ?? () => Navigator.of(context).pop(),
                    )
                  : null,
              automaticallyImplyLeading: false,
              actions: actions,
              bottom: bottom,
            )
          : null,
      body: body,
      floatingActionButton: fab,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
