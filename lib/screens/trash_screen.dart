// lib/screens/trash_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/photo_sorter_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class TrashScreen extends StatefulWidget {
  static const routeName = '/trash';

  const TrashScreen({Key? key}) : super(key: key);

  @override
  _TrashScreenState createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedPhotos = {};
  List<AssetEntity> _trashedPhotos = [];
  bool _isLoading = true;
  final Map<String, Uint8List?> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _loadTrashedPhotos();
  }

  Future<void> _loadTrashedPhotos() async {
    setState(() {
      _isLoading = true;
    });

    final sorter = context.read<PhotoSorterModel>();
    if (sorter.totalCount == 0) {
      await sorter.loadAllImages(); // Ensure images are loaded
    }
    _trashedPhotos = await sorter.getDiscardedPhotos();
    _trashedPhotos = await sorter.getDiscardedPhotos();

    // Preload thumbnails for better performance
    await _preloadThumbnails();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _preloadThumbnails() async {
    final futures = _trashedPhotos.take(20).map((asset) async {
      try {
        final thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(300, 300),
        );
        _thumbnailCache[asset.id] = thumbnail;
      } catch (e) {
        print('Error loading thumbnail for ${asset.id}: $e');
        _thumbnailCache[asset.id] = null;
      }
    });

    await Future.wait(futures);
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPhotos.clear();
      }
    });
  }

  void _togglePhotoSelection(String photoId) {
    setState(() {
      if (_selectedPhotos.contains(photoId)) {
        _selectedPhotos.remove(photoId);
      } else {
        _selectedPhotos.add(photoId);
      }

      // Exit selection mode if no photos are selected
      if (_selectedPhotos.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedPhotos.length == _trashedPhotos.length) {
        // If all are selected, deselect all
        _selectedPhotos.clear();
        _isSelectionMode = false;
      } else {
        // Select all
        _selectedPhotos.clear();
        _selectedPhotos.addAll(_trashedPhotos.map((photo) => photo.id));
      }
    });
  }

  Future<void> _recoverSelectedPhotos() async {
    if (_selectedPhotos.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog(
      title: 'Recover Photos',
      message:
          'Recover ${_selectedPhotos.length} photo(s) from trash? They will be available for sorting again.',
      confirmText: 'Recover',
      confirmColor: Colors.green,
    );

    if (!confirmed) return;

    final sorter = context.read<PhotoSorterModel>();
    final photosToRecover = _trashedPhotos
        .where((photo) => _selectedPhotos.contains(photo.id))
        .toList();

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      // Recover photos one by one
      for (final photo in photosToRecover) {
        await sorter.recoverFromTrash(photo);
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${photosToRecover.length} photo(s) recovered successfully!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh the trash view
      await _loadTrashedPhotos();

      // Exit selection mode
      setState(() {
        _isSelectionMode = false;
        _selectedPhotos.clear();
      });
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recovering photos: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteSelectedPhotosPermanently() async {
    if (_selectedPhotos.isEmpty) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Delete Permanently',
      message:
          'Permanently delete ${_selectedPhotos.length} photo(s)? This action cannot be undone.',
      confirmText: 'Delete Forever',
      confirmColor: Colors.red,
    );

    if (!confirmed) return;

    final photosToDelete = _trashedPhotos
        .where((photo) => _selectedPhotos.contains(photo.id))
        .toList();

    if (Platform.isAndroid) {
      await _deletePhotosAndroidDirect(photosToDelete);
    } else {
      await _deletePhotosIOSFallback(photosToDelete);
    }
  }

  // Android: Use platform channel to delete via MediaStore directly
  Future<void> _deletePhotosAndroidDirect(
    List<AssetEntity> photosToDelete,
  ) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: Colors.black87,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Deleting photos...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );

      // Create platform channel
      const platform = MethodChannel('com.example.quick_photo_sorter/deletion');

      // Get photo file paths instead of IDs (more reliable)
      final List<Map<String, String>> photoData = [];
      for (final photo in photosToDelete) {
        final file = await photo.file;
        if (file != null) {
          photoData.add({'id': photo.id, 'path': file.path});
        }
      }

      if (photoData.isEmpty) {
        Navigator.of(context).pop();
        _showError('No valid photos found to delete');
        return;
      }

      // Call native Android deletion
      final result = await platform.invokeMethod('deletePhotos', {
        'photos': photoData,
      });

      Navigator.of(context).pop();

      if (result['success'] == true) {
        final deletedCount = result['deletedCount'] as int;

        // Remove from our model
        final sorter = context.read<PhotoSorterModel>();
        for (final photo in photosToDelete) {
          await sorter.removeFromTrashPermanently(photo);
        }

        _showSuccess('$deletedCount photo(s) deleted successfully!');
        await _refreshAfterDeletion();
      } else {
        final error = result['error'] as String? ?? 'Unknown error';
        _showErrorWithFallback('Deletion failed: $error');
      }
    } catch (e) {
      Navigator.of(context).pop();
      if (e is PlatformException) {
        if (e.code == 'PERMISSION_DENIED') {
          _showPermissionError();
        } else {
          _showErrorWithFallback('Platform error: ${e.message}');
        }
      } else {
        _showErrorWithFallback('Error: $e');
      }
    }
  }

  // iOS: Fallback to system deletion (since iOS is more restrictive)
  Future<void> _deletePhotosIOSFallback(
    List<AssetEntity> photosToDelete,
  ) async {
    // For iOS, redirect to Photos app since deletion is very restricted
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Use Photos App',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'iOS requires deletion through the Photos app. We\'ll open it for you.\n\n'
          'Photos to delete: ${photosToDelete.length}',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openPhotosApp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Open Photos',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for better UX
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorWithFallback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Use Gallery',
          textColor: Colors.white,
          onPressed: _openGalleryApp,
        ),
      ),
    );
  }

  void _showPermissionError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Permission Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This app needs permission to delete photos. Please:\n\n'
          '1. Grant storage permission\n'
          '2. Allow "Modify or delete contents"\n'
          '3. Try deletion again',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Open Settings',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAfterDeletion() async {
    await _loadTrashedPhotos();
    setState(() {
      _isSelectionMode = false;
      _selectedPhotos.clear();
    });
  }

  Future<void> _openGalleryApp() async {
    try {
      if (Platform.isAndroid) {
        await launchUrl(Uri.parse('content://media/external/images/media'));
      } else {
        await _openPhotosApp();
      }
    } catch (e) {
      _showError('Could not open gallery app');
    }
  }

  Future<void> _openPhotosApp() async {
    try {
      await launchUrl(Uri.parse('photos-redirect://'));
    } catch (e) {
      _showError('Could not open Photos app');
    }
  }

  Future<void> _openAppSettings() async {
    try {
      if (Platform.isAndroid) {
        await launchUrl(Uri.parse('package:com.example.quick_photo_sorter'));
      } else {
        await launchUrl(Uri.parse('app-settings:'));
      }
    } catch (e) {
      _showError('Could not open app settings');
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _openPhotoViewer(AssetEntity photo, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          photos: _trashedPhotos,
          initialIndex: index,
          onSelectionChanged: _isSelectionMode ? _togglePhotoSelection : null,
          selectedPhotos: _selectedPhotos,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isSelectionMode
              ? '${_selectedPhotos.length} selected'
              : 'Trash (${_trashedPhotos.length})',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_trashedPhotos.isNotEmpty && !_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
          if (_isSelectionMode)
            IconButton(
              icon: Icon(
                _selectedPhotos.length == _trashedPhotos.length
                    ? Icons.deselect
                    : Icons.select_all,
                color: Colors.white,
              ),
              onPressed: _selectAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _trashedPhotos.isEmpty
          ? _buildEmptyTrashView()
          : _buildPhotoGrid(),
      bottomNavigationBar: _isSelectionMode && _selectedPhotos.isNotEmpty
          ? _buildActionBottomBar()
          : null,
    );
  }

  Widget _buildEmptyTrashView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 20),
          Text(
            'Trash is Empty',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Discarded photos will appear here',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: _trashedPhotos.length,
      itemBuilder: (context, index) {
        final photo = _trashedPhotos[index];
        final isSelected = _selectedPhotos.contains(photo.id);

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              _togglePhotoSelection(photo.id);
            } else {
              _openPhotoViewer(photo, index);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedPhotos.add(photo.id);
              });
            }
          },
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Colors.blue, width: 3)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildThumbnail(photo),
                ),
              ),
              if (_isSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(AssetEntity photo) {
    if (_thumbnailCache.containsKey(photo.id) &&
        _thumbnailCache[photo.id] != null) {
      return Image.memory(
        _thumbnailCache[photo.id]!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: photo.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[800],
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            color: Colors.grey[800],
            child: const Icon(
              Icons.error_outline,
              color: Colors.white54,
              size: 32,
            ),
          );
        }

        // Cache the thumbnail
        _thumbnailCache[photo.id] = snapshot.data!;

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }

  Widget _buildActionBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _recoverSelectedPhotos,
              icon: const Icon(Icons.restore, color: Colors.white),
              label: const Text(
                'Recover',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _deleteSelectedPhotosPermanently,
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: const Text(
                'Delete Forever',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Photo Viewer Screen for full-screen photo viewing
class PhotoViewerScreen extends StatefulWidget {
  final List<AssetEntity> photos;
  final int initialIndex;
  final Function(String)? onSelectionChanged;
  final Set<String> selectedPhotos;

  const PhotoViewerScreen({
    Key? key,
    required this.photos,
    required this.initialIndex,
    this.onSelectionChanged,
    required this.selectedPhotos,
  }) : super(key: key);

  @override
  _PhotoViewerScreenState createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleAppBar() {
    setState(() {
      _showAppBar = !_showAppBar;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showAppBar
          ? AppBar(
              backgroundColor: Colors.black54,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                '${_currentIndex + 1} of ${widget.photos.length}',
                style: const TextStyle(color: Colors.white),
              ),
              actions: widget.onSelectionChanged != null
                  ? [
                      IconButton(
                        icon: Icon(
                          widget.selectedPhotos.contains(
                                widget.photos[_currentIndex].id,
                              )
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          widget.onSelectionChanged!(
                            widget.photos[_currentIndex].id,
                          );
                          setState(() {}); // Refresh to show selection state
                        },
                      ),
                    ]
                  : null,
            )
          : null,
      body: GestureDetector(
        onTap: _toggleAppBar,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.photos.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return Center(
              child: FutureBuilder<Uint8List?>(
                future: widget.photos[index].originBytes,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator(color: Colors.white);
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Icon(
                      Icons.error_outline,
                      color: Colors.white54,
                      size: 64,
                    );
                  }

                  return InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
