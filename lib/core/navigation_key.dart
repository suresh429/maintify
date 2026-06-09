import 'package:flutter/material.dart';

/// App-wide [NavigatorState] key. Used by [FcmService] to navigate from
/// notification tap handlers that execute outside the widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();