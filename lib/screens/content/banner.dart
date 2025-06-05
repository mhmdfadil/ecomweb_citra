import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class BannerEditorScreen extends StatefulWidget {
  const BannerEditorScreen({super.key});

  @override
  State<BannerEditorScreen> createState() => _BannerEditorScreenState();
}

class _BannerEditorScreenState extends State<BannerEditorScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final ImagePicker picker = ImagePicker();
  
  List<Map<String, dynamic>> bannersList = [];
  List<Map<String, dynamic>> activeBannerContents = [];
  Map<String, dynamic>? currentBanner;
  int? selectedContentId;
  
  bool isLoading = true;
  bool isEditing = false;
  bool showFrameBoundaries = true;
  
  // Frame settings
  final Map<String, Map<String, int>> framePresets = {
    'Mobile': {'width': 375, 'height': 600},
    'Desktop': {'width': 1200, 'height': 400},
    'Square': {'width': 600, 'height': 600},
    'Story': {'width': 1080, 'height': 1920},
  };
  
  // UI controls
  double toolbarHeight = 72;
  double propertiesPanelHeight = 320;
  Color pickerColor = const Color(0xff443a49);
  Color currentColor = const Color(0xff443a49);

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('banners')
          .select()
          .order('display_order');
      
      setState(() {
        bannersList = List<Map<String, dynamic>>.from(response);
        if (bannersList.isNotEmpty) {
          currentBanner = bannersList.first;
          _loadBannerContents();
        }
      });
    } catch (e) {
      _showError('Error loading banners: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadBannerContents() async {
    if (currentBanner == null || currentBanner!['id'] == null) return;
    
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('banner_contents')
          .select()
          .eq('banner_id', currentBanner!['id'])
          .order('z_index');
          
      setState(() {
        activeBannerContents = List<Map<String, dynamic>>.from(response);
        selectedContentId = null;
      });
    } catch (e) {
      _showError('Error loading contents: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _createNewBanner() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('banners')
          .insert({
            'title': 'New Banner ${bannersList.length + 1}',
            'display_order': bannersList.length,
            'frame_type': 'Mobile',
            'frame_width': framePresets['Mobile']!['width'],
            'frame_height': framePresets['Mobile']!['height'],
            'is_active': false,
          })
          .select()
          .single();
          
      await _loadBanners();
      setState(() => currentBanner = response);
    } catch (e) {
      _showError('Error creating banner: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateBannerSettings(Map<String, dynamic> updates) async {
    if (currentBanner == null) return;
    
    setState(() => isLoading = true);
    try {
      await supabase
          .from('banners')
          .update(updates)
          .eq('id', currentBanner!['id']);
          
      await _loadBanners();
      // Update current banner with new settings
      currentBanner = {
        ...currentBanner!,
        ...updates,
      };
    } catch (e) {
      _showError('Error updating banner: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _uploadImage() async {
    if (activeBannerContents.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum of 5 images allowed')),
      );
      return;
    }

    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => isLoading = true);
      
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd_HHmmss').format(now);
      final fileExtension = path.extension(image.name);
      final fileName = '${formattedDate}_${image.name.replaceAll(fileExtension, '')}$fileExtension';
      
      // Handle web vs mobile differently
      Uint8List bytes;
      if (kIsWeb) {
        bytes = await image.readAsBytes();
      } else {
        final file = File(image.path);
        bytes = await file.readAsBytes();
      }

      // Show preview immediately
      setState(() {
        activeBannerContents.add({
          'id': -1, // Temporary ID for new items
          'content_type': 'image',
          'content_data': {
            'url': '', // Will be updated after upload
            'fit': 'contain',
            'width': 200,
            'height': 200,
            'preview': bytes, // Store bytes for preview
            'originalName': image.name,
            'fileName': fileName,
            'isNew': true
          },
          'position_x': 100,
          'position_y': 100,
          'rotation': 0,
          'scale': 1,
          'z_index': activeBannerContents.length,
        });
      });

      // Upload to Supabase
      String imageUrl;
      if (kIsWeb) {
        final uploadResponse = await supabase.storage
            .from('picture-products')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: lookupMimeType(image.name),
                upsert: true,
              ),
            );
        
        imageUrl = supabase.storage
            .from('picture-products')
            .getPublicUrl(fileName);
      } else {
        final uploadResponse = await supabase.storage
            .from('picture-products')
            .upload(
              fileName,
              File(image.path),
              fileOptions: FileOptions(
                contentType: lookupMimeType(image.path),
                upsert: true,
              ),
            );
        
        imageUrl = supabase.storage
            .from('picture-products')
            .getPublicUrl(fileName);
      }

      // Update the content with the actual URL
      final newContentId = await supabase.from('banner_contents')
          .insert({
            'banner_id': currentBanner!['id'],
            'content_type': 'image',
            'content_data': {
              'url': imageUrl,
              'fit': 'contain',
              'width': 200,
              'height': 200,
            },
            'position_x': 100,
            'position_y': 100,
            'rotation': 0,
            'scale': 1,
            'z_index': activeBannerContents.length - 1,
          })
          .select('id')
          .single()
          .then((value) => value['id'] as int);

      // Update local state with the actual ID
      setState(() {
        final index = activeBannerContents.indexWhere((c) => c['id'] == -1);
        if (index != -1) {
          activeBannerContents[index]['id'] = newContentId;
          activeBannerContents[index]['content_data']['url'] = imageUrl;
          activeBannerContents[index]['content_data'].remove('preview');
          activeBannerContents[index]['content_data'].remove('originalName');
          activeBannerContents[index]['content_data'].remove('isNew');
        }
      });

    } catch (e) {
      _showError('Error uploading image: $e');
      // Remove the failed upload from the list
      setState(() {
        activeBannerContents.removeWhere((c) => c['id'] == -1);
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addContent(String type, [Map<String, dynamic>? initialData]) async {
    if (currentBanner == null) return;
    
    setState(() => isLoading = true);
    try {
      final defaultData = {
        'image': {
          'url': '',
          'fit': 'contain',
          'width': 200,
          'height': 200,
        },
        'text': {
          'text': 'Double tap to edit',
          'color': '#000000',
          'fontSize': 16,
          'fontFamily': 'Roboto',
          'fontWeight': 'normal',
          'align': 'left',
          'width': 200,
        },
        'shape': {
          'type': 'rectangle',
          'color': '#4285F4',
          'width': 100,
          'height': 100,
          'borderRadius': 0,
        }
      };
      
      final contentData = initialData ?? defaultData[type];
      
      // Center the new content in the frame
      final frameWidth = currentBanner!['frame_width'] ?? 375;
      final frameHeight = currentBanner!['frame_height'] ?? 600;
      
      await supabase.from('banner_contents').insert({
        'banner_id': currentBanner!['id'],
        'content_type': type,
        'content_data': contentData,
        'position_x': (frameWidth / 2) - ((contentData!['width'] ?? 100) / 2),
        'position_y': (frameHeight / 2) - ((contentData['height'] ?? 100) / 2),
        'z_index': activeBannerContents.length,
      });
      
      await _loadBannerContents();
    } catch (e) {
      _showError('Error adding content: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateContent(int contentId, Map<String, dynamic> updates) async {
    try {
      await supabase
          .from('banner_contents')
          .update(updates)
          .eq('id', contentId);
          
      // Update local state for immediate feedback
      setState(() {
        final index = activeBannerContents.indexWhere((c) => c['id'] == contentId);
        if (index != -1) {
          activeBannerContents[index] = {
            ...activeBannerContents[index],
            ...updates,
          };
        }
      });
    } catch (e) {
      _showError('Error updating content: $e');
    }
  }

  Future<void> _deleteContent(int contentId) async {
    setState(() => isLoading = true);
    try {
      await supabase.from('banner_contents').delete().eq('id', contentId);
      await _loadBannerContents();
    } catch (e) {
      _showError('Error deleting content: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _changeFramePreset(String preset) {
    if (currentBanner == null) return;
    
    final dimensions = framePresets[preset];
    if (dimensions == null) return;
    
    _updateBannerSettings({
      'frame_type': preset,
      'frame_width': dimensions['width'],
      'frame_height': dimensions['height'],
    });
  }

  void _changeColor(Color color) {
    if (selectedContentId == null) return;
    
    final content = activeBannerContents.firstWhere(
      (c) => c['id'] == selectedContentId,
      orElse: () => {},
    );
    if (content.isEmpty) return;
    
    final contentData = Map<String, dynamic>.from(content['content_data']);
    contentData['color'] = '#${color.value.toRadixString(16).substring(2)}';
    
    _updateContent(selectedContentId!, {
      'content_data': contentData,
    });
  }

  Widget _buildContentItem(Map<String, dynamic> content) {
    final isSelected = selectedContentId == content['id'];
    final contentData = Map<String, dynamic>.from(content['content_data']);
    final positionX = content['position_x'] as double;
    final positionY = content['position_y'] as double;
    final rotation = content['rotation'] as double;
    final scale = content['scale'] as double;
    final zIndex = content['z_index'] as int;
    
    // Calculate dimensions based on content type
    double width = 100;
    double height = 100;
    
    Widget contentWidget;
    switch (content['content_type']) {
      case 'image':
        width = (contentData['width'] as num?)?.toDouble() ?? 200;
        height = (contentData['height'] as num?)?.toDouble() ?? 200;
        
        // If we have a preview (new upload), use that
        if (contentData['preview'] != null) {
          contentWidget = Image.memory(
            contentData['preview'] as Uint8List,
            width: width,
            height: height,
            fit: BoxFit.contain,
          );
        } else {
          contentWidget = Image.network(
            contentData['url'] ?? '',
            width: width,
            height: height,
            fit: BoxFit.values.firstWhere(
              (e) => e.toString().split('.').last == contentData['fit'],
              orElse: () => BoxFit.contain,
            ),
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[200],
              width: width,
              height: height,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          );
        }
        break;
        
      case 'text':
        width = (contentData['width'] as num?)?.toDouble() ?? 200;
        height = (contentData['fontSize'] as num?)?.toDouble() ?? 16 * 1.2;
        
        contentWidget = SizedBox(
          width: width,
          child: Text(
            contentData['text'] ?? '',
            style: TextStyle(
              color: _parseColor(contentData['color']),
              fontSize: (contentData['fontSize'] as num?)?.toDouble(),
              fontFamily: contentData['fontFamily'],
              fontWeight: _parseFontWeight(contentData['fontWeight']),
            ),
            textAlign: _parseTextAlign(contentData['align']),
          ),
        );
        break;
        
      case 'shape':
        width = (contentData['width'] as num?)?.toDouble() ?? 100;
        height = (contentData['height'] as num?)?.toDouble() ?? 100;
        
        contentWidget = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: _parseColor(contentData['color']),
            borderRadius: BorderRadius.circular(
              (contentData['borderRadius'] as num?)?.toDouble() ?? 0,
            ),
          ),
        );
        break;
        
      default:
        contentWidget = Container();
    }
    
    return Positioned(
      left: positionX,
      top: positionY,
      child: GestureDetector(
        onTap: () {
          if (!isEditing) return;
          setState(() => selectedContentId = content['id'] as int);
        },
        onDoubleTap: () {
          if (content['content_type'] == 'text') {
            _showTextEditDialog(content);
          }
        },
        onPanStart: (details) {
          if (!isEditing) return;
          setState(() {
            selectedContentId = content['id'] as int;
          });
        },
        onPanUpdate: (details) {
          if (!isEditing) return;
          final newX = positionX + details.delta.dx;
          final newY = positionY + details.delta.dy;
          _updateContent(content['id'] as int, {
            'position_x': newX,
            'position_y': newY,
          });
        },
        child: Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation * (pi / 180),
            child: Stack(
              children: [
                contentWidget,
                if (isSelected && isEditing)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.8),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 24,
                            color: Colors.blue.withOpacity(0.5),
                            child: const Center(
                              child: Icon(Icons.drag_handle, 
                                color: Colors.white, 
                                size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTextEditDialog(Map<String, dynamic> content) {
    final contentData = Map<String, dynamic>.from(content['content_data']);
    final textController = TextEditingController(text: contentData['text']);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Text',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: textController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelText: 'Text Content',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      contentData['text'] = textController.text;
                      _updateContent(content['id'] as int, {
                        'content_data': contentData,
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Save', 
                      style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrameBoundary() {
    if (currentBanner == null || !showFrameBoundaries) return Container();
    
    final width = (currentBanner!['frame_width'] as num?)?.toDouble() ?? 375;
    final height = (currentBanner!['frame_height'] as num?)?.toDouble() ?? 600;
    
    return Positioned(
      left: (MediaQuery.of(context).size.width - width) / 2,
      top: (MediaQuery.of(context).size.height - toolbarHeight - propertiesPanelHeight - height) / 2 + toolbarHeight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.blueGrey.withOpacity(0.8),
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: _parseColor(currentBanner!['background_color'] ?? '#FFFFFF'),
          ),
        ),
      ),
    );
  }

  Widget _buildContentPropertiesPanel() {
    if (selectedContentId == null || !isEditing) return Container();
    
    final content = activeBannerContents.firstWhere(
      (c) => c['id'] == selectedContentId,
      orElse: () => {},
    );
    if (content.isEmpty) return Container();
    
    final contentData = Map<String, dynamic>.from(content['content_data']);
    final contentType = content['content_type'] as String;
    
    return Container(
      height: propertiesPanelHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit ${contentType.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => selectedContentId = null),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Common properties
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Position & Transform',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberInput(
                            label: 'X Position',
                            value: content['position_x']?.toDouble() ?? 0,
                            onChanged: (value) => _updateContent(content['id'] as int, {
                              'position_x': value,
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberInput(
                            label: 'Y Position',
                            value: content['position_y']?.toDouble() ?? 0,
                            onChanged: (value) => _updateContent(content['id'] as int, {
                              'position_y': value,
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberInput(
                            label: 'Rotation',
                            value: content['rotation']?.toDouble() ?? 0,
                            min: 0,
                            max: 360,
                            onChanged: (value) => _updateContent(content['id'] as int, {
                              'rotation': value,
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberInput(
                            label: 'Scale',
                            value: content['scale']?.toDouble() ?? 1,
                            step: 0.1,
                            min: 0.1,
                            max: 5,
                            onChanged: (value) => _updateContent(content['id'] as int, {
                              'scale': value,
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Content type specific properties
            if (contentType == 'image') ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Image Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload),
                        label: const Text('Change Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _uploadImage,
                      ),
                      const SizedBox(height: 12),
                      if (contentData['url'] != null && contentData['url'].isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            contentData['url'], 
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberInput(
                              label: 'Width',
                              value: (contentData['width'] as num?)?.toDouble() ?? 200,
                              min: 10,
                              onChanged: (value) {
                                contentData['width'] = value;
                                _updateContent(content['id'] as int, {
                                  'content_data': contentData,
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberInput(
                              label: 'Height',
                              value: (contentData['height'] as num?)?.toDouble() ?? 200,
                              min: 10,
                              onChanged: (value) {
                                contentData['height'] = value;
                                _updateContent(content['id'] as int, {
                                  'content_data': contentData,
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: contentData['fit'] ?? 'contain',
                        items: BoxFit.values
                            .map((e) => e.toString().split('.').last)
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            contentData['fit'] = value;
                            _updateContent(content['id'] as int, {
                              'content_data': contentData,
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Image Fit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            if (contentType == 'text') ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Text Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Text Content',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: contentData['text'] ?? '',
                        maxLines: 3,
                        onChanged: (value) {
                          contentData['text'] = value;
                          _updateContent(content['id'] as int, {
                            'content_data': contentData,
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberInput(
                              label: 'Font Size',
                              value: (contentData['fontSize'] as num?)?.toDouble() ?? 16,
                              min: 8,
                              max: 72,
                              onChanged: (value) {
                                contentData['fontSize'] = value;
                                _updateContent(content['id'] as int, {
                                  'content_data': contentData,
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberInput(
                              label: 'Width',
                              value: (contentData['width'] as num?)?.toDouble() ?? 200,
                              min: 50,
                              onChanged: (value) {
                                contentData['width'] = value;
                                _updateContent(content['id'] as int, {
                                  'content_data': contentData,
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: contentData['fontFamily'] ?? 'Roboto',
                              items: ['Roboto', 'Arial', 'Times New Roman', 'Courier New']
                                  .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  contentData['fontFamily'] = value;
                                  _updateContent(content['id'] as int, {
                                    'content_data': contentData,
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Font',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: contentData['fontWeight'] ?? 'normal',
                              items: ['normal', 'bold', 'w100', 'w200', 'w300', 'w400', 'w500', 'w600', 'w700', 'w800', 'w900']
                                  .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  contentData['fontWeight'] = value;
                                  _updateContent(content['id'] as int, {
                                    'content_data': contentData,
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Weight',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: contentData['align'] ?? 'left',
                        items: ['left', 'center', 'right', 'justify']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            contentData['align'] = value;
                            _updateContent(content['id'] as int, {
                              'content_data': contentData,
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Alignment',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildColorPicker(contentData),
                    ],
                  ),
                ),
              ),
            ],
            
            if (contentType == 'shape') ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shape Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: contentData['type'] ?? 'rectangle',
                        items: ['rectangle', 'circle', 'triangle']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            contentData['type'] = value;
                            _updateContent(content['id'] as int, {
                              'content_data': contentData,
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Shape Type',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberInput(
                              label: 'Width',
                              value: (contentData['width'] as num?)?.toDouble() ?? 100,
                              min: 10,
                              onChanged: (value) {
                                contentData['width'] = value;
                                _updateContent(content['id'] as int, {
                                  'content_data': contentData,
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberInput(
                              label: 'Height',
                              value: (contentData['height'] as num?)?.toDouble() ?? 100,
                              min: 10,
                              onChanged: (value) {
                                contentData['height'] = value;
                                _updateContent(content['id'] as int, {
                                  'content_data': contentData,
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (contentData['type'] == 'rectangle') ...[
                        const SizedBox(height: 12),
                        _buildNumberInput(
                          label: 'Border Radius',
                          value: (contentData['borderRadius'] as num?)?.toDouble() ?? 0,
                          min: 0,
                          onChanged: (value) {
                            contentData['borderRadius'] = value;
                            _updateContent(content['id'] as int, {
                              'content_data': contentData,
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildColorPicker(contentData),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _deleteContent(content['id'] as int),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: 'Bring Forward',
                      onPressed: () {
                        final newZIndex = (content['z_index'] as int) + 1;
                        _updateContent(content['id'] as int, {
                          'z_index': newZIndex,
                        });
                        _loadBannerContents();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      tooltip: 'Send Backward',
                      onPressed: () {
                        final newZIndex = max(0, (content['z_index'] as int) - 1);
                        _updateContent(content['id'] as int, {
                          'z_index': newZIndex,
                        });
                        _loadBannerContents();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required double value,
    double? min,
    double? max,
    double step = 1,
    required Function(double) onChanged,
  }) {
    final controller = TextEditingController(text: value.toStringAsFixed(step < 1 ? 1 : 0));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              onPressed: () {
                final newValue = max != null ? max : value - step;
                controller.text = newValue.toStringAsFixed(step < 1 ? 1 : 0);
                onChanged(newValue);
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (text) {
                  final newValue = double.tryParse(text) ?? value;
                  onChanged(newValue);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () {
                final newValue = min != null ? min : value + step;
                controller.text = newValue.toStringAsFixed(step < 1 ? 1 : 0);
                onChanged(newValue);
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorPicker(Map<String, dynamic> contentData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Color',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _parseColor(contentData['color'] ?? '#000000'),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  pickerColor = _parseColor(contentData['color'] ?? '#000000');
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Select Color',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ColorPicker(
                              pickerColor: pickerColor,
                              onColorChanged: (color) {
                                setState(() => pickerColor = color);
                              },
                              pickerAreaHeightPercent: 0.5,
                              enableAlpha: false,
                              displayThumbColor: true,
                              portraitOnly: true,
                              pickerAreaBorderRadius: BorderRadius.circular(12),
                              hexInputBar: true,
                              colorPickerWidth: 300,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    _changeColor(pickerColor);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Apply', 
                                    style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Choose Color'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBannerSettingsPanel() {
    if (currentBanner == null) return Container();
    
    return Container(
      height: propertiesPanelHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Banner Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'General',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Banner Title',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: currentBanner!['title'] ?? '',
                      onChanged: (value) {
                        _updateBannerSettings({'title': value});
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Active:'),
                        const SizedBox(width: 8),
                        Switch(
                          value: currentBanner!['is_active'] ?? false,
                          onChanged: (value) {
                            _updateBannerSettings({'is_active': value});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Frame Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: currentBanner!['frame_type'] ?? 'Mobile',
                      items: framePresets.keys.map((String key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(key),
                        );
                      }).toList(),
                      decoration: const InputDecoration(
                        labelText: 'Preset',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          _changeFramePreset(value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberInput(
                            label: 'Width',
                            value: (currentBanner!['frame_width'] as num?)?.toDouble() ?? 375,
                            min: 100,
                            onChanged: (value) {
                              _updateBannerSettings({'frame_width': value.toInt()});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberInput(
                            label: 'Height',
                            value: (currentBanner!['frame_height'] as num?)?.toDouble() ?? 600,
                            min: 100,
                            onChanged: (value) {
                              _updateBannerSettings({'frame_height': value.toInt()});
                            },
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Background',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildColorPicker({
                      'color': currentBanner!['background_color'] ?? '#FFFFFF',
                    }),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show Frame Boundaries'),
                      value: showFrameBoundaries,
                      onChanged: (value) {
                        setState(() => showFrameBoundaries = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.black;
    }
  }

  FontWeight _parseFontWeight(String? weight) {
    switch (weight) {
      case 'bold': return FontWeight.bold;
      case 'normal': return FontWeight.normal;
      case 'w100': return FontWeight.w100;
      case 'w200': return FontWeight.w200;
      case 'w300': return FontWeight.w300;
      case 'w400': return FontWeight.w400;
      case 'w500': return FontWeight.w500;
      case 'w600': return FontWeight.w600;
      case 'w700': return FontWeight.w700;
      case 'w800': return FontWeight.w800;
      case 'w900': return FontWeight.w900;
      default: return FontWeight.normal;
    }
  }

  TextAlign _parseTextAlign(String? align) {
    switch (align) {
      case 'left': return TextAlign.left;
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      case 'justify': return TextAlign.justify;
      default: return TextAlign.left;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameWidth = currentBanner?['frame_width']?.toDouble() ?? 375;
    final frameHeight = currentBanner?['frame_height']?.toDouble() ?? 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banner Editor'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.done : Icons.edit),
            tooltip: isEditing ? 'Exit Edit Mode' : 'Edit Mode',
            onPressed: () {
              setState(() {
                isEditing = !isEditing;
                if (!isEditing) selectedContentId = null;
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Banner selector toolbar
                Container(
                  height: toolbarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: currentBanner?['id'] as int?,
                          items: bannersList
                              .map((banner) => DropdownMenuItem(
                                    value: banner['id'] as int,
                                    child: Text(
                                      banner['title'] as String,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              currentBanner = bannersList.firstWhere(
                                (b) => b['id'] == value,
                                orElse: () => {},
                              );
                              selectedContentId = null;
                            });
                            _loadBannerContents();
                          },
                          underline: Container(),
                          hint: const Text('Select Banner'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'New Banner',
                        onPressed: _createNewBanner,
                      ),
                      const SizedBox(width: 8),
                      if (isEditing)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image),
                              tooltip: 'Add Image',
                              onPressed: _uploadImage,
                            ),
                            IconButton(
                              icon: const Icon(Icons.text_fields),
                              tooltip: 'Add Text',
                              onPressed: () => _addContent('text'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.shape_line),
                              tooltip: 'Add Shape',
                              onPressed: () => _addContent('shape'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                // Banner editing area
                Expanded(
                  child: Container(
                    color: Colors.grey[100],
                    child: Center(
                      child: InteractiveViewer(
                        boundaryMargin: const EdgeInsets.all(100),
                        minScale: 0.1,
                        maxScale: 4.0,
                        child: Stack(
                          children: [
                            // Frame boundary
                            _buildFrameBoundary(),
                            
                            // Banner contents
                            Container(
                              width: frameWidth,
                              height: frameHeight,
                              decoration: BoxDecoration(
                                color: _parseColor(
                                  currentBanner?['background_color'] ?? '#FFFFFF'),
                              ),
                              child: Stack(
                                children: activeBannerContents
                                    .map(_buildContentItem)
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Properties panel
                if (isEditing && selectedContentId != null)
                  _buildContentPropertiesPanel()
                else if (isEditing)
                  _buildBannerSettingsPanel(),
              ],
            ),
    );
  }
  
  File(String path) {}
}