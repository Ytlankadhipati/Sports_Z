import 'package:flutter/material.dart';

/// Global navigator key allowing navigation from anywhere in the app,
/// including root-level broadcast listeners (e.g., 401 session expired).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
