// lib/services/photo_sorter_model.dart

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

/// Defines which mode the user has chosen.
enum SortMode { all, byDate, cluster }

/// A ChangeNotifier that holds all the state and logic
/// for loading, filtering, and swiping photos.
class PhotoSorterModel extends ChangeNotifier {
  // ─── Private storage ────────────────────────────────────────────────
  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  /// All images in the gallery (loaded once).
  List<AssetEntity> _allImages = [];

  /// The current list the user is swiping through.
  List<AssetEntity> _workingList = [];

  /// Keeps track of the last-swiped asset & whether it was kept.
  AssetEntity? _lastActionAsset;
  bool _lastActionKept = false;

  /// Cache for processed photo IDs to avoid repeated disk reads
  Set<String>? _cachedProcessedIds;

  // ─── Persistent storage keys ────────────────────────────────────────

  static const String _keptPhotosKey = 'kept_photos';
  static const String _discardedPhotosKey = 'discarded_photos';
  static const String _processedPhotosKey = 'processed_photos';

  // ─── Public state ─────────────────────────────────────────────────

  /// Photos the user chose to keep.
  final List<AssetEntity> kept = [];

  /// Photos the user chose to discard.
  final List<AssetEntity> discarded = [];

  /// Which mode is active.
  SortMode mode = SortMode.all;

  /// The date selected in by‑date mode.
  DateTime? selectedDate;

  /// The "seed" photo selected in cluster mode.
  AssetEntity? seedPhoto;

  // ─── Initialization & Loading ─────────────────────────────────────

  /// Simple cache for thumbnails by asset ID
  final Map<String, Uint8List?> thumbnailCache = {};

  /// Call this once at app start to request permissions and load images.
  Future<void> loadAllImages() async {
    if (_isInitializing) return; // Prevent re-entrance
    _isInitializing = true;
    notifyListeners();
    final res = await PhotoManager.requestPermissionExtend();
    if (!res.isAuth) return;

    final path = (await PhotoManager.getAssetPathList(onlyAll: true)).first;
    _allImages = await path.getAssetListRange(start: 0, end: 9999);

    // Load persistent data and filter processed photos
    await _loadPersistedData();
    await _filterProcessedPhotos();

    // PRELOAD thumbnails for a snappier first few swipes
    await cacheThumbnails(count: 50);
    _isInitializing = false;
    notifyListeners();
  }

  /// Initialize the photo sorter with persistence (alternative to loadAllImages)
  Future<void> initialize() async {
    await loadAllImages();
  }

  /// After loading _allImages, call this to preload the first [count] thumbnails
  Future<void> cacheThumbnails({int count = 20}) async {
    final imagesToCache = _workingList.take(count).toList();
    final thumbs = await Future.wait(
      imagesToCache.map((asset) async {
        final data = await asset.thumbnailDataWithSize(
          ThumbnailSize(1080, 1920),
        );
        return MapEntry(asset.id, data);
      }),
    );
    thumbnailCache.addEntries(thumbs);
  }

  // ─── Persistence Methods ───────────────────────────────────────────

  /// Load persisted data from SharedPreferences
  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load kept photos IDs
      final keptIds = prefs.getStringList(_keptPhotosKey) ?? [];
      kept.clear();
      kept.addAll(_allImages.where((asset) => keptIds.contains(asset.id)));

      // Load discarded photos IDs
      final discardedIds = prefs.getStringList(_discardedPhotosKey) ?? [];
      discarded.clear();
      discarded.addAll(
        _allImages.where((asset) => discardedIds.contains(asset.id)),
      );

