import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ecomweb/screens/content/resi_cek.dart';

class PemesananContent extends StatefulWidget {
  const PemesananContent({super.key});

  @override
  State<PemesananContent> createState() => _PemesananContentState();
}

class _PemesananContentState extends State<PemesananContent> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _statusLabels = {
    'pending': 'Menunggu',
    'process': 'Diproses',
    'delivered': 'Dikirim',
    'completed': 'Selesai',
    'cancelled': 'Dibatalkan',
  };

  final Map<String, Color> _statusColors = {
    'pending': Color(0xFFFFA726), // Orange
    'process': Color(0xFF42A5F5), // Blue
    'delivered': Color(0xFFAB47BC), // Purple
    'completed': Color(0xFF66BB6A), // Green
    'cancelled': Color(0xFFEF5350), // Red
  };

  final Map<String, Color> _statusLightColors = {
    'pending': Color(0xFFFFF3E0),
    'process': Color(0xFFE3F2FD),
    'delivered': Color(0xFFF3E5F5),
    'completed': Color(0xFFE8F5E9),
    'cancelled': Color(0xFFFFEBEE),
  };

  final List<String> _statusTabs = ['pending', 'process', 'delivered', 'completed', 'cancelled'];
  final Map<String, TextEditingController> _resiControllers = {};
  final Map<String, int> _statusCounts = {
    'pending': 0,
    'process': 0,
    'delivered': 0,
    'completed': 0,
    'cancelled': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _scrollController.addListener(_scrollListener);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    for (var controller in _resiControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (_filteredOrders.length > _currentPage * _itemsPerPage) {
        setState(() {
          _currentPage++;
        });
      }
    }
  }

  Future<void> _fetchOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _currentPage = 1;
      });

      final response = await supabase
          .from('orders')
          .select('''
            *, 
            order_items(*, product:products(*, category:categories(*))),
            payments(*),
            address:addresses(*)
          ''')
          .order('created_at', ascending: false);

      if (response != null) {
        // Calculate status counts
        final counts = {'pending': 0, 'process': 0, 'delivered': 0, 'completed': 0, 'cancelled': 0};
        for (var order in response) {
          final status = order['status'] ?? 'pending';
          counts[status] = (counts[status] ?? 0) + 1;
        }

        setState(() {
          _orders = List<Map<String, dynamic>>.from(response);
          _filteredOrders = _orders;
          _statusCounts.clear();
          _statusCounts.addAll(counts);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data pesanan: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterOrders(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredOrders = _orders;
      } else {
        _filteredOrders = _orders.where((order) {
          final orderNumber = order['order_number']?.toString().toLowerCase() ?? '';
          final recipientName = order['address']?['recipient_name']?.toString().toLowerCase() ?? '';
          final resi = order['resi']?.toString().toLowerCase() ?? '';
          return orderNumber.contains(query.toLowerCase()) ||
              recipientName.contains(query.toLowerCase()) ||
              resi.contains(query.toLowerCase());
        }).toList();
      }
      _currentPage = 1;
    });
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
  try {
    // Update di Supabase
    await supabase
        .from('orders')
        .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', orderId);

    // Update state lokal tanpa perlu fetch ulang
    setState(() {
      final orderIndex = _orders.indexWhere((order) => order['id'].toString() == orderId);
      if (orderIndex != -1) {
        // Update status order
        _orders[orderIndex]['status'] = newStatus;
        _orders[orderIndex]['updated_at'] = DateTime.now().toIso8601String();
        
        // Update status counts
        final oldStatus = _orders[orderIndex]['status'];
        if (_statusCounts.containsKey(oldStatus) && _statusCounts[oldStatus]! > 0) {
          _statusCounts[oldStatus] = _statusCounts[oldStatus]! - 1;
        }
        _statusCounts[newStatus] = (_statusCounts[newStatus] ?? 0) + 1;
        
        // Update filtered orders jika perlu
        if (_searchQuery.isNotEmpty) {
          _filterOrders(_searchQuery);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status berhasil diubah ke ${_statusLabels[newStatus] ?? newStatus}'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal mengupdate status: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

 Future<void> _updateResi(String orderId) async {
  final resi = _resiControllers[orderId]?.text.trim();
  if (resi == null || resi.isEmpty) return;

  try {
    await supabase
        .from('orders')
        .update({
          'resi': resi,
          'updated_at': DateTime.now().toIso8601String()
        })
        .eq('id', orderId);

    // Update state lokal
    setState(() {
      final orderIndex = _orders.indexWhere((order) => order['id'].toString() == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex]['resi'] = resi;
        _orders[orderIndex]['updated_at'] = DateTime.now().toIso8601String();
        
        // Update filtered orders jika perlu
        if (_searchQuery.isNotEmpty) {
          _filterOrders(_searchQuery);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nomor resi berhasil diupdate'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal mengupdate resi: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Widget _buildStatusSummaryCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem('Menunggu', _statusCounts['pending'] ?? 0, _statusColors['pending']!),
                _buildSummaryItem('Diproses', _statusCounts['process'] ?? 0, _statusColors['process']!),
                _buildSummaryItem('Dikirim', _statusCounts['delivered'] ?? 0, _statusColors['delivered']!),
                _buildSummaryItem('Dibatalkan', _statusCounts['cancelled'] ?? 0, _statusColors['cancelled']!),
                _buildSummaryItem('Selesai', _statusCounts['completed'] ?? 0, _statusColors['completed']!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatusIcon(title),
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Menunggu':
        return Icons.access_time;
      case 'Diproses':
        return Icons.autorenew;
      case 'Dikirim':
        return Icons.local_shipping;
      case 'Selesai':
        return Icons.check_circle;
      case 'Dibatalkan':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildCompactOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final orderItems = List<Map<String, dynamic>>.from(order['order_items'] ?? []);
    
    // Calculate subtotal
    double subtotal = 0;
    for (var item in orderItems) {
      subtotal += (item['quantity'] ?? 0) * (item['price'] ?? 0);
    }

    return Card(
      
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOrderDetailsDialog(order, subtotal),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _statusLightColors[status],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'No. Pesanan: #${order['order_number']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColors[status],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabels[status] ?? status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd MMM yyyy').format(DateTime.parse(order['created_at'])),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              if (order['resi'] != null)
                Text(
                  'Resi: ${order['resi']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Text(
                NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                    .format(subtotal + (order['shipping_cost'] ?? 0) + (order['service_fee'] ?? 0) - (order['discount'] ?? 0)),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetailsDialog(Map<String, dynamic> order, double subtotal) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detail Order #${order['order_number']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderDetails(order, subtotal),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderDetails(Map<String, dynamic> order, double subtotal) {
    final orderItems = List<Map<String, dynamic>>.from(order['order_items'] ?? []);
    final payment = order['payments'] != null && (order['payments'] as List).isNotEmpty 
        ? (order['payments'] as List).first 
        : null;
    final address = order['address'] != null ? Map<String, dynamic>.from(order['address']) : null;
    final status = order['status'] ?? 'pending';

    String getStatusText(String status) {
  if (status == 'paid') return 'DIBAYAR';
  if (status == 'pending') return 'BELUM DIBAYAR';
  if (status == 'denied' || status == 'expired') return 'DIBATALKAN';
  return status.toUpperCase(); // fallback
}
    
    // Initialize resi controller if not exists
    _resiControllers.putIfAbsent(order['id'].toString(), () => TextEditingController(text: order['resi']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order items
        ...orderItems.map((item) {
          final product = item['product'] != null ? Map<String, dynamic>.from(item['product']) : null;
          final category = product?['category'] != null ? Map<String, dynamic>.from(product!['category']) : null;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: product != null 
                      ? FutureBuilder(
                          future: _getProductImage(product['id']),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                                ),
                              );
                            }
                            return const Center(child: Icon(Icons.image, color: Colors.grey));
                          },
                        )
                      : const Center(child: Icon(Icons.image, color: Colors.grey)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product?['name'] ?? 'Produk tidak tersedia',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category != null)
                        Text(
                          category['name'] ?? '',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      Text(
                        '${item['quantity']} x ${NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(item['price'])}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        
        const Divider(height: 24),
        
        // Order summary
        _buildOrderSummaryRow('Subtotal Produk', subtotal),
        _buildOrderSummaryRow('Subtotal Pengiriman', order['shipping_cost']),
        _buildOrderSummaryRow('Biaya Layanan', order['service_fee']),
        if ((order['discount'] ?? 0) > 0)
          _buildOrderSummaryRow('Subtotal Diskon', -order['discount'], isDiscount: true),
        const Divider(height: 16),
        _buildOrderSummaryRow(
          'Total Tagihan',
          (subtotal + order['shipping_cost'] + order['service_fee'] - order['discount']),
          isTotal: true,
        ),
        
        // Shipping info
        if (address != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Alamat Pengiriman:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${address['recipient_name']} - ${address['phone_number']}'),
          Text('Kode Pos: ${address['street_address']}'),
        ],

        
        
        // Payment info
        if (payment != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Pembayaran:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Metode: ${order['payment_method']}'),
          Text('Status:  ${getStatusText(payment['status'])}'),
        ],
        
        const SizedBox(height: 16),
          const Text(
            'Pengiriman:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Kurir: ${order['shipping_method'].toString().toUpperCase()}'),

        // Resi input (for processed orders)
        if (status == 'process') ...[
          const SizedBox(height: 16),
          const Text(
            'Nomor Resi:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _resiControllers[order['id'].toString()],
                  decoration: InputDecoration(
                    hintText: 'Masukkan nomor resi',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
             
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _updateResi(order['id'].toString()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _statusColors['delivered'],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
        
        if (order['resi'] != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Nomor Resi:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(order['resi']),
        ],

         if (order['shipping_method'] != null && order['resi'] != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CekResiContent(
                            awb: order['resi'],
                            courier: order['shipping_method'],
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600, // lebih idiomatik
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.track_changes, size: 18),
                        SizedBox(width: 8),
                        Text('Lacak Pengiriman', ),
                      ],
                    ),
                  ),
                ),
              ],
        
        // Action buttons
        if (status == 'pending') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showConfirmationDialog(
                    'Batalkan Pesanan',
                    'Apakah Anda yakin ingin membatalkan pesanan ini?',
                    () => _updateOrderStatus(order['id'].toString(), 'cancelled'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _statusColors['cancelled'],
                    side: BorderSide(color: _statusColors['cancelled']!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Batalkan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateOrderStatus(order['id'].toString(), 'process'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _statusColors['process'],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Proses Pesanan', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
        
        // Status update buttons
        if (status == 'process') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _updateOrderStatus(order['id'].toString(), 'delivered'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _statusColors['delivered'],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Tandai Sebagai Dikirim', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
        
        if (status == 'delivered') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _updateOrderStatus(order['id'].toString(), 'completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _statusColors['completed'],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Tandai Sebagai Selesai', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrderSummaryRow(String label, dynamic amount, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? _statusColors['cancelled'] : Colors.black,
            ),
          ),
          Text(
            NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(amount),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? _statusColors['cancelled'] : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getProductImage(int productId) async {
    try {
      final response = await supabase
          .from('photo_items')
          .select('name')
          .eq('product_id', productId)
          .order('created_at', ascending: true)
          .limit(1);

      if (response != null && response.isNotEmpty) {
        final imageName = response[0]['name'];
        if (imageName != null) {
          return supabase
              .storage
              .from('picture-products')
              .getPublicUrl(imageName);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting product image: $e');
      return null;
    }
  }

  Future<void> _showConfirmationDialog(String title, String message, VoidCallback onConfirm) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              child: const Text('Ya', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 16),
          const Text('Memuat data pesanan...'),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: TextStyle(color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tidak ada pesanan dengan status ini',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = _statusTabs[_tabController.index];
    final filteredOrders = _filteredOrders.where((order) => order['status'] == currentTab).toList();
    final paginatedOrders = filteredOrders.take(_currentPage * _itemsPerPage).toList();

    return Scaffold(
      appBar: AppBar(
       title: const Text(
  'Manajemen Pesanan',
  style: TextStyle(fontWeight: FontWeight.bold),
),

        elevation: 0,
        bottom: TabBar(
  key: ValueKey(_statusCounts.toString()), // Ini akan memaksa rebuild ketika statusCounts berubah
  controller: _tabController,
  isScrollable: true,
  indicatorColor: Colors.blue,
  labelColor: Colors.blue,
  unselectedLabelColor: Colors.black,
  tabs: _statusTabs.map((status) => Tab(
    text: '${_statusLabels[status] ?? status} (${_statusCounts[status] ?? 0})',
  )).toList(),
),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        onChanged: _filterOrders,
                        decoration: InputDecoration(
                          hintText: 'Cari pesanan...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    
                    // Status summary cards
                    _buildStatusSummaryCard(),
                    
                    // Order list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchOrders,
                        child: filteredOrders.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: paginatedOrders.length + (_filteredOrders.length > _currentPage * _itemsPerPage ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index < paginatedOrders.length) {
                                    return _buildCompactOrderCard(paginatedOrders[index]);
                                  } else {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}