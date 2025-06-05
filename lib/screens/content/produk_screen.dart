import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

class ProdukContent extends StatefulWidget {
  const ProdukContent({super.key});

  @override
  _ProdukContentState createState() => _ProdukContentState();
}

class _ProdukContentState extends State<ProdukContent> {
  final SupabaseClient supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> produkList = [];
  List<Map<String, dynamic>> categoriesList = [];
  
  List<String> metodePembayaran = ['COD', 'BSI', 'SHOPEEPAY', 'GOPAY'];
  List<String> selectedMetode = [];
  String? selectedCategoryId;
  String searchQuery = "";
  int currentPage = 1;
  int itemsPerPage = 10;
  bool isLoading = true;

  Map<int, bool> expandedDescriptions = {};

  String _getFirstNWords(String text, int n) {
    if (text.isEmpty) return '-';
    List<String> words = text.split(' ');
    if (words.length <= n) return text;
    return words.take(n).join(' ') + '...';
  }

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchCategories();
  }

  Future<void> _fetchProducts() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('products')
          .select('*, categories(name), photo_items(name)')
          .order('created_at', ascending: false);

      setState(() {
        produkList = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching products: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProductImages(int productId) async {
    try {
      final response = await supabase
          .from('photo_items')
          .select()
          .eq('product_id', productId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching product images: $e')),
      );
      return [];
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select()
          .order('name', ascending: true);

      setState(() {
        categoriesList = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching categories: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get filteredProduk {
    return produkList
        .where((produk) => produk['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  List<Map<String, dynamic>> get paginatedProduk {
    int startIndex = (currentPage - 1) * itemsPerPage;
    int endIndex = startIndex + itemsPerPage;
    return filteredProduk.sublist(
        startIndex, endIndex.clamp(0, filteredProduk.length));
  }

  String _formatPaymentMethods(dynamic payments) {
    if (payments == null) return '-';
    
    if (payments is String) {
      try {
        payments = payments.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',');
      } catch (e) {
        return payments;
      }
    }
    
    if (payments is List) {
      if (payments.isEmpty) return '-';
      if (payments.length == 1) return payments.first.toString();
      return '${payments.sublist(0, payments.length - 1).join(', ')} dan ${payments.last}';
    }
    
    return payments.toString();
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void _showProdukModal({Map<String, dynamic>? produk}) {
    // Form controllers
    final nameController = TextEditingController(text: produk?['name'] ?? '');
    final descController = TextEditingController(text: produk?['desc'] ?? '');
    final priceOriController = TextEditingController(
      text: produk?['price_ori'] != null ? _formatNumber(produk!['price_ori']) : ''
    );
    final stockController = TextEditingController(
      text: produk?['stock'] != null ? _formatNumber(produk!['stock']) : ''
    );
    final diskonController = TextEditingController(
      text: produk?['diskon']?.toString() ?? '0'
    );
    final priceDisplayController = TextEditingController(
      text: produk?['price_display'] != null ? _formatNumber(produk!['price_display']) : ''
    );
    final weightController = TextEditingController(
      text: produk?['weight']?.toString() ?? '0'
    );
    
    // Image handling state
    final List<Map<String, dynamic>> _uploadedImages = [];
    final PageController _pageController = PageController();
    bool _isUploadingImage = false;
    bool _isLoadingImages = produk != null;
    int _currentImageIndex = 0;
    
    // Payment methods
    selectedMetode = [];
    if (produk?['payment'] != null) {
      if (produk!['payment'] is List) {
        selectedMetode = List<String>.from(produk!['payment'].map((e) => e.toString()));
      } else if (produk!['payment'] is String) {
        try {
          String paymentStr = produk!['payment'].replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
          selectedMetode = paymentStr.split(',').map((e) => e.trim()).toList();
        } catch (e) {
          selectedMetode = [];
        }
      }
    }
    
    selectedCategoryId = produk?['category_id']?.toString();

    // Load existing images if editing
    if (produk != null) {
      _fetchProductImages(produk['id']).then((images) {
        if (mounted) {
          setState(() {
            _uploadedImages.addAll(images.map((img) => {
              'id': img['id'],
              'name': img['name'],
              'preview': supabase.storage.from('picture-products').getPublicUrl(img['name']),
              'isNew': false
            }));
            _isLoadingImages = false;
          });
        }
      });
    }

    void calculatePriceDisplay() {
      if (priceOriController.text.isEmpty || diskonController.text.isEmpty) return;
      
      try {
        String priceText = priceOriController.text.replaceAll('.', '');
        double price = double.parse(priceText);
        double discount = double.parse(diskonController.text);
        double discountedPrice = price - (price * discount / 100);
        priceDisplayController.text = _formatNumber(discountedPrice.toInt());
      } catch (e) {
        priceDisplayController.text = '';
      }
    }

    calculatePriceDisplay();

    Future<void> _pickImage() async {
      if (_uploadedImages.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maksimal 5 gambar telah diupload')),
        );
        return;
      }

      try {
        final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
        uploadInput.multiple = true;
        uploadInput.accept = 'image/png,image/jpeg,image/jpg';
        uploadInput.click();

        uploadInput.onChange.listen((e) async {
          final files = uploadInput.files;
          if (files != null && files.isNotEmpty) {
            for (var file in files) {
              if (_uploadedImages.length >= 5) break;
              
              final reader = html.FileReader();
              
              reader.onLoadEnd.listen((e) {
                if (reader.result != null) {
                  final now = DateTime.now();
                  final formattedDate = DateFormat('yyyy-MM-dd_HHmmss').format(now);
                  final fileExtension = path.extension(file.name);
                  final newFilename = '${formattedDate}_${file.name.replaceAll(fileExtension, '')}$fileExtension';

                  setState(() {
                    _uploadedImages.add({
                      'bytes': reader.result as Uint8List?,
                      'name': newFilename,
                      'originalName': file.name,
                      'preview': reader.result,
                      'isNew': true
                    });
                    // Auto-scroll to the newly added image
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _pageController.animateToPage(
                        _uploadedImages.length - 1,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    });
                  });
                }
              });

              reader.readAsArrayBuffer(file);
            }
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    }

    Future<void> _uploadImages(int productId) async {
      if (_uploadedImages.isEmpty) return;

      setState(() => _isUploadingImage = true);
      
      try {
        // First delete any existing images that were removed
        if (produk != null) {
          final existingImages = await supabase
              .from('photo_items')
              .select('id,name')
              .eq('product_id', productId);
              
          final existingImageIds = existingImages.map((img) => img['id']).toList();
          final currentImageIds = _uploadedImages.where((img) => !img['isNew']).map((img) => img['id']).toList();
          
          // Find images to delete
          final imagesToDelete = existingImages.where((img) => !currentImageIds.contains(img['id'])).toList();
          
          if (imagesToDelete.isNotEmpty) {
            await supabase.storage.from('picture-products')
                .remove(imagesToDelete.map((img) => img['name'] as String).toList());
            await supabase.from('photo_items')
                .delete()
                .inFilter('id', imagesToDelete.map((img) => img['id']).toList());
          }
        }
        
        // Upload new images
        for (var img in _uploadedImages.where((img) => img['isNew'] == true)) {
          await supabase.storage
              .from('picture-products')
              .uploadBinary(
                img['name'],
                img['bytes']!,
                fileOptions: FileOptions(
                  contentType: lookupMimeType(img['originalName']),
                  upsert: true,
                ),
              );

          await supabase.from('photo_items').insert({
            'name': img['name'],
            'product_id': productId,
          });
        }

        setState(() => _isUploadingImage = false);
      } catch (e) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading images: $e')),
        );
      }
    }

    Future<void> _deleteImage(int index) async {
      final image = _uploadedImages[index];
      
      try {
        // If it's a new image, just remove from list
        if (image['isNew'] == true) {
          setState(() {
            _uploadedImages.removeAt(index);
            if (_currentImageIndex >= _uploadedImages.length) {
              _currentImageIndex = _uploadedImages.length - 1;
            }
          });
          return;
        }
        
        // If it's an existing image, delete from storage and database
        await supabase.storage.from('picture-products').remove([image['name']]);
        await supabase.from('photo_items').delete().eq('id', image['id']);
        
        setState(() {
          _uploadedImages.removeAt(index);
          if (_currentImageIndex >= _uploadedImages.length) {
            _currentImageIndex = _uploadedImages.length - 1;
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting image: $e')),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              insetPadding: EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              produk == null ? 'Tambah Produk' : 'Edit Produk',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                            SizedBox(height: 16),
                            
                            // Image section
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey[100],
                              ),
                              padding: EdgeInsets.all(10),
                              child: Column(
                                children: [
                                  if (_isLoadingImages)
                                    Center(child: CircularProgressIndicator())
                                  else if (_uploadedImages.isEmpty)
                                    Container(
                                      height: 150,
                                      alignment: Alignment.center,
                                      child: Text('Belum ada gambar', style: TextStyle(color: Colors.grey)),
                                    )
                                  else
                                    Column(
                                      children: [
                                        // Main carousel preview
                                        Container(
                                          height: 250,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Stack(
                                            children: [
                                              PageView.builder(
                                                itemCount: _uploadedImages.length,
                                                controller: _pageController,
                                                onPageChanged: (index) {
                                                  setState(() {
                                                    _currentImageIndex = index;
                                                  });
                                                },
                                                itemBuilder: (context, index) {
                                                  final image = _uploadedImages[index];
                                                  return ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: image['preview'] is Uint8List
                                                        ? Image.memory(
                                                            image['preview'] as Uint8List,
                                                            fit: BoxFit.contain,
                                                          )
                                                        : Image.network(
                                                            image['preview'] as String,
                                                            fit: BoxFit.contain,
                                                            loadingBuilder: (context, child, loadingProgress) {
                                                              if (loadingProgress == null) return child;
                                                              return Center(
                                                                child: CircularProgressIndicator(
                                                                  value: loadingProgress.expectedTotalBytes != null
                                                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                                      : null,
                                                                ),
                                                              );
                                                            },
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Center(
                                                                child: Icon(Icons.error, color: Colors.red),
                                                              );
                                                            },
                                                          ),
                                                  );
                                                },
                                              ),
                                              Positioned(
                                                bottom: 10,
                                                left: 0,
                                                right: 0,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Gambar ${_currentImageIndex + 1} dari ${_uploadedImages.length}',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        backgroundColor: Colors.black54,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 10,
                                                left: 0,
                                                right: 0,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: List.generate(_uploadedImages.length, (index) {
                                                    return GestureDetector(
                                                      onTap: () {
                                                        _pageController.animateToPage(
                                                          index,
                                                          duration: Duration(milliseconds: 300),
                                                          curve: Curves.easeInOut,
                                                        );
                                                      },
                                                      // child: Container(
                                                      //   margin: EdgeInsets.symmetric(horizontal: 4),
                                                      //   width: 8,
                                                      //   height: 8,
                                                      //   decoration: BoxDecoration(
                                                      //     shape: BoxShape.circle,
                                                      //     color: _currentImageIndex == index
                                                      //         ? Colors.blue 
                                                      //         : Colors.grey,
                                                      //   ),
                                                      // ),
                                                    );
                                                  }),
                                                ),
                                              ),
                                              Positioned(
                                                top: 10,
                                                right: 10,
                                                child: CircleAvatar(
                                                  backgroundColor: Colors.red,
                                                  radius: 15,
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    icon: Icon(Icons.delete, size: 15, color: Colors.white),
                                                    onPressed: () {
                                                      _deleteImage(_currentImageIndex);
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        
                                        // Thumbnail preview
                                        Container(
                                          height: 80,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _uploadedImages.length,
                                            itemBuilder: (context, index) {
                                              final image = _uploadedImages[index];
                                              return GestureDetector(
                                                onTap: () {
                                                  _pageController.animateToPage(
                                                    index,
                                                    duration: Duration(milliseconds: 300),
                                                    curve: Curves.easeInOut,
                                                  );
                                                },
                                                child: Container(
                                                  margin: EdgeInsets.symmetric(horizontal: 5),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: _currentImageIndex == index
                                                          ? Colors.blue 
                                                          : Colors.transparent,
                                                      width: 2,
                                                    ),
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(3),
                                                    child: image['preview'] is Uint8List
                                                        ? Image.memory(
                                                            image['preview'] as Uint8List,
                                                            width: 80,
                                                            height: 80,
                                                            fit: BoxFit.cover,
                                                          )
                                                        : Image.network(
                                                            image['preview'] as String,
                                                            width: 80,
                                                            height: 80,
                                                            fit: BoxFit.cover,
                                                          ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  
                                  SizedBox(height: 10),
                                  
                                  // Add image button
                                  ElevatedButton.icon(
                                    onPressed: _pickImage,
                                    icon: Icon(Icons.add_photo_alternate),
                                    label: Text(
                                      'Tambah Gambar (${_uploadedImages.length}/5)',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 45),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 20),
                            
                            // Form fields
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Nama Produk',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 15),
                            
                            DropdownButtonFormField<String>(
                              value: selectedCategoryId,
                              decoration: InputDecoration(
                                labelText: 'Kategori',
                                border: OutlineInputBorder(),
                              ),
                              items: categoriesList.map((category) {
                                return DropdownMenuItem(
                                  value: category['id'].toString(),
                                  child: Text(category['name']),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => selectedCategoryId = value);
                              },
                            ),
                            SizedBox(height: 15),
                            
                            TextField(
                              controller: descController,
                              decoration: InputDecoration(
                                labelText: 'Deskripsi',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            SizedBox(height: 15),
                            
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: priceOriController,
                                    decoration: InputDecoration(
                                      labelText: 'Harga Asli',
                                      border: OutlineInputBorder(),
                                      prefixText: 'Rp ',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => calculatePriceDisplay(),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: diskonController,
                                    decoration: InputDecoration(
                                      labelText: 'Diskon (%)',
                                      border: OutlineInputBorder(),
                                      suffixText: '%',
                                    ),
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => calculatePriceDisplay(),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 15),
                            
                            TextField(
                              controller: priceDisplayController,
                              decoration: InputDecoration(
                                labelText: 'Harga Setelah Diskon',
                                border: OutlineInputBorder(),
                                prefixText: 'Rp ',
                              ),
                              readOnly: true,
                            ),
                            SizedBox(height: 15),
                            
                            TextField(
                              controller: weightController,
                              decoration: InputDecoration(
                                labelText: 'Berat (dalam gram)',
                                border: OutlineInputBorder(),
                                suffixText: 'gram',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            SizedBox(height: 15),
                            
                            Text(
                              'Metode Pembayaran',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 10),
                            
                            Wrap(
                              spacing: 10,
                              children: metodePembayaran.map((metode) {
                                return CheckboxListTile(
                          title: Text(metode),
                          value: selectedMetode.contains(metode),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedMetode.add(metode);
                              } else {
                                selectedMetode.remove(metode);
                              }
                            });
                          },
                        );
                      }).toList(),
                    )
                  ],
                        ),
                      ),
                      
                      Divider(height: 1),
                      
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Batal', style: TextStyle(color: Colors.red)),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                if (nameController.text.isEmpty ||
                                    priceOriController.text.isEmpty ||
                                    weightController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Nama, harga, dan berat harus diisi')),
                                  );
                                  return;
                                }

                                if (_uploadedImages.length < 3) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Minimal 3 gambar harus diupload')),
                                  );
                                  return;
                                }

                                try {
                                  final productData = {
                                    'name': nameController.text,
                                    'desc': descController.text,
                                    'price_ori': int.parse(priceOriController.text.replaceAll('.', '')),
                                    'stock': int.parse(stockController.text.replaceAll('.', '')),
                                    'diskon': double.parse(diskonController.text),
                                    'price_display': int.parse(priceDisplayController.text.replaceAll('.', '')),
                                    'weight': int.parse(weightController.text),
                                    'payment': selectedMetode,
                                    'category_id': selectedCategoryId != null
                                        ? int.parse(selectedCategoryId!)
                                        : null,
                                    'photos': _uploadedImages.length,
                                  };

                                  if (produk == null) {
                                    final response = await supabase
                                        .from('products')
                                        .insert(productData)
                                        .select()
                                        .single();
                                    
                                    final newProductId = response['id'] as int;
                                    await _uploadImages(newProductId);
                                  } else {
                                    await supabase
                                        .from('products')
                                        .update(productData)
                                        .eq('id', produk['id']);
                                    
                                    await _uploadImages(produk['id']);
                                  }

                                  Navigator.pop(context);
                                  _fetchProducts();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error saving product: $e')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                              child: _isUploadingImage
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text('Simpan'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProduct(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Produk'),
        content: Text('Apakah Anda yakin ingin menghapus produk ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final images = await supabase
            .from('photo_items')
            .select('name')
            .eq('product_id', id);
            
        if (images.isNotEmpty) {
          final imageNames = images.map((img) => img['name'] as String).toList();
          await supabase.storage.from('picture-products').remove(imageNames);
          await supabase.from('photo_items').delete().eq('product_id', id);
        }

        await supabase.from('products').delete().eq('id', id);

        _fetchProducts();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting product: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (filteredProduk.length / itemsPerPage).ceil();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.white],
          ),
        ),
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manajemen Produk',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                ElevatedButton(
                  onPressed: () => _showProdukModal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Tambah Produk',
                      style: TextStyle(color: Color.fromARGB(255, 33, 0, 85))),
                ),
              ],
            ),
            SizedBox(height: 16.0),
            TextField(
              decoration: InputDecoration(
                labelText: 'Cari Produk',
                suffixIcon: Icon(Icons.search, color: Colors.deepPurple),
                filled: true,
                fillColor: Color.fromARGB(255, 244, 244, 252),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  currentPage = 1;
                });
              },
            ),
            SizedBox(height: 10),
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else if (produkList.isEmpty)
              Center(
                child: Text('Tidak ada produk ditemukan',
                    style: TextStyle(fontSize: 18)),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: paginatedProduk.length,
                  itemBuilder: (context, index) {
                    var produk = paginatedProduk[index];
                    final productId = produk['id'];
                    final isExpanded = expandedDescriptions[productId] ?? false;
                    final description = produk['desc'] ?? '-';

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          final images = await _fetchProductImages(productId);
                          if (images.isEmpty) return;
                          
                          final PageController _pageController = PageController();
                          int _currentViewIndex = 0;
                          
                          showDialog(
                            context: context,
                            builder: (context) {
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            produk['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: 300,
                                          width: 300,
                                          child: Stack(
                                            children: [
                                              PageView.builder(
                                                itemCount: images.length,
                                                controller: _pageController,
                                                onPageChanged: (index) {
                                                  setState(() {
                                                    _currentViewIndex = index;
                                                  });
                                                },
                                                itemBuilder: (context, index) {
                                                  final image = images[index];
                                                  return Image.network(
                                                    supabase.storage
                                                        .from('picture-products')
                                                        .getPublicUrl(image['name']),
                                                    fit: BoxFit.contain,
                                                  );
                                                },
                                              ),
                                              Positioned(
                                                bottom: 10,
                                                left: 0,
                                                right: 0,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Gambar ${_currentViewIndex + 1} dari ${images.length}',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        backgroundColor: Colors.black54,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Container(
                                          height: 80,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: images.length,
                                            itemBuilder: (context, index) {
                                              final image = images[index];
                                              return GestureDetector(
                                                onTap: () {
                                                  _pageController.animateToPage(
                                                    index,
                                                    duration: Duration(milliseconds: 300),
                                                    curve: Curves.easeInOut,
                                                  );
                                                },
                                                child: Container(
                                                  margin: EdgeInsets.symmetric(horizontal: 5),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: _currentViewIndex == index
                                                          ? Colors.blue 
                                                          : Colors.transparent,
                                                      width: 2,
                                                    ),
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(3),
                                                    child: Image.network(
                                                      supabase.storage
                                                          .from('picture-products')
                                                          .getPublicUrl(image['name']),
                                                      width: 80,
                                                      height: 80,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        SizedBox(height: 16),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: FutureBuilder<List<Map<String, dynamic>>>(
                            future: supabase
                                .from('photo_items')
                                .select()
                                .eq('product_id', produk['id'])
                                .order('created_at', ascending: true)
                                .limit(1),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                final image = snapshot.data!.first;
                                return Image.network(
                                  supabase.storage
                                      .from('picture-products')
                                      .getPublicUrl(image['name']),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Icon(Icons.image, size: 80);
                            },
                          ),
                          title: Text(
                            produk['name'],
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),
                              Text('Kategori: ${produk['categories']?['name'] ?? '-'}'),
                              SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Deskripsi: '),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(isExpanded ? description : _getFirstNWords(description, 6)),
                                        if (description.split(' ').length > 6)
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                expandedDescriptions[productId] = !isExpanded;
                                              });
                                            },
                                            child: Text(
                                              isExpanded ? 'Sembunyikan' : 'Tampilkan detail',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                  'Harga: Rp ${_formatNumber(produk['price_display'] ?? 0)} (Diskon ${produk['diskon']?.toStringAsFixed(0) ?? '0'}%)'),
                              SizedBox(height: 4),
                              Text('Stok: ${_formatNumber(produk['stock'] ?? 0)}'),
                              SizedBox(height: 4),
                              Text('Berat: ${_formatNumber(produk['weight'] ?? 0)} gram'),
                              SizedBox(height: 4),
                              Text(
                                  'Metode: ${_formatPaymentMethods(produk['payment'])}'),
                              SizedBox(height: 4),
                              Text('Gambar: ${produk['photos'] ?? 0}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showProdukModal(produk: produk),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteProduct(produk['id']),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (!isLoading && produkList.isNotEmpty)
              SizedBox(height: 10),
            if (!isLoading && produkList.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.deepPurple),
                    onPressed: currentPage > 1
                        ? () => setState(() => currentPage--)
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
        ),
      ),
    );
  }
}