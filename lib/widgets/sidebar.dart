import 'package:ecomweb/screens/content/resi_screen.dart';
import 'package:flutter/material.dart';
import '../screens/content/dashboard_screen.dart';
import '../screens/content/kategori_screen.dart';
import '../screens/content/produk_screen.dart';
import '../screens/content/pemesanan_screen.dart';
import '../screens/content/pembayaran_screen.dart';
import '../screens/content/banner.dart';
import '../screens/content/barang_masuk.dart';
import '../screens/content/barang_keluar.dart';
import '../screens/content/promo_screen.dart';

class Sidebar extends StatelessWidget {
  final Function(Widget, String) onChangeContent;
  final bool isSidebarVisible;
  final String activePage;

  const Sidebar({super.key, 
    required this.onChangeContent,
    required this.isSidebarVisible,
    required this.activePage,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: isSidebarVisible ? 260 : 0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF273F0), Color(0xFFF273F0)], // Kuning muda ke oranye muda
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Visibility(
        visible: isSidebarVisible,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER SIDEBAR
            Container(
              height: 75,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF273F0), Color(0xFFF273F0)], // Oranye lebih gelap
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  // ignore: deprecated_member_use
                  bottom: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
                ),
              ),
              child: Text(
                '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            // MENU ITEM
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 10),
                children: [
                  _buildMenuItem(
                    title: 'Dashboard',
                    icon: Icons.dashboard,
                    isActive: activePage == 'dashboard',
                    onTap: () => onChangeContent(DashboardContent(), 'dashboard'),
                  ),
                  // _buildMenuItem(
                  //   title: 'Banner',
                  //   icon: Icons.photo_library,
                  //   isActive: activePage == 'banner',
                  //   onTap: () => onChangeContent(BannerEditorScreen(), 'banner'),
                  // ),
                    _buildMenuItem(
                    title: 'Kategori',
                    icon: Icons.category,
                    isActive: activePage == 'kategori',
                    onTap: () => onChangeContent(KategoriContent(), 'kategori'),
                  ),
                  _buildMenuItem(
                    title: 'Produk',
                    icon: Icons.shopping_bag_outlined,
                    isActive: activePage == 'produk',
                    onTap: () => onChangeContent(ProdukContent(), 'produk'),
                  ),
                  _buildMenuItem(
  title: 'Barang Masuk',
  icon: Icons.move_to_inbox, // Ikon masuk/inbox
  isActive: activePage == 'barang_masuk',
  onTap: () => onChangeContent(BarangMasukContent(), 'barang_masuk'),
),
_buildMenuItem(
  title: 'Barang Keluar',
  icon: Icons.local_shipping, // Ikon pengiriman keluar
  isActive: activePage == 'barang_keluar',
  onTap: () => onChangeContent(BarangKeluarContent(), 'barang_keluar'),
),
_buildMenuItem(
  title: 'Promo',
  icon: Icons.local_offer_outlined, // ganti ikon di sini
  isActive: activePage == 'promo',
  onTap: () => onChangeContent(PromoContent(), 'promo'),
),



                  _buildMenuItem(
                    title: 'Pemesanan',
                    icon: Icons.shopping_cart_checkout_outlined,
                    isActive: activePage == 'pemesanan',
                    onTap: () => onChangeContent(PemesananContent(), 'pemesanan'),
                  ),
                  _buildMenuItem(
                    title: 'Pembayaran',
                    icon: Icons.payment_outlined,
                    isActive: activePage == 'pembayaran',
                    onTap: () => onChangeContent(PembayaranContent(), 'pembayaran'),
                  ),
                  _buildMenuItem(
                    title: 'Cek Resi',
                    icon: Icons.local_shipping_outlined, // ikon lebih representatif
                    isActive: activePage == 'resi',
                    onTap: () => onChangeContent(ResiContent(), 'resi'),
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [Color(0xFFF273F0), Color(0xFFF273F0)], // Oranye lebih gelap
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              // ignore: deprecated_member_use
              color: isActive ? Colors.white : Colors.black.withOpacity(0.8),
              size: 26,
            ),
            SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                // ignore: deprecated_member_use
                color: isActive ? Colors.white : Colors.black.withOpacity(0.8),
                fontSize: 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}