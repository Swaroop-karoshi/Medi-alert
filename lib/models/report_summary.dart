class ReportSummary {
  final int taken;
  final int missed;
  final int skipped;

  const ReportSummary({
    required this.taken,
    required this.missed,
    required this.skipped,
  });

  int get total => taken + missed + skipped;
}
