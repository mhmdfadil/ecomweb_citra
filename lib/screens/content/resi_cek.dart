import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'utils/binderbyte2.dart';

class CekResiContent extends StatefulWidget {
  final String awb;
  final String courier;

  const CekResiContent({
    Key? key,
    required this.awb,
    required this.courier,
  }) : super(key: key);

  @override
  _CekResiContentState createState() => _CekResiContentState();
}

class _CekResiContentState extends State<CekResiContent> {
  bool _isLoading = false;
  Map<String, dynamic>? _trackingResult;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _trackResi();
  }

  Future<void> _trackResi() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _trackingResult = null;
    });

    try {
      final result = await BinderByte2.trackPackage(
        courier: widget.courier,
        awb: widget.awb,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Lacak Pengiriman',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            if (_isLoading) _buildLoadingIndicator(),
            if (_hasError) _buildErrorWidget(),
            if (_trackingResult != null) _buildTrackingResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple[400]!,
            Colors.blue[600]!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Iconsax.box, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nomor Resi',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.awb,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Iconsax.truck, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kurir',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.courier.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
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
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey[200]!,
              highlightColor: Colors.grey[100]!,
              child: Column(
                children: List.generate(
                    3,
                    (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                      color: Colors.grey[300]!, width: 2),
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
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 200,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ]),
                              ),
                            ],
                          ),
                        )),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: Colors.blue[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.red[400]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh, color: Colors.blue[600]),
              ),
              onPressed: _trackResi,
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
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildStatusRow(summary),
                const SizedBox(height: 24),
                _buildDetailRow('Asal', details['origin']),
                const Divider(height: 24),
                _buildDetailRow('Tujuan', details['destination']),
                const Divider(height: 24),
                _buildDetailRow('Pengirim', details['shipper']),
                const Divider(height: 24),
                _buildDetailRow('Penerima', details['receiver']),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.clock, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Riwayat Pengiriman',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${manifest.length} Aktivitas',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
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

  Widget _buildStatusRow(Map<String, dynamic> summary) {
    final statusColor = _getStatusColor(summary['status']);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(summary['status']),
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Pengiriman',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  summary['status'] ?? '-',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 16,
                  ),
                ),
                if (summary['desc'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      summary['desc'],
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            title,
            style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(List<dynamic> manifest) {
    return Column(
      children: List.generate(manifest.length, (index) {
        final item = manifest[index];
        final isFirst = index == 0;
        final isLast = index == manifest.length - 1;
        final isDelivered = _trackingResult!['summary']['status']
            .toString()
            .toLowerCase()
            .contains('delivered');

        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
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
                          ? isDelivered
                              ? Colors.green
                              : Colors.blue
                          : Colors.grey[300],
                      border: Border.all(
                        color: isFirst
                            ? isDelivered
                                ? Colors.green
                                : Colors.blue
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: isFirst
                        ? Icon(Icons.check,
                            size: 14, color: Colors.white)
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
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isFirst
                        ? (isDelivered
                            ? Colors.green[50]
                            : Colors.blue[50])
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['manifest_description'] ?? '-',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isFirst
                              ? (isDelivered
                                  ? Colors.green[800]
                                  : Colors.blue[800])
                              : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Iconsax.calendar,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            item['manifest_date'] ?? '-',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          Icon(Iconsax.clock,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            item['manifest_time'] ?? '-',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                      if (item['city_name'] != null &&
                          item['city_name'] != 'N/A')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(Iconsax.location,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                item['city_name'],
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
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

  IconData _getStatusIcon(String? status) {
    if (status == null) return Icons.help_outline;

    if (status.toLowerCase().contains('delivered')) {
      return Icons.check_circle;
    } else if (status.toLowerCase().contains('failed')) {
      return Icons.error_outline;
    } else if (status.toLowerCase().contains('process')) {
      return Icons.autorenew;
    } else {
      return Icons.info_outline;
    }
  }
}