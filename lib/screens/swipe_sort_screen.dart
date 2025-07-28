// lib/screens/swipe_sort_screen.dart

import 'dart:typed_data';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../services/photo_sorter_model.dart';

class SwipeSortScreen extends StatefulWidget {
  static const routeName = '/swipe-sort';
  final String modeName;
  const SwipeSortScreen({Key? key, required this.modeName}) : super(key: key);

  @override
  _SwipeSortScreenState createState() => _SwipeSortScreenState();
}

class _SwipeSortScreenState extends State<SwipeSortScreen>
    with TickerProviderStateMixin {
  late final CardSwiperController _swiperController;
  late final TransformationController _transformationController;
  late final AnimationController _overlayController;
  late final AnimationController _tutorialController;
  late final PageController _pageController;

  bool _collapsed = false;
  bool _showOverlay = true;
  bool _isInitialized = false; // Track initialization state
  bool _showTutorial = false;
  bool _showZoneHighlights = false;
  int _currentIndex = 0;
  List<AssetEntity> _images = [];
  Map<String, Uint8List> _imageCache = {};
  Set<String> _loadingImages = {}; // Track currently loading images
  Timer? _hideTimer;
  Timer? _tutorialTimer;

  @override
  void initState() {
    super.initState();
    _swiperController = CardSwiperController();
    _transformationController = TransformationController();
    _pageController = PageController();
    _overlayController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _tutorialController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _overlayController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePhotos();
    });
  }

  void _initializePhotos() async {
    final sorter = context.read<PhotoSorterModel>();

    // Initialize the model (loads persisted data and filters processed photos)
    await sorter.initialize();

    // Always sync with the model's working list
    _syncWithModel();
    await _preloadImages();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  /// Sync local images with the model's working list
  void _syncWithModel() {
    final sorter = context.read<PhotoSorterModel>();
    _images = List.from(sorter.workingList);

    // Adjust current index if needed
    if (_currentIndex >= _images.length && _images.isNotEmpty) {
      _currentIndex = _images.length - 1;
    } else if (_images.isEmpty) {
      _currentIndex = 0;
    }
  }

  _preloadImages() async {
    // Images are already filtered by PhotoSorterModel.initialize()
    // Just preload the first batch
    final int initialLoadCount = _images.length > 10 ? 10 : _images.length;
    final List<Future<void>> loadTasks = [];

    for (int i = 0; i < initialLoadCount; i++) {
      loadTasks.add(_loadImageAsync(_images[i]));
    }

    // Load images in parallel
    await Future.wait(loadTasks);

    if (mounted) setState(() {});
  }

  Future<void> _loadImageAsync(AssetEntity asset) async {
    if (_imageCache.containsKey(asset.id) ||
        _loadingImages.contains(asset.id)) {
      return;
    }

    _loadingImages.add(asset.id);
    try {
      // Use a more appropriate thumbnail size - smaller for better performance
      final data = await asset.thumbnailDataWithSize(ThumbnailSize(800, 1200));
      if (data != null && mounted) {
        _imageCache[asset.id] = data;
      }
    } catch (e) {
      // Handle loading errors gracefully
      print('Error loading image ${asset.id}: $e');
    } finally {
      _loadingImages.remove(asset.id);
    }
  }

  void _toggleCollapsed() {
    setState(() {
      _collapsed = !_collapsed;
      if (_collapsed) {
        _showOverlay = true;
        _overlayController.forward();
        _startHideTimer();
        // Reset zoom when entering fullscreen
        _transformationController.value = Matrix4.identity();

        // Check if we should show tutorial
        _checkAndShowTutorial();
      } else {
        _showOverlay = true;
        _overlayController.forward();
        _hideTimer?.cancel();
        _tutorialTimer?.cancel();
        _showTutorial = false;
        _showZoneHighlights = false;
      }
    });
  }

  void _checkAndShowTutorial() async {
    // Check if tutorial was shown before (you can use SharedPreferences for persistence)
    // For now, we'll show it every time - you can modify this logic
    final shouldShowTutorial = true; // Replace with SharedPreferences check

    if (shouldShowTutorial) {
      await Future.delayed(Duration(milliseconds: 500)); // Small delay
      if (mounted && _collapsed) {
        _showTutorialDialog();
      }
    }
  }

  void _showTutorialDialog() {
    setState(() {
      _showTutorial = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.touch_app, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'Fullscreen Tutorial',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'In fullscreen mode, you can sort images by tapping on the screen edges:',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap LEFT edge to discard image',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap RIGHT edge to keep image',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'The tap zones will be highlighted briefly to show you where to tap.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startZoneHighlights();
                // TODO: Save "don't show again" preference
              },
              child: Text(
                "Don't show again",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startZoneHighlights();
                setState(() {
                  _showZoneHighlights = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFB57AF2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Got it!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startZoneHighlights() {
    setState(() {
      _showZoneHighlights = true;
      _showTutorial = false;
    });

    _tutorialController.forward();

    // Hide highlights after 3 seconds
    _tutorialTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        _tutorialController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showZoneHighlights = false;
            });
          }
        });
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: 3), () {
      if (_collapsed && mounted) {
        setState(() {
          _showOverlay = false;
        });
        _overlayController.reverse();
      }
    });
  }

  void _onSingleTap() {
    if (_collapsed) {
      setState(() {
        _showOverlay = !_showOverlay;
      });
      if (_showOverlay) {
        _overlayController.forward();
        _startHideTimer();
      } else {
        _overlayController.reverse();
        _hideTimer?.cancel();
      }
    }
  }

  void _onDoubleTap() {
    if (_collapsed) {
      if (_transformationController.value != Matrix4.identity()) {
        // Reset zoom
        _transformationController.value = Matrix4.identity();
      } else {
        // Zoom in
        final double scale = 2.0;
        _transformationController.value = Matrix4.identity()..scale(scale);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB57AF2), Color(0xFF54488f)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Main Content
            !_isInitialized
                ? circularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : _images.isEmpty
                ? _buildNoPhotosView()
                : _collapsed
                ? _buildFullScreenView()
                : SafeArea(
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildActionIcons(),
                        Expanded(child: _buildCardSwipeView()),
                      ],
                    ),
                  ),

            // Overlay controls for collapsed view
            if (_collapsed && _images.isNotEmpty)
              AnimatedBuilder(
                animation: _overlayController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _overlayController.value,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildCollapsedHeader(),
                            Spacer(),
                            _buildCollapsedActionButtons(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              widget.modeName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.undo, color: Colors.white),
            onPressed: () async {
              final sorter = context.read<PhotoSorterModel>();
              if (sorter.kept.isNotEmpty || sorter.discarded.isNotEmpty) {
                await sorter.undo();

                // Sync with model and update UI
                setState(() {
                  _syncWithModel();
                });

                // Use card swiper undo if available
                if (_images.isNotEmpty) {
                  _swiperController.undo();
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.fullscreen, color: Colors.white),
            onPressed: _toggleCollapsed,
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedHeader() {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text(
            widget.modeName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.undo, color: Colors.white),
          onPressed: () async {
            final sorter = context.read<PhotoSorterModel>();
            if (sorter.kept.isNotEmpty || sorter.discarded.isNotEmpty) {
              await sorter.undo();

              setState(() {
                _syncWithModel();
                // Reset zoom when undoing
                _transformationController.value = Matrix4.identity();
              });
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.view_carousel, color: Colors.white),
          onPressed: _toggleCollapsed,
        ),
      ],
    );
  }

  Widget _buildActionIcons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.delete_outline, color: Colors.red, size: 26),
          ),
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.favorite_outline, color: Colors.green, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () async {
            final sorter = context.read<PhotoSorterModel>();
            await sorter.discard(_images[_currentIndex]);
            _removeCurrentImage();
            _startHideTimer();
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.close, color: Colors.white, size: 30),
          ),
        ),
        GestureDetector(
          onTap: () async {
            final sorter = context.read<PhotoSorterModel>();
            await sorter.keep(_images[_currentIndex]);
            _removeCurrentImage();
            _startHideTimer();
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.check, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildNoPhotosView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.white54),
          SizedBox(height: 20),
          Text(
            "All photos sorted!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Great job! You've sorted all your photos.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.home, color: Colors.white),
            label: Text(
              "Back to Home",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
          ),
          SizedBox(height: 20),
          Consumer<PhotoSorterModel>(
            builder: (context, sorter, child) {
              final stats = sorter.getStatistics();
              return Container(
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      "Sorting Summary",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          "Total",
                          stats['total']!,
                          Icons.photo_library,
                        ),
                        _buildStatItem("Kept", stats['kept']!, Icons.favorite),
                        _buildStatItem(
                          "Discarded",
                          stats['discarded']!,
                          Icons.delete,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildCardSwipeView() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CardSwiper(
        controller: _swiperController,
        cardsCount: _images.length,
        cardBuilder: (context, index, horizontalThreshold, verticalThreshold) {
          return _buildPhotoCard(_images[index]);
        },
        duration: Duration(milliseconds: 200),
        initialIndex: _currentIndex,
        isLoop: false,
        maxAngle: 25,
        threshold: 80,
        scale: 0.95,
        numberOfCardsDisplayed: 3,
        allowedSwipeDirection: AllowedSwipeDirection.only(
          left: true,
          right: true,
          up: false,
          down: false,
        ),
        onSwipe: (previousIndex, currentIndex, direction) {
          final asset = _images[previousIndex];
          final sorter = context.read<PhotoSorterModel>();

          if (direction == CardSwiperDirection.left) {
            sorter.discard(asset);
            print(sorter.discarded.length);
          } else if (direction == CardSwiperDirection.right) {
            sorter.keep(asset);
            print(sorter.kept.length);
          }

          // Don't manually remove from _images - let the model handle it
          // The model removes from workingList, we just update our index
          _currentIndex = currentIndex ?? 0;
          _preloadNextImages();

          return true;
        },
        onEnd: () {},
      ),
    );
  }

  Widget _buildFullScreenView() {
    if (_images.isEmpty) return Container();

    return Stack(
      children: [
        // Main content with InteractiveViewer
        InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.0,
          child: GestureDetector(
            onTap: _onSingleTap,
            onDoubleTap: _onDoubleTap,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred background (same as card view)
                  CachedAssetImage(
                    _images[_currentIndex],
                    cache: _imageCache,
                    fit: BoxFit.cover,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.black.withOpacity(0.3)),
                    ),
                  ),
                  // Main image with proper aspect ratio
                  Center(
                    child: CachedAssetImage(
                      _images[_currentIndex],
                      cache: _imageCache,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Left tap zone (discard)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 120,
          child: GestureDetector(
            onTap: () {
              _handleFullScreenSwipe(false);
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Right tap zone (keep)
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 120,
          child: GestureDetector(
            onTap: () {
              _handleFullScreenSwipe(true);
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Tutorial zone highlights
        if (_showZoneHighlights)
          AnimatedBuilder(
            animation: _tutorialController,
            builder: (context, child) {
              return Stack(
                children: [
                  // Left zone highlight (discard)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 120,
                    child: Opacity(
                      opacity: _tutorialController.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.red.withOpacity(0.4),
                              Colors.red.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'DISCARD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Right zone highlight (keep)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 120,
                    child: Opacity(
                      opacity: _tutorialController.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.green.withOpacity(0.4),
                              Colors.green.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'KEEP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  void _handleFullScreenSwipe(bool keep) async {
    if (_images.isEmpty || _currentIndex >= _images.length) return;

    final sorter = context.read<PhotoSorterModel>();
    final currentAsset = _images[_currentIndex];

    // Perform the sorting action
    if (keep) {
      await sorter.keep(currentAsset);
      print('Kept: ${sorter.kept.length}');
    } else {
      await sorter.discard(currentAsset);
      print('Discarded: ${sorter.discarded.length}');
    }

    // Show visual feedback immediately
    _showSwipeFeedback(keep);

    // Remove current image and update the list
    setState(() {
      _images.removeAt(_currentIndex);

      // Stay at same index (which now shows the next image)
      // or adjust if we're at the end
      if (_currentIndex >= _images.length && _images.isNotEmpty) {
        _currentIndex = _images.length - 1;
      }
    });

    // Check if we ran out of images
    if (_images.isEmpty) {
      // No more images - exit fullscreen to show completion view
      setState(() {
        _collapsed = false;
      });
    } else {
      // Reset zoom for the new image
      _transformationController.value = Matrix4.identity();

      // Preload nearby images
      _preloadNextImages();
    }

    // Restart hide timer if overlay is showing
    if (_showOverlay) {
      _startHideTimer();
    }
  }

  void _showSwipeFeedback(bool keep) {
    // Simple feedback - you could enhance this with animations
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(keep ? 'Image kept!' : 'Image discarded!'),
        duration: Duration(milliseconds: 500),
        backgroundColor: keep ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildPhotoCard(AssetEntity asset) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedAssetImage(
                asset,
                cache: _imageCache,
                fit: BoxFit.cover,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.black.withOpacity(0.3)),
                ),
              ),
              Center(
                child: CachedAssetImage(
                  asset,
                  cache: _imageCache,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _preloadNextImages() {
    // Preload more images in both directions for smoother scrolling
    final int preloadCount = 5; // Increase preload count

    // Preload previous images
    for (
      int i = _currentIndex - 2;
      i <= _currentIndex + preloadCount && i < _images.length;
      i++
    ) {
      if (i >= 0 &&
          !_imageCache.containsKey(_images[i].id) &&
          !_loadingImages.contains(_images[i].id)) {
        _loadImageAsync(_images[i]);
      }
    }

    // Clean up cache to prevent memory issues (keep only nearby images)
    _cleanupDistantCache();
  }

  void _cleanupDistantCache() {
    final keysToRemove = <String>[];
    final keepRange = 10; // Keep images within 10 positions of current

    _imageCache.forEach((id, data) {
      final index = _images.indexWhere((asset) => asset.id == id);
      if (index != -1 &&
          (index < _currentIndex - keepRange ||
              index > _currentIndex + keepRange)) {
        keysToRemove.add(id);
      }
    });

    for (final key in keysToRemove) {
      _imageCache.remove(key);
    }
  }

  void _removeCurrentImage() {
    if (_currentIndex < _images.length) {
      setState(() {
        _images.removeAt(_currentIndex);
        if (_currentIndex >= _images.length && _images.isNotEmpty) {
          _currentIndex = _images.length - 1;
        }
      });

      // Update page controller
      if (_images.isNotEmpty && _pageController.hasClients) {
        _pageController.animateToPage(
          _currentIndex,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _transformationController.dispose();
    _overlayController.dispose();
    _tutorialController.dispose();
    _pageController.dispose();
    _hideTimer?.cancel();
    _tutorialTimer?.cancel();
    _imageCache.clear();
    super.dispose();
  }

  Widget circularProgressIndicator({
    required AlwaysStoppedAnimation<Color> valueColor,
  }) {
    return Center(child: CircularProgressIndicator(valueColor: valueColor));
  }
}

/// Cached image widget that uses preloaded data
class CachedAssetImage extends StatelessWidget {
  final AssetEntity asset;
  final Map<String, Uint8List> cache;
  final BoxFit fit;
  final Widget? child;

  const CachedAssetImage(
    this.asset, {
    Key? key,
    required this.cache,
    this.fit = BoxFit.cover,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (cache.containsKey(asset.id)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            cache[asset.id]!,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
          ),
          if (child != null) child!,
        ],
      );
    }

    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(
        ThumbnailSize(800, 1200),
      ), // Smaller size for better performance
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.black12,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            color: Colors.black12,
            child: Center(
              child: Icon(Icons.error_outline, color: Colors.white54, size: 40),
            ),
          );
        }

        cache[asset.id] = snapshot.data!;

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              snapshot.data!,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
            ),
            if (child != null) child!,
          ],
        );
      },
    );
  }
}
