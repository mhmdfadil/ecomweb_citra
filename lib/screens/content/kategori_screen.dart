import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KategoriContent extends StatefulWidget {
  const KategoriContent({super.key});

  @override
  State<KategoriContent> createState() => _KategoriContentState();
}

class _KategoriContentState extends State<KategoriContent> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> categoriesList = [];
  String searchQuery = "";
  int currentPage = 1;
  int itemsPerPage = 10;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('categories')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        categoriesList = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching categories: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get filteredCategories {
    return categoriesList
        .where((category) => 
            category['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  List<Map<String, dynamic>> get paginatedCategories {
    int startIndex = (currentPage - 1) * itemsPerPage;
    int endIndex = startIndex + itemsPerPage;
    return filteredCategories.sublist(
        startIndex, endIndex.clamp(0, filteredCategories.length));
  }

  void _showCategoryModal({Map<String, dynamic>? category}) {
    TextEditingController nameController = TextEditingController(
        text: category?['name'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          title: Text(category == null ? 'Tambah Kategori' : 'Edit Kategori',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Nama Kategori'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Nama kategori harus diisi')),
                  );
                  return;
                }

                try {
                  if (category == null) {
                    // Add new category
                    await supabase.from('categories').insert({
                      'name': nameController.text,
                    });
                  } else {
                    // Update existing category
                    await supabase
                        .from('categories')
                        .update({'name': nameController.text})
                        .eq('id', category['id']);
                  }

                  Navigator.pop(context);
                  _fetchCategories();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving category: $e')),
                  );
                }
              },
              child: Text('Simpan', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Kategori'),
        content: Text('Apakah Anda yakin ingin menghapus kategori ini?'),
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
        await supabase.from('categories').delete().eq('id', id);
        _fetchCategories();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting category: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (filteredCategories.length / itemsPerPage).ceil();

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
                  'Kategori Produk',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                ElevatedButton(
                  onPressed: () => _showCategoryModal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Tambah Kategori',
                      style: TextStyle(color: Color.fromARGB(255, 33, 0, 85))),
                ),
              ],
            ),
            SizedBox(height: 16.0),
            TextField(
              decoration: InputDecoration(
                labelText: 'Cari Kategori',
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
            else if (categoriesList.isEmpty)
              Center(
                child: Text('Tidak ada kategori ditemukan',
                    style: TextStyle(fontSize: 18)),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: paginatedCategories.length,
                  itemBuilder: (context, index) {
                    var category = paginatedCategories[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: Icon(Icons.category, size: 50, color: Colors.deepPurple),
                        title: Text(
                          category['name'],
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showCategoryModal(category: category),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCategory(category['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (!isLoading && categoriesList.isNotEmpty)
              SizedBox(height: 10),
            if (!isLoading && categoriesList.isNotEmpty)
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
        ),
      ),
    );
  }
}