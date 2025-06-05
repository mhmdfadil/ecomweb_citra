import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BarangKeluarContent extends StatefulWidget {
  const BarangKeluarContent({super.key});

  @override
  _BarangKeluarContentState createState() => _BarangKeluarContentState();
}

class _BarangKeluarContentState extends State<BarangKeluarContent> {
  final SupabaseClient supabase = Supabase.instance.client;
  final GlobalKey _chartKey = GlobalKey();
  
  // Data variables
  List<Map<String, dynamic>> stockOutData = [];
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;
  int currentPage = 1;
  int itemsPerPage = 10;
  int totalItems = 0;
  
  // Filter controls
  String selectedTimePeriod = 'daily';
  String selectedChartType = 'bar';
  final List<String> timePeriodOptions = ['daily', 'weekly', 'monthly'];
  final List<String> chartTypeOptions = ['bar', 'line', 'pie', 'radar', 'heat'];
  
  // Chart colors
  final List<Color> chartColors = [
    Colors.blue.shade400,
    Colors.green.shade400,
    Colors.orange.shade400,
    Colors.purple.shade400,
    Colors.red.shade400,
    Colors.teal.shade400,
    Colors.pink.shade400,
    Colors.indigo.shade400,
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchProducts();
  }

  Future<void> _fetchData() async {
    try {
      setState(() => isLoading = true);
      
      final countResponse = await supabase
          .from('stok_keluar')
          .select('id');
      
      totalItems = countResponse.length;
      
      final response = await supabase
          .from('stok_keluar')
          .select('''
            *, 
            products:product_id (id, name),
            users:user_id (id, username)
          ''')
          .order('created_at', ascending: false)
          .range(
            (currentPage - 1) * itemsPerPage,
            (currentPage * itemsPerPage) - 1,
          );
      
      setState(() {
        stockOutData = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: ${e.toString()}')),
      );
    }
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await supabase
          .from('products')
          .select('id, name, stock')
          .order('name', ascending: true);
      
      setState(() {
        products = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching products: ${e.toString()}')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getChartData() async {
    final now = DateTime.now();
    DateTime startDate;
    
    switch (selectedTimePeriod) {
      case 'daily':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'weekly':
        startDate = now.subtract(const Duration(days: 30 * 6));
        break;
      case 'monthly':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year - 1, now.month, now.day);
    }

    final response = await supabase
        .from('stok_keluar')
        .select('created_at, brg_keluar, product_id, products:product_id (name)')
        .gte('created_at', startDate.toIso8601String())
        .order('created_at', ascending: true);

    if (response.isEmpty) return [];

    final grouped = groupBy(response, (Map<String, dynamic> record) {
      final date = DateTime.parse(record['created_at'] as String);
      
      switch (selectedTimePeriod) {
        case 'daily':
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        case 'weekly':
          final weekStart = date.subtract(Duration(days: date.weekday - 1));
          return '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
        case 'monthly':
          return '${date.year}-${date.month.toString().padLeft(2, '0')}';
        default:
          return '${date.year}-${date.month.toString().padLeft(2, '0')}';
      }
    });

    return grouped.entries.map((entry) {
      DateTime periodDate;
      String periodLabel;
      
      switch (selectedTimePeriod) {
        case 'daily':
          final parts = entry.key.split('-');
          periodDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          periodLabel = DateFormat('d MMM', 'id_ID').format(periodDate);
          break;
        case 'weekly':
          final parts = entry.key.split('-');
          final weekStart = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final weekEnd = weekStart.add(const Duration(days: 6));
          periodDate = weekStart;
          periodLabel = '${DateFormat('d MMM', 'id_ID').format(weekStart)} - ${DateFormat('d MMM', 'id_ID').format(weekEnd)}';
          break;
        case 'monthly':
          final parts = entry.key.split('-');
          periodDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
          periodLabel = DateFormat('MMM yyyy', 'id_ID').format(periodDate);
          break;
        default:
          final parts = entry.key.split('-');
          periodDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
          periodLabel = DateFormat('MMM yyyy', 'id_ID').format(periodDate);
      }

      final total = entry.value.fold<double>(
        0,
        (sum, record) => sum + (record['brg_keluar'] as num).toDouble(),
      );

      return {
        'period': periodDate,
        'label': periodLabel,
        'total': total,
        'count': entry.value.length,
      };
    }).toList();
  }

  Widget _buildChart(List<Map<String, dynamic>> chartData) {
    if (chartData.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data untuk ditampilkan',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    switch (selectedChartType) {
      case 'bar':
        return _buildBarChart(chartData);
      case 'line':
        return _buildLineChart(chartData);
      case 'pie':
        return _buildPieChart(chartData);
      case 'radar':
        return _buildRadarChart(chartData);
      case 'heat':
        return _buildHeatChart(chartData);
      default:
        return _buildBarChart(chartData);
    }
  }

  Widget _buildBarChart(List<Map<String, dynamic>> chartData) {
    final maxValue = chartData.fold<double>(0, (max, item) => 
      item['total'] > max ? item['total'].toDouble() : max);

    return SizedBox(
      height: 350,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxValue * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${chartData[groupIndex]['label']}\n'
                  'Total: ${NumberFormat.decimalPattern('id').format(chartData[groupIndex]['total'])}\n'
                  'Transaksi: ${chartData[groupIndex]['count']}',
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
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < chartData.length) {
                    // return SideTitleWidget(
                    //   axisSide: meta.axisSide,
                    //   child: Text(
                    //     chartData[index]['label'],
                    //     style: const TextStyle(fontSize: 10),
                    //   ),
                    // );
                  }
                  return const Text('');
                },
                reservedSize: 36,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compact().format(value),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  );
                },
                interval: maxValue / 4,
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
            horizontalInterval: maxValue / 4,
          ),
          barGroups: chartData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data['total'].toDouble(),
                  gradient: LinearGradient(
                    colors: [
                      chartColors[index % chartColors.length],
                      chartColors[index % chartColors.length].withOpacity(0.7),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: selectedTimePeriod == 'monthly' ? 22 : 16,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxValue * 1.2,
                    color: Colors.grey.shade100,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> chartData) {
    final maxValue = chartData.fold<double>(0, (max, item) => 
      item['total'] > max ? item['total'].toDouble() : max);

    return SizedBox(
      height: 350,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: chartData.length.toDouble() - 1,
          minY: 0,
          maxY: maxValue * 1.2,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${chartData[spot.x.toInt()]['label']}\n'
                    'Total: ${NumberFormat.decimalPattern('id').format(spot.y)}\n'
                    'Transaksi: ${chartData[spot.x.toInt()]['count']}',
                    const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < chartData.length) {
                    // return SideTitleWidget(
                    //   axisSide: meta.axisSide,
                    //   child: Text(
                    //     chartData[index]['label'],
                    //     style: const TextStyle(fontSize: 10),
                    //   ),
                    // );
                  }
                  return const Text('');
                },
                reservedSize: 36,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compact().format(value),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  );
                },
                interval: maxValue / 4,
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
            horizontalInterval: maxValue / 4,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: chartData.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value['total'].toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.blue,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.blue.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(List<Map<String, dynamic>> chartData) {
    final total = chartData.fold<double>(0, (sum, e) => sum + (e['total'] as num).toDouble());
    final displayData = chartData.length > 8 ? chartData.sublist(chartData.length - 8) : chartData;

    return SizedBox(
      height: 350,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            enabled: true,
            touchCallback: (FlTouchEvent event, pieTouchResponse) {},
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 70,
          sections: displayData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final percentage = ((data['total'] as double) / total * 100).toStringAsFixed(1);
            
            return PieChartSectionData(
              color: chartColors[index % chartColors.length],
              value: data['total'].toDouble(),
              title: '${percentage}%',
              radius: 24,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              badgeWidget: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  data['label'],
                  style: TextStyle(
                    fontSize: 10,
                    color: chartColors[index % chartColors.length],
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              badgePositionPercentageOffset: 1.5,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRadarChart(List<Map<String, dynamic>> chartData) {
    final maxValue = chartData.fold<double>(0, (max, item) => 
      item['total'] > max ? item['total'].toDouble() : max);
    final displayData = chartData.length > 8 ? chartData.sublist(chartData.length - 8) : chartData;

    return SizedBox(
      height: 350,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              dataEntries: displayData.map((data) {
                return RadarEntry(value: data['total'].toDouble());
              }).toList(),
              fillColor: Colors.blue.withOpacity(0.3),
              borderColor: Colors.blue,
              borderWidth: 2,
            ),
          ],
          radarBackgroundColor: Colors.transparent,
          radarBorderData: BorderSide(color: Colors.grey.shade300, width: 1),
          titlePositionPercentageOffset: 0.1,
          titleTextStyle: const TextStyle(
            fontSize: 10,
            color: Colors.black87,
          ),
          getTitle: (index, angle) {
            return RadarChartTitle(
              text: displayData[index]['label'],
              angle: angle,
            );
          },
          radarShape: RadarShape.polygon,
          tickCount: 4,
          ticksTextStyle: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
          tickBorderData: BorderSide(color: Colors.grey.shade300, width: 1),
          gridBorderData: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
    );
  }

  Widget _buildHeatChart(List<Map<String, dynamic>> chartData) {
    final minValue = chartData.fold<double>(
      chartData[0]['total'].toDouble(), 
      (min, item) => item['total'] < min ? item['total'].toDouble() : min
    );
    final maxValue = chartData.fold<double>(0, (max, item) => 
      item['total'] > max ? item['total'].toDouble() : max);

    final colorGradient = LinearGradient(
      colors: [
        Colors.blue.shade100,
        Colors.blue.shade300,
        Colors.blue.shade500,
        Colors.blue.shade700,
        Colors.blue.shade900,
      ],
    );

    return SizedBox(
      height: 350,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxValue * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${chartData[groupIndex]['label']}\n'
                  'Total: ${NumberFormat.decimalPattern('id').format(chartData[groupIndex]['total'])}\n'
                  'Transaksi: ${chartData[groupIndex]['count']}',
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
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < chartData.length) {
                    // return SideTitleWidget(
                    //   axisSide: meta.axisSide,
                    //   child: Text(
                    //     chartData[index]['label'],
                    //     style: const TextStyle(fontSize: 10),
                    //   ),
                    // );
                  }
                  return const Text('');
                },
                reservedSize: 36,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compact().format(value),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  );
                },
                interval: maxValue / 4,
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
            horizontalInterval: maxValue / 4,
          ),
          barGroups: chartData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final value = data['total'].toDouble();
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
                    color: Colors.grey.shade100,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _exportAsPNG() async {
    try {
      final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes != null) {
        final blob = html.Blob([pngBytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'grafik_stok_keluar_${DateFormat('yyyyMMdd').format(DateTime.now())}.png')
          ..click();
        
        html.Url.revokeObjectUrl(url);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grafik berhasil diunduh sebagai PNG')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export PNG: ${e.toString()}')),
      );
    }
  }

  Future<void> _exportAsCSV() async {
    try {
      final chartData = await _getChartData();
      
      final csvData = [
        ['Periode', 'Jumlah Stok Keluar'],
        ...chartData.map((e) => [
          e['label'],
          e['total'].toStringAsFixed(0),
        ]),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      final csvBytes = utf8.encode(csvString);
      
      final blob = html.Blob([csvBytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'data_stok_keluar_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
        ..click();
      
      html.Url.revokeObjectUrl(url);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil diunduh sebagai CSV')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export CSV: ${e.toString()}')),
      );
    }
  }

  Future<void> _exportAsPDF() async {
    try {
      final pdf = pw.Document();
      final chartData = await _getChartData();
      final now = DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Laporan Stok Keluar - $now',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Grafik Stok Keluar', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Periode: ${selectedTimePeriod == 'daily' ? 'Harian' : selectedTimePeriod == 'weekly' ? 'Mingguan' : 'Bulanan'}'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['Periode', 'Jumlah Stok Keluar'],
                ...chartData.map((e) => [
                  e['label'],
                  e['total'].toStringAsFixed(0),
                ]),
              ],
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'laporan_stok_keluar_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf')
        ..click();
      
      html.Url.revokeObjectUrl(url);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan berhasil diunduh sebagai PDF')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export PDF: ${e.toString()}')),
      );
    }
  }

  Future<void> _downloadAllDatasets() async {
    try {
      final now = DateFormat('yyyyMMdd').format(DateTime.now());
      
      await _downloadDataset(
        'stok_keluar', 
        'stok_keluar_$now.csv',
        ['ID', 'Produk', 'Jumlah', 'Tanggal', 'User'],
        (data) => [
          data['id']?.toString() ?? '',
          data['products'] != null ? (data['products'] as Map<String, dynamic>)['name']?.toString() ?? '' : '',
          data['brg_keluar']?.toString() ?? '0',
          data['created_at'] != null 
            ? DateFormat('yyyy-MM-dd').format(DateTime.parse(data['created_at'] as String))
            : '',
          data['users'] != null ? (data['users'] as Map<String, dynamic>)['username']?.toString() ?? '' : '',
        ]
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dataset stok keluar berhasil diunduh')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh dataset: ${e.toString()}')),
      );
    }
  }

  Future<void> _downloadDataset(
    String tableName, 
    String fileName,
    List<String> headers,
    List<String> Function(Map<String, dynamic>) rowMapper,
  ) async {
    try {
      final response = await supabase
          .from(tableName)
          .select('''
            *, 
            products:product_id (id, name),
            users:user_id (id, username)
          ''')
          .order('created_at', ascending: false);
      
      if (response == null || response.isEmpty) return;

      final csvData = [
        headers,
        ...response.map((data) => rowMapper(data)),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      final csvBytes = utf8.encode(csvString);
      
      final blob = html.Blob([csvBytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Error downloading $tableName dataset: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Barang Keluar',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daftar Stok Keluar',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _fetchData,
                                tooltip: 'Refresh Data',
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.download),
                                onSelected: (value) {
                                  if (value == 'all_data') {
                                    _downloadAllDatasets();
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem<String>(
                                    value: 'all_data',
                                    child: Text('Unduh Dataset Stok Keluar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('No')),
                            DataColumn(label: Text('Produk')),
                            DataColumn(label: Text('Jumlah')),
                            DataColumn(label: Text('Tanggal')),
                            DataColumn(label: Text('User')),
                          ],
                          rows: stockOutData.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final product = item['products'] as Map<String, dynamic>?;
                            final user = item['users'] as Map<String, dynamic>?;
                            
                            return DataRow(
                              cells: [
                                DataCell(Text('${index + 1 + ((currentPage - 1)) * itemsPerPage}')),
                                DataCell(Text(product?['name']?.toString() ?? '-')),
                                DataCell(Text(NumberFormat.decimalPattern('id').format(item['brg_keluar'] ?? 0))),
                                DataCell(Text(
                                  item['created_at'] != null 
                                    ? DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(item['created_at'] as String))
                                    : '-',
                                )),
                                DataCell(Text(user?['username']?.toString() ?? '-')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: currentPage > 1
                                ? () {
                                    setState(() {
                                      currentPage--;
                                      _fetchData();
                                    });
                                  }
                                : null,
                          ),
                          Text('Halaman $currentPage'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: (currentPage * itemsPerPage) < totalItems
                                ? () {
                                    setState(() {
                                      currentPage++;
                                      _fetchData();
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grafik Stok Keluar',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.image),
                                onPressed: _exportAsPNG,
                                tooltip: 'Export as PNG',
                              ),
                              IconButton(
                                icon: const Icon(Icons.table_chart),
                                onPressed: _exportAsCSV,
                                tooltip: 'Export as CSV',
                              ),
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf),
                                onPressed: _exportAsPDF,
                                tooltip: 'Export as PDF',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Statistik stok keluar berdasarkan periode',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: selectedTimePeriod,
                              underline: const SizedBox(),
                              items: timePeriodOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value == 'daily' 
                                      ? 'Harian' 
                                      : value == 'weekly' 
                                        ? 'Mingguan' 
                                        : 'Bulanan',
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedTimePeriod = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: selectedChartType,
                              underline: const SizedBox(),
                              items: chartTypeOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value == 'bar' 
                                      ? 'Batang' 
                                      : value == 'line' 
                                        ? 'Garis' 
                                        : value == 'pie'
                                          ? 'Pie'
                                          : value == 'radar'
                                            ? 'Radar'
                                            : 'Heat',
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedChartType = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _getChartData(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text(
                                'Tidak ada data untuk ditampilkan',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }
                          return RepaintBoundary(
                            key: _chartKey,
                            child: _buildChart(snapshot.data!),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}