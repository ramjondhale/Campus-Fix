import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The app's router. Stage A placeholder: a single route; the real route table
/// and auth redirect land in the next stage.
final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: EmptyState(icon: Icons.build_outlined, title: 'CampusFix'),
        ),
      ),
    ],
  ),
);
