import 'package:flutter/material.dart';
import '../widgets/navbar.dart';
import '../widgets/sidebar.dart';
import '../screens/content/dashboard_screen.dart';
import '../screens/content/produk_screen.dart';
import '../screens/content/pemesanan_screen.dart';
import '../screens/content/pembayaran_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isSidebarVisible = true;
  Widget _currentContent = const DashboardContent();
  String _activePage = 'dashboard';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _adjustSidebarVisibility();
  }

  void _adjustSidebarVisibility() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    if (isMobile && _isSidebarVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _isSidebarVisible = false);
      });
    } else if (!isMobile && !_isSidebarVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _isSidebarVisible = true);
      });
    }
  }

  void _toggleSidebar() {
    setState(() => _isSidebarVisible = !_isSidebarVisible);
  }

  void _changeContent(Widget content, String page) {
    setState(() {
      _currentContent = content;
      _activePage = page;
    });
  }

  void _navigateToProduk() => _changeContent(const ProdukContent(), 'produk');
  void _navigateToPemesanan() => _changeContent(const PemesananContent(), 'pemesanan');
  void _navigateToPembayaran() => _changeContent(PembayaranContent(), 'pembayaran');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          if (_isSidebarVisible)
            Sidebar(
              onChangeContent: _changeContent,
              isSidebarVisible: _isSidebarVisible,
              activePage: _activePage,
            ),
          Expanded(
            child: Column(
              children: [
                Navbar(
                  onMenuPressed: _toggleSidebar,
                  isSidebarVisible: _isSidebarVisible,
                ),
                Expanded(
                  child: _currentContent is DashboardContent
                      ? (_currentContent as DashboardContent).copyWith(
                          onProdukTap: _navigateToProduk,
                          onPemesananTap: _navigateToPemesanan,
                          onPembayaranTap: _navigateToPembayaran,
                        )
                      : _currentContent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}