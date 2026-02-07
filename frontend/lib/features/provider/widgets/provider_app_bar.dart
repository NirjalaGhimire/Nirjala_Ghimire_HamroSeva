import 'package:flutter/material.dart';
import 'package:hamro_sewa_frontend/core/theme/app_theme.dart';

/// Rounded bottom shape for provider app bars (matches reference UI).
const ShapeBorder providerAppBarShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
);

/// Builds a consistent provider AppBar with title and optional actions.
AppBar buildProviderAppBar({
  required String title,
  Widget? leading,
  List<Widget>? actions,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(
        color: AppTheme.white,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    leading: leading,
    automaticallyImplyLeading: automaticallyImplyLeading,
    backgroundColor: AppTheme.customerPrimary,
    foregroundColor: AppTheme.white,
    elevation: 0,
    shape: providerAppBarShape,
    actions: actions,
  );
}
