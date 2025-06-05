// grafik.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class Grafik {
  final List<Map<String, dynamic>> salesData;
  final String selectedTimePeriod;
  final String selectedChartType;
  final String selectedStatus;
  final List<Color> chartColors;
  final GlobalKey chartKey;

  Grafik({
    required this.salesData,
    required this.selectedTimePeriod,
    required this.selectedChartType,
    required this.selectedStatus,
    required this.chartColors,
    required this.chartKey,
  });

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'process':
        return Colors.blue;
      case 'delivered':
        return Colors.lightBlue;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Widget buildChart() {
    switch (selectedChartType) {
      case 'line':
        return _buildLineChart();
      case 'pie':
        return _buildPieChart();
      case 'radar':
        return _buildRadarChart();
      case 'heat':
        return _buildHeatChart();
      case 'bar':
      default:
        return _buildBarChart();
    }
  }

  Widget _buildBarChart() {
    if (salesData.isEmpty) {
      return _buildNoDataMessage();
    }

    // Sort data by period
    salesData.sort((a, b) => (a['period'] as DateTime).compareTo(b['period'] as DateTime));

    // Limit display data based on time period
    List<Map<String, dynamic>> displayData = _getDisplayData();

    // Find max value for scaling
    final maxValue = displayData
        .map<double>((e) => e['total'] as double)
        .reduce((a, b) => a > b ? a : b);

    return RepaintBoundary(
      key: chartKey,
      child: Container(
        padding: const EdgeInsets.only(top: 16, right: 16),
        height: 300,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxValue * 1.2, // Add 20% padding at top
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding: const EdgeInsets.all(8),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final period = displayData[groupIndex]['label'] as String;
                  final total = displayData[groupIndex]['total'] as double;
                  final count = displayData[groupIndex]['count'] as int;
                  return BarTooltipItem(
                    '$period\n'
                    'Total: ${_formatCurrency(total)}\n'
                    'Transaksi: $count',
                    const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 70,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const Text('0');
                    return Padding(
                      padding: const EdgeInsets.only(right: 0.0),
                      child: Text(
                        _formatCurrency(value),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                  interval: maxValue / 4,
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= displayData.length) return const SizedBox();
                    final label = displayData[value.toInt()]['label'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                  reservedSize: 36,
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[200],
                  strokeWidth: 1,
                );
              },
              horizontalInterval: maxValue / 4,
            ),
            borderData: FlBorderData(
              show: false,
            ),
            barGroups: displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final colorIndex = index % chartColors.length;
              
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: data['total'] as double,
                    gradient: LinearGradient(
                      colors: [
                        chartColors[colorIndex],
                        chartColors[colorIndex].withOpacity(0.7),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: selectedTimePeriod == 'monthly' ? 22 : 16,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxValue * 1.2,
                      color: Colors.grey[200],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    if (salesData.isEmpty) {
      return _buildNoDataMessage();
    }

    salesData.sort((a, b) => (a['period'] as DateTime).compareTo(b['period'] as DateTime));
    List<Map<String, dynamic>> displayData = _getDisplayData();
    final maxValue = displayData
        .map<double>((e) => e['total'] as double)
        .reduce((a, b) => a > b ? a : b);

    Set<String> labeledWeeks = {};

    return RepaintBoundary(
      key: chartKey,
      child: Container(
        padding: const EdgeInsets.only(top: 16, right: 16),
        height: 300,
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                  return touchedSpots.map((spot) {
                    final data = displayData[spot.x.toInt()];
                    return LineTooltipItem(
                      '${data['label']}\n'
                      'Total: ${_formatCurrency(data['total'] as double)}\n'
                      'Transaksi: ${data['count']}',
                      const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[200],
                  strokeWidth: 1,
                );
              },
              horizontalInterval: maxValue / 4,
            ),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 70,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const Text('0');
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        _formatCurrency(value),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                  interval: maxValue / 4,
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= displayData.length) return const SizedBox();
                    
                    final data = displayData[value.toInt()];
                    final periodDate = data['period'] as DateTime;
                    
                    if (selectedTimePeriod == 'weekly') {
                      final weekStart = periodDate.subtract(Duration(days: periodDate.weekday - 1));
                      final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
                      
                      if (labeledWeeks.contains(weekKey)) {
                        return const SizedBox();
                      }
                      
                      labeledWeeks.add(weekKey);
                      final weekEnd = weekStart.add(const Duration(days: 6));
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${DateFormat('d MMM', 'id_ID').format(weekStart)} - ${DateFormat('d MMM', 'id_ID').format(weekEnd)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }
                    
                    if (selectedTimePeriod == 'daily') {
                      if (value.toInt() > 0 && 
                          periodDate.day == (displayData[value.toInt() - 1]['period'] as DateTime).day) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('d MMM', 'id_ID').format(periodDate),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }
                    
                    if (selectedTimePeriod == 'monthly') {
                      if (value.toInt() > 0 && 
                          periodDate.month == (displayData[value.toInt() - 1]['period'] as DateTime).month) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('MMM yyyy', 'id_ID').format(periodDate),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }
                    
                    return const SizedBox();
                  },
                  reservedSize: 36,
                ),
              ),
            ),
            borderData: FlBorderData(
              show: false,
            ),
            minX: 0,
            maxX: displayData.length.toDouble() - 1,
            minY: 0,
            maxY: maxValue * 1.2,
            lineBarsData: [
              LineChartBarData(
                spots: displayData.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    entry.value['total'] as double,
                  );
                }).toList(),
                isCurved: true,
                color: _getStatusColor(selectedStatus),
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: _getStatusColor(selectedStatus),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      _getStatusColor(selectedStatus).withOpacity(0.3),
                      _getStatusColor(selectedStatus).withOpacity(0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (salesData.isEmpty) {
      return _buildNoDataMessage();
    }

    salesData.sort((a, b) => (a['period'] as DateTime).compareTo(b['period'] as DateTime));
    List<Map<String, dynamic>> displayData = salesData.length > 8 
        ? salesData.sublist(salesData.length - 8)
        : salesData;

    final total = displayData.fold<double>(0, (sum, e) => sum + (e['total'] as double));

    return RepaintBoundary(
      key: chartKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 400,
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              enabled: true,
              touchCallback: (FlTouchEvent event, pieTouchResponse) {},
            ),
            borderData: FlBorderData(show: false),
            sectionsSpace: 2,
            centerSpaceRadius: 60,
            sections: displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final percentage = ((data['total'] as double) / total * 100).toStringAsFixed(1);
              final colorIndex = index % chartColors.length;
              
              return PieChartSectionData(
                color: chartColors[colorIndex],
                value: data['total'] as double,
                title: '${percentage}%',
                radius: 40,
                titleStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                badgeWidget: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: chartColors[colorIndex],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                badgePositionPercentageOffset: 2.0,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildRadarChart() {
    if (salesData.isEmpty) {
      return _buildNoDataMessage();
    }

    salesData.sort((a, b) => (a['period'] as DateTime).compareTo(b['period'] as DateTime));
    List<Map<String, dynamic>> displayData = salesData.length > 8 
        ? salesData.sublist(salesData.length - 8)
        : salesData;

    final maxValue = displayData
        .map<double>((e) => e['total'] as double)
        .reduce((a, b) => a > b ? a : b);

    return RepaintBoundary(
      key: chartKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 400,
        child: RadarChart(
          RadarChartData(
            dataSets: [
              RadarDataSet(
                dataEntries: displayData.map((data) {
                  return RadarEntry(
                    value: data['total'] as double,
                  );
                }).toList(),
                fillColor: _getStatusColor(selectedStatus).withOpacity(0.3),
                borderColor: _getStatusColor(selectedStatus),
                borderWidth: 2,
              ),
            ],
            radarBackgroundColor: Colors.transparent,
            radarBorderData: BorderSide(color: Colors.grey[300]!, width: 1),
            titlePositionPercentageOffset: 0.2,
            titleTextStyle: const TextStyle(
              fontSize: 10,
              color: Colors.black87,
            ),
            getTitle: (index, angle) {
              return RadarChartTitle(
                text: displayData[index]['label'] as String,
                angle: angle,
              );
            },
            radarShape: RadarShape.polygon,
            tickCount: 4,
            ticksTextStyle: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            tickBorderData: BorderSide(color: Colors.grey[300]!, width: 1),
            gridBorderData: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildHeatChart() {
    if (salesData.isEmpty) {
      return _buildNoDataMessage();
    }

    salesData.sort((a, b) => (a['period'] as DateTime).compareTo(b['period'] as DateTime));
    List<Map<String, dynamic>> displayData = _getDisplayData();

    final minValue = displayData
        .map<double>((e) => e['total'] as double)
        .reduce((a, b) => a < b ? a : b);
    final maxValue = displayData
        .map<double>((e) => e['total'] as double)
        .reduce((a, b) => a > b ? a : b);

    final colorGradient = LinearGradient(
      colors: [
        Colors.blue[100]!,
        Colors.blue[300]!,
        Colors.blue[500]!,
        Colors.blue[700]!,
        Colors.blue[900]!,
      ],
    );

    return RepaintBoundary(
      key: chartKey,
      child: Container(
        padding: const EdgeInsets.only(top: 16, right: 16),
        height: 300,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxValue * 1.2,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding: const EdgeInsets.all(8),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final period = displayData[groupIndex]['label'] as String;
                  final total = displayData[groupIndex]['total'] as double;
                  final count = displayData[groupIndex]['count'] as int;
                  return BarTooltipItem(
                    '$period\n'
                    'Total: ${_formatCurrency(total)}\n'
                    'Transaksi: $count',
                    const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 70,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const Text('0');
                    return Padding(
                      padding: const EdgeInsets.only(right: 0.0),
                      child: Text(
                        _formatCurrency(value),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                  interval: maxValue / 4,
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= displayData.length) return const SizedBox();
                    final label = displayData[value.toInt()]['label'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                  reservedSize: 36,
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[200],
                  strokeWidth: 1,
                );
              },
              horizontalInterval: maxValue / 4,
            ),
            borderData: FlBorderData(
              show: false,
            ),
            barGroups: displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final value = data['total'] as double;
              final normalizedValue = (value - minValue) / (maxValue - minValue);
              final color = Color.lerp(
                colorGradient.colors.first,
                colorGradient.colors.last,
                normalizedValue,
              )!;
              
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: value,
                    color: color,
                    width: selectedTimePeriod == 'monthly' ? 22 : 16,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxValue * 1.2,
                      color: Colors.grey[200],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getDisplayData() {
    switch (selectedTimePeriod) {
      case 'daily':
        return salesData.length > 30 ? salesData.sublist(salesData.length - 30) : salesData;
      case 'weekly':
        return salesData.length > 12 ? salesData.sublist(salesData.length - 12) : salesData;
      case 'monthly':
        return salesData.length > 12 ? salesData.sublist(salesData.length - 12) : salesData;
      default:
        return salesData;
    }
  }

  Widget _buildNoDataMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Tidak ada data penjualan yang tersedia',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}