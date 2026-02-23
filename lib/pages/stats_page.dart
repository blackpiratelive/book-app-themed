import 'dart:math' as math;

import 'package:book_app_themed/models/book.dart';
import 'package:book_app_themed/state/app_controller.dart';
import 'package:book_app_themed/utils/date_formatters.dart';
import 'package:book_app_themed/widgets/book_cover.dart';
import 'package:book_app_themed/widgets/section_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int? _selectedYear;

  Future<void> _pickYear(BuildContext context, List<int> years, int currentYear) async {
    if (years.isEmpty) return;
    var selectedIndex = years.indexOf(currentYear);
    if (selectedIndex < 0) selectedIndex = 0;

    final pickedIndex = await showCupertinoModalPopup<int>(
      context: context,
      builder: (sheetContext) {
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(sheetContext),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator.resolveFrom(sheetContext),
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 0),
                      onPressed: () => Navigator.of(sheetContext).pop(selectedIndex),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: selectedIndex),
                  itemExtent: 38,
                  onSelectedItemChanged: (value) => selectedIndex = value,
                  children: years
                      .map(
                        (year) => Center(
                          child: Text(
                            '$year',
                            style: TextStyle(
                              color: CupertinoColors.label.resolveFrom(sheetContext),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (pickedIndex == null || pickedIndex < 0 || pickedIndex >= years.length) return;
    setState(() => _selectedYear = years[pickedIndex]);
  }

  int _resolveSelectedYear(List<int> years) {
    final nowYear = DateTime.now().year;
    if (_selectedYear != null && years.contains(_selectedYear)) return _selectedYear!;
    if (years.contains(nowYear)) return nowYear;
    if (years.isNotEmpty) return years.first;
    return nowYear;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final stats = _StatsSnapshot.fromBooks(widget.controller.books);
        final selectedYear = _resolveSelectedYear(stats.availableYears);
        final yearly = stats.byYear[selectedYear] ??
            const _YearStats(
              year: 0,
              books: <_FinishedBook>[],
              totalPages: 0,
              authorCounts: <String, int>{},
            );

        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Stats'),
          ),
          child: SafeArea(
            child: stats.finishedBooks.isEmpty
                ? _StatsEmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: <Widget>[
                      SectionCard(
                        title: 'Yearly Overview',
                        child: _YearOverviewSection(
                          years: stats.availableYears,
                          selectedYear: selectedYear,
                          stats: yearly,
                          onPickYear: () => _pickYear(context, stats.availableYears, selectedYear),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Books Read Over Years',
                        child: _YearBarChart(
                          entries: stats.yearSeries,
                          valueForEntry: (entry) => entry.bookCount.toDouble(),
                          accent: CupertinoColors.systemBlue,
                          valueLabel: (value) => value.round().toString(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Pages Read Over Years',
                        child: _YearLineChart(
                          entries: stats.yearSeries,
                          valueForEntry: (entry) => entry.pageCount.toDouble(),
                          accent: CupertinoColors.systemTeal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Reading Medium (Finished Books)',
                        child: _MediumPieChart(mediumCounts: stats.mediumCounts),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _StatsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                CupertinoIcons.chart_bar_fill,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Finished Books Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stats use only locally cached books that are marked Read and have an end date.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearOverviewSection extends StatelessWidget {
  const _YearOverviewSection({
    required this.years,
    required this.selectedYear,
    required this.stats,
    required this.onPickYear,
  });

  final List<int> years;
  final int selectedYear;
  final _YearStats stats;
  final VoidCallback onPickYear;

  @override
  Widget build(BuildContext context) {
    final topAuthors = stats.topAuthors(limit: 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: CupertinoColors.activeBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(CupertinoIcons.calendar, size: 14, color: CupertinoColors.activeBlue),
                  const SizedBox(width: 6),
                  Text(
                    '$selectedYear',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 0),
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
              onPressed: years.isEmpty ? null : onPickYear,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Icon(CupertinoIcons.arrow_2_circlepath, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Change Year',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatsMetricRow(
          items: <_StatsMetricItem>[
            _StatsMetricItem(
              label: 'Books',
              value: '${stats.books.length}',
              tint: CupertinoColors.systemBlue,
              icon: CupertinoIcons.book_solid,
            ),
            _StatsMetricItem(
              label: 'Pages',
              value: '${stats.totalPages}',
              tint: CupertinoColors.systemTeal,
              icon: CupertinoIcons.doc_text_fill,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Top Authors',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 8),
        if (topAuthors.isEmpty)
          Text(
            'No finished books with author data in this year.',
            style: TextStyle(
              fontSize: 13.5,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topAuthors
                .map(
                  (entry) => _AuthorChip(
                    name: entry.key,
                    count: entry.value,
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: 12),
        Text(
          'Finished Books',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 8),
        if (stats.books.isEmpty)
          Text(
            'No finished books found for this year.',
            style: TextStyle(
              fontSize: 13.5,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.books.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.58,
            ),
            itemBuilder: (context, index) {
              final item = stats.books[index];
              return _YearBookGridCard(book: item);
            },
          ),
      ],
    );
  }
}

class _StatsMetricRow extends StatelessWidget {
  const _StatsMetricRow({required this.items});

  final List<_StatsMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: item == items.last ? 0 : 10),
                child: _StatsMetricCard(item: item),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _StatsMetricItem {
  const _StatsMetricItem({
    required this.label,
    required this.value,
    required this.tint,
    required this.icon,
  });

  final String label;
  final String value;
  final CupertinoDynamicColor tint;
  final IconData icon;
}

class _StatsMetricCard extends StatelessWidget {
  const _StatsMetricCard({required this.item});

  final _StatsMetricItem item;

  @override
  Widget build(BuildContext context) {
    final tint = item.tint.resolveFrom(context);
    final fill = Color.alphaBlend(
      tint.withValues(alpha: CupertinoTheme.of(context).brightness == Brightness.dark ? 0.16 : 0.08),
      CupertinoColors.tertiarySystemFill.resolveFrom(context),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, size: 16, color: tint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorChip extends StatelessWidget {
  const _AuthorChip({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearBookGridCard extends StatelessWidget {
  const _YearBookGridCard({required this.book});

  final _FinishedBook book;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: BookCover(
                title: book.item.title,
                coverUrl: book.item.coverUrl,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          book.item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.label.resolveFrom(context),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatDateShort(book.item.endDateIso),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}

class _YearBarChart extends StatelessWidget {
  const _YearBarChart({
    required this.entries,
    required this.valueForEntry,
    required this.accent,
    required this.valueLabel,
  });

  final List<_YearSeriesEntry> entries;
  final double Function(_YearSeriesEntry entry) valueForEntry;
  final CupertinoDynamicColor accent;
  final String Function(double value) valueLabel;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _ChartEmpty(label: 'No finished books yet.');
    }

    final resolvedAccent = accent.resolveFrom(context);
    final values = entries.map(valueForEntry).toList(growable: false);
    final maxValue = values.fold<double>(0, math.max);
    final topY = maxValue <= 0 ? 1.0 : (maxValue * 1.2).ceilToDouble();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: topY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: topY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.18),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: topY / 4,
                getTitlesWidget: (value, meta) => Text(
                  valueLabel(value),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entries[index].year.toString(),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List<BarChartGroupData>.generate(entries.length, (index) {
            final value = valueForEntry(entries[index]);
            return BarChartGroupData(
              x: index,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: value,
                  width: 18,
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[
                      resolvedAccent.withValues(alpha: 0.82),
                      resolvedAccent.withValues(alpha: 0.38),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _YearLineChart extends StatelessWidget {
  const _YearLineChart({
    required this.entries,
    required this.valueForEntry,
    required this.accent,
  });

  final List<_YearSeriesEntry> entries;
  final double Function(_YearSeriesEntry entry) valueForEntry;
  final CupertinoDynamicColor accent;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _ChartEmpty(label: 'No finished books yet.');
    }

    final resolvedAccent = accent.resolveFrom(context);
    final values = entries.map(valueForEntry).toList(growable: false);
    final maxValue = values.fold<double>(0, math.max);
    final topY = maxValue <= 0 ? 1.0 : (maxValue * 1.15).ceilToDouble();

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (entries.length - 1).toDouble(),
          minY: 0,
          maxY: topY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: topY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.18),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: topY / 4,
                getTitlesWidget: (value, meta) => Text(
                  value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.round().toString(),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entries[index].year.toString(),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              isCurved: true,
              color: resolvedAccent,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3.2,
                  color: resolvedAccent,
                  strokeWidth: 1.4,
                  strokeColor: CupertinoColors.systemBackground.resolveFrom(context),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: resolvedAccent.withValues(alpha: 0.12),
              ),
              spots: List<FlSpot>.generate(
                entries.length,
                (index) => FlSpot(index.toDouble(), valueForEntry(entries[index])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediumPieChart extends StatelessWidget {
  const _MediumPieChart({required this.mediumCounts});

  final Map<String, int> mediumCounts;

  @override
  Widget build(BuildContext context) {
    if (mediumCounts.isEmpty) {
      return _ChartEmpty(label: 'No finished books with reading medium yet.');
    }

    final entries = mediumCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, item) => sum + item.value);
    final palette = <CupertinoDynamicColor>[
      CupertinoColors.systemBlue,
      CupertinoColors.systemTeal,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPurple,
      CupertinoColors.systemPink,
      CupertinoColors.systemGreen,
    ];

    return Column(
      children: <Widget>[
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 42,
              sections: List<PieChartSectionData>.generate(entries.length, (index) {
                final entry = entries[index];
                final color = palette[index % palette.length].resolveFrom(context);
                final pct = total == 0 ? 0.0 : (entry.value / total) * 100;
                return PieChartSectionData(
                  color: color,
                  value: entry.value.toDouble(),
                  title: '${pct.round()}%',
                  radius: 62,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(entries.length, (index) {
            final entry = entries[index];
            final color = palette[index % palette.length].resolveFrom(context);
            return _LegendChip(
              color: color,
              label: entry.key,
              value: entry.value,
            );
          }),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _StatsSnapshot {
  const _StatsSnapshot({
    required this.finishedBooks,
    required this.availableYears,
    required this.byYear,
    required this.yearSeries,
    required this.mediumCounts,
  });

  final List<_FinishedBook> finishedBooks;
  final List<int> availableYears;
  final Map<int, _YearStats> byYear;
  final List<_YearSeriesEntry> yearSeries;
  final Map<String, int> mediumCounts;

  factory _StatsSnapshot.fromBooks(List<BookItem> books) {
    final finished = <_FinishedBook>[];
    for (final book in books) {
      if (book.status != BookStatus.read) continue;
      final end = parseDateOnlyIso(book.endDateIso);
      if (end == null) continue;
      finished.add(_FinishedBook(item: book, endedOn: end));
    }

    finished.sort((a, b) {
      final byDate = b.endedOn.compareTo(a.endedOn);
      if (byDate != 0) return byDate;
      return a.item.title.toLowerCase().compareTo(b.item.title.toLowerCase());
    });

    final byYearBuckets = <int, List<_FinishedBook>>{};
    final mediumCounts = <String, int>{};
    for (final entry in finished) {
      byYearBuckets.putIfAbsent(entry.endedOn.year, () => <_FinishedBook>[]).add(entry);
      final mediumLabel = entry.item.medium.label;
      mediumCounts[mediumLabel] = (mediumCounts[mediumLabel] ?? 0) + 1;
    }

    final years = byYearBuckets.keys.toList()..sort((a, b) => b.compareTo(a));
    final byYear = <int, _YearStats>{};
    final yearSeries = <_YearSeriesEntry>[];

    for (final year in years) {
      final yearBooks = List<_FinishedBook>.from(byYearBuckets[year]!)
        ..sort((a, b) {
          final byDate = b.endedOn.compareTo(a.endedOn);
          if (byDate != 0) return byDate;
          return a.item.title.toLowerCase().compareTo(b.item.title.toLowerCase());
        });
      final authorCounts = <String, int>{};
      var totalPages = 0;
      for (final item in yearBooks) {
        final author = item.item.author.trim();
        if (author.isNotEmpty) {
          authorCounts[author] = (authorCounts[author] ?? 0) + 1;
        }
        if (item.item.pageCount > 0) {
          totalPages += item.item.pageCount;
        }
      }
      byYear[year] = _YearStats(
        year: year,
        books: yearBooks,
        totalPages: totalPages,
        authorCounts: authorCounts,
      );
    }

    final yearsAsc = years.toList()..sort();
    for (final year in yearsAsc) {
      final yearStat = byYear[year]!;
      yearSeries.add(
        _YearSeriesEntry(
          year: year,
          bookCount: yearStat.books.length,
          pageCount: yearStat.totalPages,
        ),
      );
    }

    return _StatsSnapshot(
      finishedBooks: finished,
      availableYears: years,
      byYear: byYear,
      yearSeries: yearSeries,
      mediumCounts: mediumCounts,
    );
  }
}

class _FinishedBook {
  const _FinishedBook({
    required this.item,
    required this.endedOn,
  });

  final BookItem item;
  final DateTime endedOn;
}

class _YearStats {
  const _YearStats({
    required this.year,
    required this.books,
    required this.totalPages,
    required this.authorCounts,
  });

  final int year;
  final List<_FinishedBook> books;
  final int totalPages;
  final Map<String, int> authorCounts;

  List<MapEntry<String, int>> topAuthors({int limit = 3}) {
    final entries = authorCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    if (entries.length <= limit) return entries;
    return entries.sublist(0, limit);
  }
}

class _YearSeriesEntry {
  const _YearSeriesEntry({
    required this.year,
    required this.bookCount,
    required this.pageCount,
  });

  final int year;
  final int bookCount;
  final int pageCount;
}
