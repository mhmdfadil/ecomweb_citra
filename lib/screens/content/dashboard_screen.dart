import 'package:ecomweb/screens/content/grafik.dart';
import 'package:ecomweb/screens/content/pembayaran_screen.dart';
import 'package:ecomweb/screens/content/pemesanan_screen.dart';
import 'package:ecomweb/screens/content/produk_screen.dart';
import 'package:ecomweb/screens/content/build_card.dart'; 
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:csv/csv.dart';
import 'dart:html' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DashboardContent extends StatefulWidget {
  final VoidCallback? onProdukTap;
  final VoidCallback? onPemesananTap;
  final VoidCallback? onPembayaranTap;
  
  const DashboardContent({
    super.key, 
    this.onProdukTap, 
    this.onPemesananTap,
    this.onPembayaranTap,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();

  DashboardContent copyWith({
    VoidCallback? onProdukTap,
    VoidCallback? onPemesananTap,
    VoidCallback? onPembayaranTap,
  }) {
    return DashboardContent(
      key: key,
      onProdukTap: onProdukTap ?? this.onProdukTap,
      onPemesananTap: onPemesananTap ?? this.onPemesananTap,
      onPembayaranTap: onPembayaranTap ?? this.onPembayaranTap,
    );
  }
}

class _DashboardContentState extends State<DashboardContent> {
  final supabase = Supabase.instance.client;
  int totalProducts = 0;
  double totalPayments = 0;
  List<Map<String, dynamic>> salesData = [];
  bool isLoading = true;
  
  // Payment statistics
  Map<String, int> paymentCounts = {
    'paid': 0,
    'pending': 0,
    'deny': 0,
    'expire': 0,
  };
  
  // Order statistics (enhanced from PemesananContent)
  Map<String, int> orderCounts = {
    'pending': 0,
    'process': 0,
    'delivered': 0,
    'cancelled': 0,
    'completed': 0,
  };
  
  // Product statistics
  int outOfStockProducts = 0;
  int lowStockProducts = 0;
  int newProductsThisWeek = 0;
  int bestSellingProducts = 0;
  
  // Filter controls
  String selectedStatus = 'pending';
  String selectedTimePeriod = 'daily';
  String selectedChartType = 'bar';
  final List<String> statusOptions = [
    'pending',
    'process',
    'delivered',
    'cancelled',
    'completed'
  ];
  final List<String> timePeriodOptions = ['daily', 'weekly', 'monthly'];
  final List<String> chartTypeOptions = ['bar', 'line', 'pie', 'radar', 'heat'];

  // Chart colors
  final List<Color> chartColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id_ID';
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      setState(() => isLoading = true);
      
      final results = await Future.wait([
        _getTotalProducts(),
        _getTotalPayments(),
        _getSalesData(),
        _getProductStatistics(),
        _fetchOrderCounts(), // Fetch enhanced order counts
        _fetchPaymentCounts(), // Fetch payment counts
      ]);

      setState(() {
        totalProducts = results[0] as int;
        totalPayments = results[1] as double;
        salesData = results[2] as List<Map<String, dynamic>>;
        
        // Product statistics
        final productStats = results[3] as Map<String, dynamic>;
        outOfStockProducts = productStats['out_of_stock'] ?? 0;
        lowStockProducts = productStats['low_stock'] ?? 0;
        newProductsThisWeek = productStats['new_this_week'] ?? 0;
        bestSellingProducts = productStats['best_selling'] ?? 0;
        
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: ${e.toString()}')),
      );
    }
  }

  // Enhanced order count fetching from PemesananContent
  Future<void> _fetchOrderCounts() async {
    try {
      final counts = await Future.wait([
        _getOrderCount('pending'),
        _getOrderCount('process'),
        _getOrderCount('delivered'),
        _getOrderCount('cancelled'),
        _getOrderCount('completed'),
      ]);

      setState(() {
        orderCounts = {
          'pending': counts[0],
          'process': counts[1],
          'delivered': counts[2],
          'cancelled': counts[3],
          'completed': counts[4],
        };
      });
    } catch (e) {
      debugPrint('Error fetching order counts: $e');
    }
  }

  Future<int> _getOrderCount(String status) async {
    try {
      final response = await supabase
          .from('orders')
          .select()
          .eq('status', status);
      
      if (response is List) {
        return response.length;
      } else if (response != null && response.length != null) {
        return response.length;
      }
      return 0;
    } catch (e) {
      debugPrint('Error fetching $status orders: $e');
      return 0;
    }
  }

  Future<void> _fetchPaymentCounts() async {
    try {
      final counts = await Future.wait([
        _getPaymentCount('paid'),
        _getPaymentCount('pending'),
        _getPaymentCount('deny'),
        _getPaymentCount('expire'),
      ]);

      setState(() {
        paymentCounts = {
          'paid': counts[0],
          'pending': counts[1],
          'deny': counts[2],
          'expire': counts[3],
        };
      });
    } catch (e) {
      debugPrint('Error fetching payment counts: $e');
    }
  }

  Future<int> _getPaymentCount(String status) async {
    try {
      final response = await supabase
          .from('payments')
          .select()
          .eq('status', status);
      
      if (response is List) {
        return response.length;
      }
      return 0;
    } catch (e) {
      debugPrint('Error fetching $status payments: $e');
      return 0;
    }
  }

  Future<int> _getTotalProducts() async {
    final response = await supabase
        .from('products')
        .select()
        .count(CountOption.exact);
    return response.count ?? 0;
  }

  Future<double> _getTotalPayments() async {
    final response = await supabase
        .from('payments')
        .select('amount')
        .eq('status', 'paid');

    if (response.isEmpty) return 0;

    return response.fold<double>(
      0,
      (sum, payment) => sum + (payment['amount'] as num).toDouble(),
    );
  }

  Future<Map<String, dynamic>> _getProductStatistics() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    
    final results = await Future.wait([
      supabase
          .from('products')
          .select()
          .lte('stock', 0)
          .count(CountOption.exact),
      supabase
          .from('products')
          .select()
          .gt('stock', 0)
          .lte('stock', 10)
          .count(CountOption.exact),
      supabase
          .from('products')
          .select()
          .gte('created_at', weekAgo.toIso8601String())
          .count(CountOption.exact),
      supabase
          .from('products')
          .select()
          .order('sold', ascending: false)
          .limit(1)
          .count(CountOption.exact),
    ]);

    return {
      'out_of_stock': results[0].count ?? 0,
      'low_stock': results[1].count ?? 0,
      'new_this_week': results[2].count ?? 0,
      'best_selling': results[3].count ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> _getSalesData() async {
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
        .from('orders')
        .select('created_at, total_amount, status')
        .eq('status', selectedStatus)
        .gte('created_at', startDate.toIso8601String())
        .order('created_at', ascending: true);

    if (response.isEmpty) return [];

    final grouped = groupBy(response, (Map<String, dynamic> order) {
      final date = DateTime.parse(order['created_at'] as String);
      
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
        (sum, order) => sum + (order['total_amount'] as num).toDouble(),
      );

      return {
        'period': periodDate,
        'label': periodLabel,
        'total': total,
        'count': entry.value.length,
        'status': entry.value.first['status'],
      };
    }).toList();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  String getFormattedDate() {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());
  }

  Widget _buildProductInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onProdukTap ?? () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProdukContent()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.withOpacity(0.1), Colors.blue.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Produk',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.blue),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                totalProducts.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildStatItem('Habis Stok', outOfStockProducts.toString(), Icons.warning, Colors.red),
                  _buildStatItem('Stok Rendah', lowStockProducts.toString(), Icons.inventory, Colors.orange),
                  _buildStatItem('Baru Minggu Ini', newProductsThisWeek.toString(), Icons.new_releases, Colors.green),
                  _buildStatItem('Terlaris', bestSellingProducts.toString(), Icons.star, Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    final totalOrders = orderCounts.values.fold(0, (sum, count) => sum + count);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
         onTap: widget.onPemesananTap ?? () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PemesananContent()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Pemesanan',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.green),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                totalOrders.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildStatItem('Pending', orderCounts['pending'].toString(), Icons.pending, Colors.blue),
                  _buildStatItem('Proses', orderCounts['process'].toString(), Icons.autorenew, Colors.orange),
                  _buildStatItem('Dikirim', orderCounts['delivered'].toString(), Icons.local_shipping, Colors.purple),
                  _buildStatItem('Selesai', orderCounts['completed'].toString(), Icons.check_circle, Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

 Widget _buildPaymentInfoCard() {
    final totalPaymentsCount = paymentCounts.values.fold(0, (sum, count) => sum + count);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        
        onTap: widget.onPembayaranTap ?? () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PembayaranContent()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.withOpacity(0.1), Colors.purple.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Pembayaran',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.purple),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(totalPayments),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildStatItem('Berhasil', paymentCounts['paid'].toString(), Icons.check_circle, Colors.green),
                  _buildStatItem('Pending', paymentCounts['pending'].toString(), Icons.pending, Colors.orange),
                  _buildStatItem('Ditolak', paymentCounts['deny'].toString(), Icons.cancel, Colors.red),
                  _buildStatItem('Kadaluarsa', paymentCounts['expire'].toString(), Icons.timer_off, Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                      'Dashboard',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getFormattedDate(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchDashboardData,
                      tooltip: 'Refresh Data',
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.download),
                      onSelected: (value) {
                        if (value == 'pdf') {
                          _exportAsPDF();
                        } else if (value == 'all_data') {
                          _downloadAllDatasets();
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'pdf',
                          child: Text('Export as PDF'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'all_data',
                          child: Text('Unduh Semua Dataset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isLoading)
              _buildLoadingIndicator()
            else
              Column(
                children: [
                  // Responsive grid for info cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 600) {
                        // Desktop/tablet layout
                        return Row(
                          children: [
                            Expanded(child: _buildProductInfoCard()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildOrderInfoCard()), // Updated order card
                            const SizedBox(width: 16),
                            Expanded(child: _buildPaymentInfoCard()),
                          ],
                        );
                      } else {
                        // Mobile layout
                        return Column(
                          children: [
                            _buildProductInfoCard(),
                            const SizedBox(height: 16),
                            _buildOrderInfoCard(), // Updated order card
                            const SizedBox(height: 16),
                            _buildPaymentInfoCard(),
                          ],
                        );
                      }
                    },
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
                                'Grafik Pemesanan',
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
                            'Statistik pemesanan berdasarkan status',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Filter controls
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Status filter
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedStatus,
                                  underline: const SizedBox(),
                                  items: statusOptions.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(_getStatusLabel(value)),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        selectedStatus = newValue;
                                        _fetchDashboardData();
                                      });
                                    }
                                  },
                                ),
                              ),
                              // Time period filter
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
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
                                        _fetchDashboardData();
                                      });
                                    }
                                  },
                                ),
                              ),
                              // Chart type filter
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedChartType,
                                  underline: const SizedBox(),
                                  items: chartTypeOptions.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(_getChartTypeLabel(value)),
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
                          Grafik(
                            salesData: salesData,
                            selectedTimePeriod: selectedTimePeriod,
                            selectedChartType: selectedChartType,
                            selectedStatus: selectedStatus,
                            chartColors: chartColors,
                            chartKey: _chartKey,
                          ).buildChart(),
                          if (salesData.isNotEmpty && selectedChartType != 'pie' && selectedChartType != 'radar')
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Text(
                                'Geser grafik ke kiri/kanan untuk melihat detail',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
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
          ..setAttribute('download', 'grafik_penjualan_${DateFormat('yyyyMMdd').format(DateTime.now())}.png')
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
      final csvData = [
        ['Periode', 'Jumlah Transaksi', 'Total Pendapatan'],
        ...salesData.map((e) => [
          e['label'],
          e['count'],
          _formatCurrency(e['total'] as double),
        ]),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      final csvBytes = utf8.encode(csvString);
      
      final blob = html.Blob([csvBytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'data_penjualan_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
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

      // Add a page with dashboard summary
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Dashboard Report - ${DateFormat('d MMMM yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Ringkasan Dashboard', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfStatCard('Total Produk', totalProducts.toString(), PdfColors.blue),
                _buildPdfStatCard('Total Pemesanan', orderCounts.values.fold(0, (sum, count) => sum + count).toString(), PdfColors.green),
                _buildPdfStatCard('Total Pembayaran', _formatCurrency(totalPayments), PdfColors.purple),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text('Statistik Produk', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.GridView(
              crossAxisCount: 4,
              childAspectRatio: 3,
              children: [
                _buildPdfStatItem('Habis Stok', outOfStockProducts.toString(), PdfColors.red),
                _buildPdfStatItem('Stok Rendah', lowStockProducts.toString(), PdfColors.orange),
                _buildPdfStatItem('Baru Minggu Ini', newProductsThisWeek.toString(), PdfColors.green),
                _buildPdfStatItem('Terlaris', bestSellingProducts.toString(), PdfColors.purple),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text('Statistik Pemesanan', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.GridView(
              crossAxisCount: 5,
              childAspectRatio: 3,
              children: [
                _buildPdfStatItem('Pending', orderCounts['pending'].toString(), PdfColors.blue),
                _buildPdfStatItem('Proses', orderCounts['process'].toString(), PdfColors.orange),
                _buildPdfStatItem('Dikirim', orderCounts['delivered'].toString(), PdfColors.purple),
                _buildPdfStatItem('Selesai', orderCounts['completed'].toString(), PdfColors.green),
                _buildPdfStatItem('Dibatalkan', orderCounts['cancelled'].toString(), PdfColors.red),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text('Statistik Pembayaran', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.GridView(
              crossAxisCount: 4,
              childAspectRatio: 3,
              children: [
                _buildPdfStatItem('Berhasil', paymentCounts['paid'].toString(), PdfColors.green),
                _buildPdfStatItem('Pending', paymentCounts['pending'].toString(), PdfColors.orange),
                _buildPdfStatItem('Ditolak', paymentCounts['deny'].toString(), PdfColors.red),
                _buildPdfStatItem('Kadaluarsa', paymentCounts['expire'].toString(), PdfColors.grey),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Data Penjualan', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['Periode', 'Jumlah Transaksi', 'Total Pendapatan'],
                ...salesData.map((e) => [
                  e['label'],
                  e['count'].toString(),
                  _formatCurrency(e['total'] as double),
                ]),
              ],
            ),
          ],
        ),
      );

      // Save the PDF
      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'dashboard_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf')
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

  pw.Widget _buildPdfStatCard(String title, String value, PdfColor color) {
    return pw.Container(
      width: 150,
      height: 80,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStatItem(String label, String value, PdfColor color) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: color)),
          pw.Text(label, style: pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _downloadAllDatasets() async {
    try {
      // Create a zip file or multiple file downloads
      final now = DateFormat('yyyyMMdd').format(DateTime.now());
      
      // Download products data
      await _downloadDataset(
        'products', 
        'produk_$now.csv',
        ['ID', 'Nama', 'Harga', 'Stok', 'Terjual', 'Dibuat Pada'],
      (data) => [
  data['id']?.toString() ?? '',
  data['name']?.toString() ?? '',
  _formatCurrency((data['price_ori'] as num?)?.toDouble() ?? 0),
  data['stock']?.toString() ?? '0',
  data['sold']?.toString() ?? '0',
  data['created_at'] != null 
    ? DateFormat('yyyy-MM-dd').format(DateTime.parse(data['created_at'] as String))
    : '',
]
      );

      // Download orders data
      await _downloadDataset(
        'orders', 
        'pemesanan_$now.csv',
        ['ID', 'Status', 'Total', 'Dibuat Pada', 'Diupdate Pada'],
        (data) => [
  data['id']?.toString() ?? '',
  _getStatusLabel(data['status'] as String? ?? ''),
  _formatCurrency((data['total_amount'] as num?)?.toDouble() ?? 0),
  data['created_at'] != null 
    ? DateFormat('yyyy-MM-dd').format(DateTime.parse(data['created_at'] as String))
    : '',
  data['updated_at'] != null 
    ? DateFormat('yyyy-MM-dd').format(DateTime.parse(data['updated_at'] as String))
    : '',
]
      );

      // Download payments data
      await _downloadDataset(
        'payments', 
        'pembayaran_$now.csv',
        ['ID', 'Status', 'Jumlah', 'Metode', 'Dibuat Pada'],
      (data) => [
  data['id']?.toString() ?? '',
  data['status']?.toString() ?? '',
  _formatCurrency((data['amount'] as num?)?.toDouble() ?? 0),
  data['method']?.toString() ?? '',
  data['created_at'] != null 
    ? DateFormat('yyyy-MM-dd').format(DateTime.parse(data['created_at'] as String))
    : '',
]
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua dataset berhasil diunduh')),
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
    final response = await supabase.from(tableName).select();
    
    if (response == null || response.isEmpty) return;

    final csvData = [
      headers,
      ...response.map((data) {
        try {
          return rowMapper(data);
        } catch (e) {
          debugPrint('Error mapping row $data: $e');
          // Return a row with error indication if mapping fails
          return ['Error'] + List.filled(headers.length - 1, '');
        }
      }),
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

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'process': return 'Proses';
      case 'delivered': return 'Dikirim';
      case 'cancelled': return 'Dibatalkan';
      case 'completed': return 'Selesai';
      default: return status;
    }
  }

  String _getChartTypeLabel(String type) {
    switch (type) {
      case 'bar': return 'Batang';
      case 'line': return 'Garis';
      case 'pie': return 'Pie';
      case 'radar': return 'Radar';
      case 'heat': return 'Heat';
      default: return type;
    }
  }
}