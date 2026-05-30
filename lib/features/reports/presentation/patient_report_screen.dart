import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../providers/app_providers.dart';
import '../../../widgets/async_value_widget.dart';

/// Doctor-facing patient report screen showing a specific patient's adherence data.
class PatientReportScreen extends ConsumerWidget {
  const PatientReportScreen({super.key, required this.patientId, this.patientName});

  final String patientId;
  final String? patientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(patientAdherenceReportProvider(patientId));
    final chartDataAsync = ref.watch(patientDailyChartDataProvider(patientId));

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          patientName != null ? '$patientName\'s Report' : 'Patient Report',
          style: theme.textTheme.titleLarge,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SizedBox.expand(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildOverallAdherence(context, reportAsync),
              const SizedBox(height: 32),
              _sectionTitle(context, 'Weekly Adherence'),
              const SizedBox(height: 16),
              _buildStackedChartCard(context, chartDataAsync),
              const SizedBox(height: 32),
              _sectionTitle(context, 'Quick Summary'),
              const SizedBox(height: 16),
              _buildSummaryRow(context, reportAsync),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Widget _buildOverallAdherence(BuildContext context, AsyncValue<Map<String, int>> reportAsync) {
    final theme = Theme.of(context);
    return AsyncValueWidget(
      value: reportAsync,
      data: (data) {
        final total = (data['taken'] ?? 0) + (data['missed'] ?? 0) +
            (data['skipped'] ?? 0) + (data['denied'] ?? 0);
        final percentage = total == 0 ? 0.0 : ((data['taken'] ?? 0) / total);

        String label;
        Color labelColor;
        if (percentage >= 0.8) {
          label = 'GREAT PROGRESS';
          labelColor = Colors.green;
        } else if (percentage >= 0.5) {
          label = 'NEEDS ATTENTION';
          labelColor = Colors.orange;
        } else {
          label = 'CRITICAL';
          labelColor = theme.colorScheme.error;
        }

        return GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: percentage,
                      strokeWidth: 10,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: labelColor,
                    ),
                    Text(
                      '${(percentage * 100).toInt()}%',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Compliance',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    'Total Logs: $total',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: labelColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn().scale();
      },
    );
  }

  Widget _buildStackedChartCard(
    BuildContext context,
    AsyncValue<List<Map<String, double>>> chartDataAsync,
  ) {
    final theme = Theme.of(context);
    return AsyncValueWidget(
      value: chartDataAsync,
      data: (data) {
        double maxY = 0;
        for (final day in data) {
          final total = (day['taken'] ?? 0) + (day['missed'] ?? 0) +
              (day['skipped'] ?? 0) + (day['denied'] ?? 0);
          if (total > maxY) maxY = total;
        }

        return GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY + 2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final now = DateTime.now().weekday;
                        final idx = (now - 7 + v.toInt()) % 7;
                        return Text(
                          days[idx],
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final day = data[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (day['taken'] ?? 0) + (day['missed'] ?? 0) +
                            (day['skipped'] ?? 0) + (day['denied'] ?? 0),
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            day['taken'] ?? 0,
                            Colors.green,
                          ),
                          BarChartRodStackItem(
                            day['taken'] ?? 0,
                            (day['taken'] ?? 0) + (day['missed'] ?? 0),
                            theme.colorScheme.error,
                          ),
                          BarChartRodStackItem(
                            (day['taken'] ?? 0) + (day['missed'] ?? 0),
                            (day['taken'] ?? 0) + (day['missed'] ?? 0) +
                                (day['skipped'] ?? 0),
                            Colors.orange,
                          ),
                          BarChartRodStackItem(
                            (day['taken'] ?? 0) + (day['missed'] ?? 0) +
                                (day['skipped'] ?? 0),
                            (day['taken'] ?? 0) + (day['missed'] ?? 0) +
                                (day['skipped'] ?? 0) + (day['denied'] ?? 0),
                            Colors.grey,
                          ),
                        ],
                        color: Colors.transparent,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ).animate().slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildSummaryRow(BuildContext context, AsyncValue<Map<String, int>> reportAsync) {
    final theme = Theme.of(context);
    return AsyncValueWidget(
      value: reportAsync,
      data: (data) => Column(
        children: [
          Row(
            children: [
              _summaryCard(context, 'Taken', data['taken'] ?? 0, Colors.green),
              const SizedBox(width: 12),
              _summaryCard(context, 'Missed', data['missed'] ?? 0, theme.colorScheme.error),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryCard(context, 'Skipped', data['skipped'] ?? 0, Colors.orange),
              const SizedBox(width: 12),
              _summaryCard(context, 'Denied', data['denied'] ?? 0, Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, String label, int val, Color color) {
    return Expanded(
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$val',
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