      print(
        'Loaded ${kept.length} kept photos and ${discarded.length} discarded photos from storage',
      );
    } catch (e) {
      print('Error loading persisted data: $e');
    }
  }

  /// Filter out already processed photos from working list (OPTIMIZED)
  Future<void> _filterProcessedPhotos() async {
    // Only read from disk if cache is empty
    if (_cachedProcessedIds == null) {
      final prefs = await SharedPreferences.getInstance();
      final processedIds = prefs.getStringList(_processedPhotosKey) ?? [];
      _cachedProcessedIds = Set.from(
        processedIds,
      ); // Convert to Set for faster lookups
    }

    _workingList = _allImages.where((photo) {
      return !_cachedProcessedIds!.contains(photo.id);
    }).toList();

    print('Total photos: ${_allImages.length}');
    print('Already processed: ${_cachedProcessedIds!.length}');
    print('Remaining to sort: ${_workingList.length}');
  }

  /// Save photo decision to persistent storage
  Future<void> _savePhotoDecision(String photoId, bool kept) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (kept) {
        final keptIds = prefs.getStringList(_keptPhotosKey) ?? [];
        if (!keptIds.contains(photoId)) {
          keptIds.add(photoId);
          await prefs.setStringList(_keptPhotosKey, keptIds);
        }
      } else {
        final discardedIds = prefs.getStringList(_discardedPhotosKey) ?? [];
        if (!discardedIds.contains(photoId)) {
          discardedIds.add(photoId);
          await prefs.setStringList(_discardedPhotosKey, discardedIds);
        }
      }
    } catch (e) {
      print('Error saving photo decision: $e');
    }
  }

  /// Remove photo decision from persistent storage (for undo)
  Future<void> _removePhotoDecision(String photoId, bool wasKept) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (wasKept) {
        final keptIds = prefs.getStringList(_keptPhotosKey) ?? [];
        keptIds.remove(photoId);
        await prefs.setStringList(_keptPhotosKey, keptIds);
      } else {
        final discardedIds = prefs.getStringList(_discardedPhotosKey) ?? [];
        discardedIds.remove(photoId);
        await prefs.setStringList(_discardedPhotosKey, discardedIds);
      }
    } catch (e) {
      print('Error removing photo decision: $e');
    }
  }

  /// Mark photo as processed (OPTIMIZED)
  Future<void> _markAsProcessed(String photoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final processedIds = prefs.getStringList(_processedPhotosKey) ?? [];

      if (!processedIds.contains(photoId)) {
        processedIds.add(photoId);
        await prefs.setStringList(_processedPhotosKey, processedIds);

        // Update cache
        _cachedProcessedIds?.add(photoId);
      }
    } catch (e) {
      print('Error marking photo as processed: $e');
    }
  }

  /// Unmark photo as processed (for undo) (OPTIMIZED)
  Future<void> _unmarkAsProcessed(String photoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final processedIds = prefs.getStringList(_processedPhotosKey) ?? [];

      processedIds.remove(photoId);
      await prefs.setStringList(_processedPhotosKey, processedIds);

      // Update cache
      _cachedProcessedIds?.remove(photoId);
    } catch (e) {
      print('Error unmarking photo as processed: $e');
    }
  }

  // ─── Mode Selection ────────────────────────────────────────────────

  /// Mode 1: straight swipe all images (but filter processed photos) (OPTIMIZED)
  Future<void> useAll() async {
    mode = SortMode.all;
    await _filterProcessedPhotos(); // Now much faster due to caching
    _resetResults();
    notifyListeners();
  }

  /// Mode 2: filter by exact date (year/month/day) and exclude processed (OPTIMIZED)
  Future<void> filterByDate(DateTime date) async {
    mode = SortMode.byDate;
    selectedDate = date;

    // First filter by date
    final dateFiltered = _allImages.where((asset) {
      final d = asset.createDateTime;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();

    // Then filter out processed photos using cache
    if (_cachedProcessedIds == null) {
      final prefs = await SharedPreferences.getInstance();
      final processedIds = prefs.getStringList(_processedPhotosKey) ?? [];
      _cachedProcessedIds = Set.from(processedIds);
    }

    _workingList = dateFiltered.where((photo) {
      return !_cachedProcessedIds!.contains(photo.id);
    }).toList();

    _resetResults();
    notifyListeners();
  }

  /// Mode 3: cluster ±30min around the seed photo and exclude processed (OPTIMIZED)
  Future<void> clusterAround(AssetEntity seed) async {
    mode = SortMode.cluster;
    seedPhoto = seed;
    final center = seed.createDateTime;

    // First filter by time cluster
    final clusterFiltered = _allImages.where((asset) {
      final diff = asset.createDateTime.difference(center).inMinutes.abs();
      return diff <= 30;
    }).toList();

    // Then filter out processed photos using cache
    if (_cachedProcessedIds == null) {
      final prefs = await SharedPreferences.getInstance();
      final processedIds = prefs.getStringList(_processedPhotosKey) ?? [];
      _cachedProcessedIds = Set.from(processedIds);
    }

    _workingList = clusterFiltered.where((photo) {
      return !_cachedProcessedIds!.contains(photo.id);
    }).toList();

    _resetResults();
    notifyListeners();
  }

  /// Clears kept/discarded lists for a fresh session (but keeps persistence).
  void _resetResults() {
    // Don't clear kept/discarded as they contain persistent data
    _lastActionAsset = null;
  }

  // ─── Swiping Actions ───────────────────────────────────────────────

  /// Keep the current [asset], record action for undo, notify UI.
  Future<void> keep(AssetEntity asset) async {
    if (!kept.contains(asset)) {
      kept.add(asset);
      await _savePhotoDecision(asset.id, true);
      await _markAsProcessed(asset.id);
    }

    _workingList.remove(asset);
    _recordLast(asset, true);
    notifyListeners();
  }

  /// Discard the current [asset], record action for undo, notify UI.
  Future<void> discard(AssetEntity asset) async {
    if (!discarded.contains(asset)) {
      discarded.add(asset);
      await _savePhotoDecision(asset.id, false);
      await _markAsProcessed(asset.id);
    }

    _workingList.remove(asset);
    _recordLast(asset, false);
    notifyListeners();
  }

  /// Record the last swipe action so it can be undone.
  void _recordLast(AssetEntity asset, bool wasKept) {
    _lastActionAsset = asset;
    _lastActionKept = wasKept;
  }

  /// Undo the most recent keep/discard, putting that photo back at front.
  Future<void> undo() async {
    if (_lastActionAsset == null) return;

    final asset = _lastActionAsset!;

    if (_lastActionKept) {
      kept.remove(asset);
      await _removePhotoDecision(asset.id, true);
    } else {
      discarded.remove(asset);
      await _removePhotoDecision(asset.id, false);
    }

    // Add back to working list at the beginning
    _workingList.insert(0, asset);
    await _unmarkAsProcessed(asset.id);

    _lastActionAsset = null;
    notifyListeners();
  }

  // ─── Trash Management Methods ──────────────────────────────────────

  /// Recover a photo from trash back to the working list
  Future<void> recoverFromTrash(AssetEntity asset) async {
    try {
      // Remove from discarded list
      discarded.remove(asset);

      // Remove from persistent storage
      await _removePhotoDecision(asset.id, false);

      // Unmark as processed so it appears in working list
      await _unmarkAsProcessed(asset.id);

      // Add back to working list if it's not already there
      if (!_workingList.contains(asset)) {
        _workingList.insert(0, asset); // Add to front
      }

      notifyListeners();
      print('Photo ${asset.id} recovered from trash');
    } catch (e) {
      print('Error recovering photo from trash: $e');
      rethrow;
    }
  }

  /// Remove a photo from trash records after permanent deletion
  Future<void> removeFromTrashPermanently(AssetEntity asset) async {
    try {
      // Remove from discarded list
      discarded.remove(asset);

      // Remove from all persistent storage
      await _removePhotoDecision(asset.id, false);
      await _unmarkAsProcessed(asset.id);

      // Remove from all images list as it no longer exists
      _allImages.remove(asset);

      notifyListeners();
      print('Photo ${asset.id} permanently removed from records');
    } catch (e) {
      print('Error removing photo from records: $e');
      rethrow;
    }
  }

  /// Empty the entire trash (remove all discarded photos from records)
  Future<void> emptyTrash() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear discarded photos from persistent storage
      await prefs.remove(_discardedPhotosKey);

      // Clear from memory
      discarded.clear();

      notifyListeners();
      print('Trash emptied successfully');
    } catch (e) {
      print('Error emptying trash: $e');
      rethrow;
    }
  }

  // ─── Additional Persistence Methods ────────────────────────────────

  /// Get kept photos by loading from persistent storage
  Future<List<AssetEntity>> getKeptPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keptIds = prefs.getStringList(_keptPhotosKey) ?? [];

      return _allImages.where((photo) => keptIds.contains(photo.id)).toList();
    } catch (e) {
      print('Error getting kept photos: $e');
      return [];
    }
  }

  /// Get discarded photos by loading from persistent storage
  Future<List<AssetEntity>> getDiscardedPhotos() async {
    try {
      // Ensure images are loaded first
      if (_allImages.isEmpty) {
        await loadAllImages();
      }

      final prefs = await SharedPreferences.getInstance();
      final discardedIds = prefs.getStringList(_discardedPhotosKey) ?? [];

      return _allImages
          .where((photo) => discardedIds.contains(photo.id))
          .toList();
    } catch (e) {
      print('Error getting discarded photos: $e');
      return [];
    }
  }

  /// Reset all data (for testing or user reset)
  Future<void> resetAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keptPhotosKey);
      await prefs.remove(_discardedPhotosKey);
      await prefs.remove(_processedPhotosKey);

      kept.clear();
      discarded.clear();
      _lastActionAsset = null;
      _cachedProcessedIds = null; // Clear cache

      // Reload all photos without processed filter
      _workingList = List.from(_allImages);
      notifyListeners();

      print('All data reset successfully');
    } catch (e) {
      print('Error resetting data: $e');
    }
  }

  /// Use a specific list of photos for sorting (for date-based sorting)
  Future<void> usePhotosFromList(List<AssetEntity> photos) async {
    _workingList.clear();

    // Ensure processed photos cache is loaded
    if (_cachedProcessedIds == null) {
      final prefs = await SharedPreferences.getInstance();
      final processedIds = prefs.getStringList(_processedPhotosKey) ?? [];
      _cachedProcessedIds = Set.from(processedIds);
    }

    // Only include photos that are not already processed
    for (final photo in photos) {
      if (!_cachedProcessedIds!.contains(photo.id)) {
        _workingList.add(photo);
      }
    }

    // Shuffle for variety
    _workingList.shuffle();

    // Set mode and reset results
    mode = SortMode.byDate; // or create a new mode for custom lists
    _resetResults();

    notifyListeners();
  }

  /// Get all photos (useful for date grouping)
  List<AssetEntity> getAllPhotos() {
    return List.from(_allImages);
  }

  /// Get statistics
  Map<String, int> getStatistics() {
    return {
      'total': _allImages.length,
      'remaining': _workingList.length,
      'kept': kept.length,
      'discarded': discarded.length,
    };
  }

  /// Check if there are more photos to process
  bool get hasMorePhotos => _workingList.isNotEmpty;

  // ─── Getters ──────────────────────────────────────────────────────

  /// Read‑only view of the current swipe list.
  List<AssetEntity> get workingList => List.unmodifiable(_workingList);

  /// How many remain to swipe.
  int get remainingCount => _workingList.length;

  /// Total images loaded.
  int get totalCount => _allImages.length;
}
