import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'utils/binderbyte.dart'; // Update this import

class ResiContent extends StatefulWidget {
  @override
  _ResiContentState createState() => _ResiContentState();
}

class _ResiContentState extends State<ResiContent> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _resiController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String _selectedCourier = 'jne';
  bool _isLoading = false;
  Map<String, dynamic>? _trackingResult;
  bool _hasError = false;
  String _errorMessage = '';

  final List<Map<String, String>> _couriers = [
    {'code': 'jne', 'name': 'JNE'},
    {'code': 'jnt', 'name': 'J&T Express'},
    {'code': 'sicepat', 'name': 'SiCepat'},
  ];

  Future<void> _trackResi() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _trackingResult = null;
      });

      try {
        final result = await BinderByte.trackPackage(
          courier: _selectedCourier,
          awb: _resiController.text.trim(),
        );

        setState(() {
          _trackingResult = result;
        });
      } catch (e) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _resiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildTrackingForm(),
            const SizedBox(height: 32),
            if (_isLoading) _buildLoadingIndicator(),
            if (_hasError) _buildErrorWidget(),
            if (_trackingResult != null) _buildTrackingResult(),
          ],
        ),
      ),
    );
  }

 Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lacak Pengiriman',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan nomor resi dan pilih kurir untuk melacak status pengiriman Anda',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildTrackingForm() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _resiController,
                decoration: InputDecoration(
                  labelText: 'Nomor Resi',
                  prefixIcon: const Icon(Iconsax.box),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan nomor resi';
                  }
                  return null;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCourier,
                decoration: InputDecoration(
                  labelText: 'Pilih Kurir',
                  prefixIcon: const Icon(Iconsax.truck),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: _couriers.map((courier) {
                  return DropdownMenuItem<String>(
                    value: courier['code'],
                    child: Text(courier['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCourier = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Pilih kurir';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
            SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: _trackResi,
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: Colors.indigo.shade600, // lebih idiomatik
      foregroundColor: Colors.white, // cara baru ganti teks/icon color
      textStyle: const TextStyle(fontSize: 16),
      elevation: 2, // opsional: beri sedikit bayangan
    ),
    child: const Text('Lacak Resi'),
  ),
),

            ],
          ),
        ),
      ),
    );
  }

Widget _buildLoadingIndicator() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                children: List.generate(5, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.5,
                              height: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              backgroundColor: Colors.grey[200],
              color: Colors.indigo[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red[100]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildTrackingResult() {
    final summary = _trackingResult!['summary'];
    final details = _trackingResult!['details'];
    final manifest = _trackingResult!['manifest'] as List<dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Iconsax.box,
                        color: Colors.indigo[600],
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nomor Resi',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            summary['waybill'] ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Iconsax.truck,
                        color: Colors.blue[600],
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kurir',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            summary['courier']?.toUpperCase() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Iconsax.clock,
                        color: Colors.green[600],
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            summary['status'] ?? '-',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _getStatusColor(summary['status']),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Pengiriman',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Pengirim', details['shipper'] ?? '-'),
                const Divider(height: 24),
                _buildDetailRow('Penerima', details['receiver'] ?? '-'),
                const Divider(height: 24),
                _buildDetailRow('Alamat Pengirim', details['origin'] ?? '-'),
                const Divider(height: 24),
                _buildDetailRow('Alamat Penerima', details['destination'] ?? '-'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Riwayat Pengiriman',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${manifest.length} Aktivitas',
                        style: TextStyle(
                          color: Colors.indigo[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTimeline(manifest),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Only change needed is in the _buildTimeline method to match the new data structure:
  Widget _buildTimeline(List<dynamic> manifest) {
    return Column(
      children: List.generate(manifest.length, (index) {
        final item = manifest[index];
        final isFirst = index == 0;
        final isLast = index == manifest.length - 1;
        final isProblem = item['status'] == 'Problem' || item['code'].isNotEmpty;
        
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFirst 
                        ? Colors.indigo[500] 
                        : isProblem
                          ? Colors.red[500]
                          : Colors.grey[300],
                      border: Border.all(
                        color: isFirst 
                          ? Colors.indigo[500]! 
                          : isProblem
                            ? Colors.red[500]!
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: isFirst
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          )
                        : isProblem
                          ? const Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 60,
                      color: Colors.grey[300],
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['manifest_description'] ?? '-',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isProblem ? Colors.red : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Iconsax.calendar,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item['manifest_date'] ?? '-',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Iconsax.clock,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item['manifest_time'] ?? '-',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (item['city_name'] != null && item['city_name'] != 'N/A')
                        Row(
                          children: [
                            Icon(
                              Iconsax.location,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item['city_name'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      if (item['code'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Kode Masalah: ${item['code']}',
                              style: TextStyle(
                                color: Colors.red[800],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    
    if (status.toLowerCase().contains('delivered') || 
        status.toLowerCase().contains('terkirim')) {
      return Colors.green;
    } else if (status.toLowerCase().contains('failed') || 
               status.toLowerCase().contains('gagal')) {
      return Colors.red;
    } else if (status.toLowerCase().contains('process') || 
               status.toLowerCase().contains('proses')) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

}
