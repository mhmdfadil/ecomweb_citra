import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PembayaranContent extends StatefulWidget {
  @override
  _PembayaranContentState createState() => _PembayaranContentState();
}

class _PembayaranContentState extends State<PembayaranContent> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> filteredPayments = [];
  String searchQuery = "";
  String selectedStatus = 'paid'; // Default filter status
  int currentPage = 1;
  int itemsPerPage = 5;
  bool isLoading = true;

  // Payment methods and statuses
  final List<String> paymentMethods = ['Transfer Bank', 'E-Wallet', 'Kartu Kredit', 'COD'];
  final List<String> paymentStatuses = ['paid', 'pending', 'deny', 'expire'];

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() => isLoading = true);
    
    try {
      final response = await supabase
          .from('payments')
          .select('''
            *, 
            orders:order_id(*, addresses:address_id(recipient_name))
          ''')
          .order('created_at', ascending: false);
      
      if (response != null && response is List) {
        setState(() {
          payments = List<Map<String, dynamic>>.from(response);
          _applyFilters();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching payments: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load payments')),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      // Apply status filter
      filteredPayments = payments.where((payment) {
        return payment['status'] == selectedStatus;
      }).toList();

      // Apply search filter if query exists
      if (searchQuery.isNotEmpty) {
        filteredPayments = filteredPayments.where((payment) {
          final order = payment['orders'] as Map<String, dynamic>?;
          final userName = order?['addresses']?['recipient_name']?.toString().toLowerCase() ?? '';
          final orderId = payment['order_id']?.toString().toLowerCase() ?? '';
          final paymentId = payment['id']?.toString().toLowerCase() ?? '';
          
          return userName.contains(searchQuery.toLowerCase()) ||
              orderId.contains(searchQuery.toLowerCase()) ||
              paymentId.contains(searchQuery.toLowerCase());
        }).toList();
      }
      
      currentPage = 1;
    });
  }

  List<Map<String, dynamic>> get paginatedPayments {
    int startIndex = (currentPage - 1) * itemsPerPage;
    int endIndex = startIndex + itemsPerPage;
    return filteredPayments.sublist(
      startIndex,
      endIndex.clamp(0, filteredPayments.length),
    );
  }

  Future<void> _updatePaymentStatus(int paymentId, String newStatus) async {
    try {
      await supabase.from('payments').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', paymentId);
      
      await _fetchPayments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment status updated successfully')),
      );
    } catch (e) {
      print('Error updating payment status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update payment status')),
      );
    }
  }

  Future<void> _deletePayment(int paymentId) async {
    try {
      await supabase.from('payments').delete().eq('id', paymentId);
      await _fetchPayments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment deleted successfully')),
      );
    } catch (e) {
      print('Error deleting payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete payment')),
      );
    }
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    final order = payment['orders'] as Map<String, dynamic>?;
    final address = order?['addresses'] as Map<String, dynamic>?;
    String currentStatus = payment['status'] ?? 'pending';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Payment Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Payment ID', payment['id'].toString()),
                _buildDetailRow('Order ID', payment['order_id'].toString()),
                _buildDetailRow('Recipient Name', address?['recipient_name'] ?? 'Unknown'),
                _buildDetailRow('Payment Method', payment['method'] ?? 'Unknown'),
                _buildDetailRow('Amount', _formatCurrency(payment['amount'] ?? 0)),
                _buildDetailRow('Created At', _formatDate(payment['created_at'])),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: currentStatus,
                  items: paymentStatuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      currentStatus = value!;
                    });
                  },
                  decoration: InputDecoration(labelText: 'Payment Status'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updatePaymentStatus(payment['id'], currentStatus);
                Navigator.pop(context);
              },
              child: Text('Update Status'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    final numValue = amount is num ? amount : double.tryParse(amount.toString()) ?? 0;
    return 'Rp ${numValue.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (filteredPayments.length / itemsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
       title: Text(
                   'Daftar Pembayaran', 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                  ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchPayments,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search Payments',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedStatus,
                  items: paymentStatuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value!;
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : filteredPayments.isEmpty
                      ? Center(child: Text('No payments found'))
                      : ListView.builder(
                          itemCount: paginatedPayments.length,
                          itemBuilder: (context, index) {
                            final payment = paginatedPayments[index];
                            final order = payment['orders'] as Map<String, dynamic>?;
                            final address = order?['addresses'] as Map<String, dynamic>?;
                            
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              elevation: 3,
                              child: ListTile(
                                title: Text('Payment #${payment['id']}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4),
                                    Text('Order #${payment['order_id']} - ${address?['recipient_name'] ?? 'Unknown'}'),
                                    SizedBox(height: 4),
                                    Text('Amount: ${_formatCurrency(payment['amount'])}'),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text(
                                            payment['method'] ?? '',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          backgroundColor: Colors.blue,
                                        ),
                                        SizedBox(width: 8),
                                        Chip(
                                          label: Text(
                                            payment['status'] ?? '',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          backgroundColor: _getStatusColor(payment['status']),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.visibility, color: Colors.blue),
                                      onPressed: () => _showPaymentDetails(payment),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deletePayment(payment['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (!isLoading && filteredPayments.isNotEmpty) ...[
              SizedBox(height: 16),
               Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.deepPurple),
                    onPressed: currentPage > 1
                        ? () {
                            setState(() {
                              currentPage--;
                            });
                          }
                        : null,
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Halaman $currentPage dari $totalPages',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward, color: Colors.deepPurple),
                    onPressed: currentPage < totalPages
                        ? () {
                            setState(() {
                              currentPage++;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'deny':
        return Colors.red;
      case 'expire':
        return Colors.grey;
      default:
        return Colors.deepPurple;
    }
  }
}