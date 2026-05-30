import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(context, 'Patient Management', Icons.group, '/patients'),
          _tile(context, 'Medicines', Icons.medication, '/medicines'),
          _tile(context, 'Reports', Icons.bar_chart, '/reports'),
          _tile(context, 'Profile', Icons.person, '/profile'),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String title, IconData icon, String route) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
