import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/dashboard/presentation/doctor_dashboard_screen.dart';

import '../features/dashboard/presentation/patient_dashboard_screen.dart';
import '../features/medicines/presentation/add_medicine_screen.dart';
import '../features/medicines/presentation/approved_prescription_screen.dart';
import '../features/medicines/presentation/doctor_inventory_screen.dart';
import '../features/medicines/presentation/patient_inventory_screen.dart';
import '../features/medicines/presentation/prescription_approval_screen.dart';
import '../features/patients/presentation/patient_management_screen.dart';
import '../features/reminders/presentation/alarm_screen.dart';
import '../features/reports/presentation/patient_report_screen.dart';
import '../features/settings/presentation/background_stability_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../models/app_user.dart';
import '../providers/app_providers.dart';
import '../layouts/doctor_main_layout.dart';
import '../layouts/patient_main_layout.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfile = ref.watch(currentUserProfileProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      
      // Patient Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return PatientMainLayout(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/patient/dashboard',
              builder: (context, state) => const PatientDashboardScreen(),
            ),
          ]),

          StatefulShellBranch(routes: [
            GoRoute(
              path: '/patient/reports',
              builder: (context, state) => const ReportsScreen(),
            ),
          ]),
          
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/patient/inventory',
              builder: (context, state) => const PatientInventoryScreen(),
            ),
          ]),
        ],
      ),

      // Doctor Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DoctorMainLayout(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/doctor/dashboard',
              builder: (context, state) => const DoctorDashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/doctor/patients',
              builder: (context, state) => const PatientManagementScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/doctor/inventory',
              builder: (context, state) => const DoctorInventoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/doctor/reports',
              builder: (context, state) => const ReportsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/prescription-approval/:id',
        builder: (context, state) =>
            PrescriptionApprovalScreen(medicineId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/approved-prescription/:id',
        builder: (context, state) =>
            ApprovedPrescriptionScreen(linkId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/add-medicine',
        builder: (context, state) => const AddMedicineScreen(),
      ),

      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      // Alarm screen — shown when a medicine alarm fires
      GoRoute(
        path: '/alarm',
        builder: (context, state) {
          final queryParams = state.uri.queryParameters;
          return AlarmScreen(
            medicineName: queryParams['medicine'] ?? 'Your Medicine',
            scheduledTime: queryParams['time'] ?? DateTime.now().toIso8601String(),
            doctorName: queryParams['doctor'],
            logId: queryParams['logId'],
            prescriptionItemId: queryParams['itemId'],
            alarmId: int.tryParse(queryParams['alarmId'] ?? ''),
          );
        },
      ),
      // Patient report — doctor views a specific patient's adherence
      GoRoute(
        path: '/patient-report/:id',
        builder: (context, state) => PatientReportScreen(
          patientId: state.pathParameters['id']!,
          patientName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/background-stability',
        builder: (context, state) => const BackgroundStabilityScreen(),
      ),
    ],
    redirect: (context, state) {
      final isAuthenticated = authState.asData?.value != null;
      final onLogin = state.uri.path == '/login';
      final onSplash = state.uri.path == '/splash';
      final onAlarm = state.uri.path == '/alarm';

      // Never redirect away from the alarm screen
      if (onAlarm) return null;

      if (authState.isLoading) return null;
      if (!isAuthenticated && !onLogin) return '/login';

      if (isAuthenticated) {
        if (userProfile.isLoading) return '/splash';

        if (userProfile.hasError) {
          debugPrint('Profile error: ${userProfile.error}');
          ref.read(authServiceProvider).signOut();
          return '/login';
        }

        final profile = userProfile.asData?.value;
        if (profile == null) {
          if (onLogin) {
            // We might be mid-signup. Let the login screen finish inserting the record to Supabase.
            return null;
          }
          // If profile fetch fails or hasn't responded properly, log out rather than trapping them
          debugPrint('Profile returned null - logging out');
          ref.read(authServiceProvider).signOut();
          return '/login';
        }

        final isDoctor = profile.role == UserRole.doctor;
        final targetDashboard = isDoctor
            ? '/doctor/dashboard'
            : '/patient/dashboard';
        if (onLogin || onSplash || state.uri.path == '/') {
          return targetDashboard;
        }
      }
      return null;
    },
  );
});
