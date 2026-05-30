import 'package:flutter/material.dart';
import '../../../widgets/glass_card.dart';

class BackgroundStabilityScreen extends StatelessWidget {
  const BackgroundStabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Alarm Reliability Guide'),
      ),
      body: SizedBox.expand(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.bolt, color: theme.colorScheme.primary, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Ensure 100% Reliability',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Some Android phones stop apps to save battery, which can prevent your alarms from ringing. Follow the steps below for your device.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildStep(context,
                '1',
                'Disable Battery Optimization',
                'MediAlert must be allowed to run in the background without battery restrictions.',
                Icons.battery_saver,
              ),
              _buildStep(context,
                '2',
                'Enable Auto-Start',
                'Crucial for Xiaomi, Redmi, Oppo, Vivo, and Samsung. This allows the app to restart itself if it was closed.',
                Icons.settings_power,
              ),
              _buildStep(context,
                '3',
                'Lock App in Task Switcher',
                'Open your "Recent Apps" screen and "Lock" MediAlert. This prevents the system from killing the app when you clear all tasks.',
                Icons.lock_open,
              ),
              _buildStep(context,
                '4',
                'Allow "Full-Screen Intents"',
                'Essential for the alarm screen to appear automatically. Go to App Info -> Other Permissions and allow "Display pop-up windows while running in background".',
                Icons.vignette,
              ),
              const SizedBox(height: 32),
              Text(
                'Manufacturer Specific Tips',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildBrandGuide(context,
                'Xiaomi / Redmi',
                '1. Long-press app icon -> App Info\n2. Toggle "Auto-start" to ON\n3. Battery saver -> "No restrictions"\n4. Other permissions -> Allow "Display pop-up windows while running in background" and "Show on Lock screen"',
              ),
              _buildBrandGuide(context,
                'Samsung (One UI)',
                '1. Go to Settings -> Apps -> MediAlert\n2. Tap "Battery" and select "Unrestricted"\n3. Go back to App Info -> "Appear on top" and set to "Allowed"\n4. Settings -> Battery -> Background usage limits -> "Never sleeping apps" -> Add MediAlert',
              ),
              _buildBrandGuide(context,
                'Oppo / Realme / Vivo',
                '1. App Info -> Battery / Power Management\n2. Enable "Allow Background Activity"\n3. Enable "Auto-launch"\n4. Permissions -> Allow "Display pop-up window"',
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String num, String title, String desc, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  num,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandGuide(BuildContext context, String brand, String steps) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ExpansionTile(
          collapsedIconColor: theme.colorScheme.onSurfaceVariant,
          iconColor: theme.colorScheme.primary,
          title: Text(
            brand,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                steps,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
