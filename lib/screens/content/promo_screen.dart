import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PromoContent extends StatefulWidget {
  const PromoContent({super.key});

  @override
  _PromoContentState createState() => _PromoContentState();
}

class _PromoContentState extends State<PromoContent> {
  final SupabaseClient supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> promoList = [];
  List<Map<String, dynamic>> filteredPromoList = [];
  List<Map<String, dynamic>> productList = [];
  Map<int, String> productNames = {};
  
  String searchQuery = "";
  bool isLoading = true;
  bool isAddingPromo = false;

  // Form controllers
  final TextEditingController _productIdController = TextEditingController();
  final TextEditingController _priceOriController = TextEditingController();
  final TextEditingController _priceDisplayController = TextEditingController();
  final TextEditingController _diskonController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Add listeners for discount calculation
    _diskonController.addListener(_calculateDisplayPrice);
    _priceOriController.addListener(_calculateDisplayPrice);
  }

  void _calculateDisplayPrice() {
    if (_priceOriController.text.isNotEmpty && _diskonController.text.isNotEmpty) {
      try {
        double originalPrice = double.parse(_priceOriController.text);
        double discount = double.parse(_diskonController.text);
        double discountedPrice = originalPrice - (originalPrice * discount / 100);
        
        setState(() {
          _priceDisplayController.text = discountedPrice.toStringAsFixed(0);
        });
      } catch (e) {
        // Handle parsing error
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load all promos sorted by created_at (newest first)
      final promoResponse = await supabase
          .from('promos')
          .select('*')
          .order('created_at', ascending: false);

      // Load all products for dropdown
      final productResponse = await supabase
          .from('products')
          .select('id, name');

      setState(() {
        promoList = List<Map<String, dynamic>>.from(promoResponse);
        filteredPromoList = List<Map<String, dynamic>>.from(promoResponse);
        productList = List<Map<String, dynamic>>.from(productResponse);
        
        // Create map of product IDs to names for easy lookup
        productNames = {
          for (var product in productList) 
            product['id'] as int: product['name'] as String
        };
        
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: $e')),
      );
    }
  }

  void _filterPromos(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      if (searchQuery.isEmpty) {
        filteredPromoList = List.from(promoList);
      } else {
        filteredPromoList = promoList.where((promo) {
          final productName = productNames[promo['product_id']]?.toLowerCase() ?? '';
          final originalPrice = promo['price_ori']?.toString() ?? '';
          final discountPrice = promo['price_display']?.toString() ?? '';
          final discount = promo['diskon']?.toString() ?? '';
          
          return productName.contains(searchQuery) ||
              originalPrice.contains(searchQuery) ||
              discountPrice.contains(searchQuery) ||
              discount.contains(searchQuery);
        }).toList();
      }
    });
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (pickedTime != null) {
        final DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        
        setState(() {
          if (isStartDate) {
            _selectedStartDate = fullDateTime;
            _startDateController.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
          } else {
            _selectedEndDate = fullDateTime;
            _endDateController.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
          }
        });
      }
    }
  }

  Future<void> _addNewPromo() async {
    if (_productIdController.text.isEmpty || 
        _priceOriController.text.isEmpty ||
        _startDateController.text.isEmpty ||
        _endDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap isi semua field yang diperlukan')),
      );
      return;
    }

    setState(() {
      isAddingPromo = true;
    });

    try {
      await supabase.from('promos').insert({
        'product_id': int.parse(_productIdController.text),
        'price_ori': double.parse(_priceOriController.text),
        'price_display': _priceDisplayController.text.isNotEmpty 
            ? double.parse(_priceDisplayController.text)
            : null,
        'diskon': _diskonController.text.isNotEmpty
            ? double.parse(_diskonController.text)
            : null,
        'start_date': _selectedStartDate?.toIso8601String(),
        'end_date': _selectedEndDate?.toIso8601String(),
      });

      // Clear form
      _productIdController.clear();
      _priceOriController.clear();
      _priceDisplayController.clear();
      _diskonController.clear();
      _startDateController.clear();
      _endDateController.clear();
      _selectedStartDate = null;
      _selectedEndDate = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo berhasil ditambahkan')),
      );

      // Reload data
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambahkan promo: $e')),
      );
    } finally {
      setState(() {
        isAddingPromo = false;
      });
    }
  }

  Future<void> _deletePromo(int id) async {
    try {
      await supabase.from('promos').delete().eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo berhasil dihapus')),
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus promo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Promo', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Cari Promo',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          ),
                          onChanged: _filterPromos,
                        ),
                      ),
                      SizedBox(width: 10),
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.blue,
                        onPressed: () => _showAddPromoDialog(context),
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                if (!isMobile) _buildDesktopHeader(),
                Expanded(
                  child: isMobile 
                      ? _buildMobilePromoList()
                      : _buildDesktopPromoList(),
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Produk', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Harga Asli', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Harga Promo', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Diskon', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Tanggal Mulai', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Tanggal Selesai', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 40), // Space for delete button
        ],
      ),
    );
  }

  Widget _buildDesktopPromoList() {
    return ListView.builder(
      itemCount: filteredPromoList.length,
      itemBuilder: (context, index) {
        final promo = filteredPromoList[index];
        final productName = productNames[promo['product_id']] ?? 'Produk Tidak Dikenal';
        final startDate = promo['start_date'] != null 
            ? DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(promo['start_date']))
            : '-';

         final endDate = promo['end_date'] != null 
            ? DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(promo['end_date']))
            : '-';
        
        final originalPrice = promo['price_ori'] != null
            ? NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                .format(promo['price_ori'])
            : '-';
        
        final discountPrice = promo['price_display'] != null
            ? NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                .format(promo['price_display'])
            : '-';
        
        final discountPercentage = promo['diskon'] != null
            ? '${promo['diskon']}%'
            : '-';

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(productName, style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  child: Text(originalPrice, 
                    style: TextStyle(
                      decoration: promo['price_display'] != null
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(discountPrice, 
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(discountPercentage, 
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(startDate),
                ),
                 Expanded(
                  flex: 2,
                  child: Text(endDate),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red.shade600),
                  onPressed: () => _showDeleteConfirmation(promo['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobilePromoList() {
    return ListView.builder(
      itemCount: filteredPromoList.length,
      itemBuilder: (context, index) {
        final promo = filteredPromoList[index];
        final productName = productNames[promo['product_id']] ?? 'Produk Tidak Dikenal';
        final createdAt = promo['created_at'] != null 
            ? DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(promo['created_at']))
            : '-';
        
        final originalPrice = promo['price_ori'] != null
            ? NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                .format(promo['price_ori'])
            : '-';
        
        final discountPrice = promo['price_display'] != null
            ? NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                .format(promo['price_display'])
            : '-';
        
        final discountPercentage = promo['diskon'] != null
            ? '${promo['diskon']}%'
            : '-';

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {},
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          productName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red.shade600),
                        onPressed: () => _showDeleteConfirmation(promo['id']),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('Dibuat: $createdAt', style: TextStyle(color: Colors.grey.shade600)),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Harga Asli', style: TextStyle(color: Colors.grey.shade600)),
                            Text(
                              originalPrice,
                              style: TextStyle(
                                decoration: promo['price_display'] != null
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (promo['price_display'] != null) ...[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Harga Promo', style: TextStyle(color: Colors.grey.shade600)),
                              Text(
                                discountPrice,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (promo['diskon'] != null) ...[
                    SizedBox(height: 12),
                    Text('Diskon', style: TextStyle(color: Colors.grey.shade600)),
                    Text(
                      discountPercentage,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Promo'),
        content: Text('Apakah Anda yakin ingin menghapus promo ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePromo(id);
            },
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddPromoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tambah Promo Baru',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 24),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Produk',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    value: _productIdController.text.isNotEmpty 
                        ? int.tryParse(_productIdController.text)
                        : null,
                    items: productList.map((product) {
                      return DropdownMenuItem<int>(
                        value: product['id'] as int,
                        child: Text(product['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _productIdController.text = value?.toString() ?? '';
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _priceOriController,
                    decoration: InputDecoration(
                      labelText: 'Harga Asli',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _diskonController,
                    decoration: InputDecoration(
                      labelText: 'Persentase Diskon (%)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _calculateDisplayPrice();
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _priceDisplayController,
                    decoration: InputDecoration(
                      labelText: 'Harga Promo',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _startDateController,
                    decoration: InputDecoration(
                      labelText: 'Tanggal Mulai',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () => _selectDateTime(context, true),
                      ),
                    ),
                    readOnly: true,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _endDateController,
                    decoration: InputDecoration(
                      labelText: 'Tanggal Berakhir',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () => _selectDateTime(context, false),
                      ),
                    ),
                    readOnly: true,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Batal'),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isAddingPromo ? null : _addNewPromo,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isAddingPromo
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('Tambah Promo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _priceOriController.dispose();
    _priceDisplayController.dispose();
    _diskonController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }
}