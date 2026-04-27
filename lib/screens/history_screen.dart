import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_controller.dart';
import '../models/noise_record.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppController>();
    final today = ctrl.todayStats;
    final week = ctrl.weekStats;
    final loc = ctrl.locationStats;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('📊', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Noise History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),

          // Stats row
          Row(children: [
            _StatCard(label: 'Today', stats: today),
            const SizedBox(width: 10),
            _StatCard(label: 'Week', stats: week),
            const SizedBox(width: 10),
            _StatCard(label: 'Here', stats: loc),
          ]),
          const SizedBox(height: 20),

          // Chart
          if (ctrl.records.isNotEmpty) _DbChart(records: ctrl.records),
          if (ctrl.records.isNotEmpty) const SizedBox(height: 20),

          // Recent recordings
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEEF2FF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(children: [
                      Text('📋', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text('Recent Recordings',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
                    if (ctrl.records.isNotEmpty)
                      TextButton(
                        onPressed: () => _confirmClear(context, ctrl),
                        child: const Text('Clear',
                            style: TextStyle(
                                color: Color(0xFFEF4444), fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (ctrl.records.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No recordings yet.\nStart monitoring to collect data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  ...ctrl.records.reversed
                      .take(10)
                      .map((r) => _RecordRow(record: r)),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '📌 Data stored locally. No audio is saved or uploaded.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, AppController ctrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('All recorded noise data will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                ctrl.clearHistory();
                Navigator.pop(context);
              },
              child: const Text('Clear',
                  style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final Map<String, double?> stats;
  const _StatCard({required this.label, required this.stats});

  @override
  Widget build(BuildContext context) {
    final min = stats['min'];
    final max = stats['max'];
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            min != null
                ? '${min.toStringAsFixed(0)}–${max!.toStringAsFixed(0)}'
                : '--',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Text('dB',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ]),
      ),
    );
  }
}

class _DbChart extends StatelessWidget {
  final List<NoiseRecord> records;
  const _DbChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final last20 = records.reversed.take(20).toList().reversed.toList();
    final spots = last20.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.db);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEF2FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('📈', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text('Noise Trend (last 20 readings)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(LineChartData(
              minY: 20,
              maxY: 100,
              gridData: const FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 20,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF94A3B8))),
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: const Color(0xFF2563EB),
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                      radius: 3,
                      color: Color(AppController.dbColorValue(spot.y)),
                      strokeWidth: 1,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0x1A2563EB),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final NoiseRecord record;
  const _RecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = Color(AppController.dbColorValue(record.db));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEF2FF)))),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.location,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
              Text(record.timeLabel,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(record.dbLabel,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ]),
    );
  }
}
