import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardUtils {
  static String formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  static String getFormattedDate() {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'process':
        return 'Proses';
      case 'delivered':
        return 'Dikirim';
      case 'cancelled':
        return 'Dibatalkan';
      case 'completed':
        return 'Selesai';
      default:
        return status;
    }
  }

  static String getChartTypeLabel(String type) {
    switch (type) {
      case 'bar':
        return 'Batang';
      case 'line':
        return 'Garis';
      case 'pie':
        return 'Pie';
      case 'radar':
        return 'Radar';
      case 'heat':
        return 'Heat';
      default:
        return type;
    }
  }

  static Color getStatusColor(String status) {
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

  static Widget buildInfoCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ),
    );
  }
}