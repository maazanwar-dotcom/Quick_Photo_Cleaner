import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:quick_photo_sorter/screens/swipe_sort_screen.dart';
import 'package:quick_photo_sorter/screens/trash_screen.dart';
import 'package:quick_photo_sorter/screens/date_selection_screen.dart'; // New screen
import 'package:quick_photo_sorter/services/photo_sorter_model.dart';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  final List<Map<String, dynamic>> modes = [
    {
      'title': 'Clean Gallery Mode',
      'subtitle':
          'Swipe to Keep or Delete pictures quickly straight off gallery',
      'image': 'assets/onboarding_mode1.png',
      'mode': 'clean_gallery',
    },
    {
      'title': 'Sweep By Date',
      'subtitle': 'Select a Date and swipe to sort pictures by date',
      'image': 'assets/onboarding_mode3.png',
      'mode': 'sweep_by_date',
    },
    {
      'title': 'After-Event CleanUp Mode',
      'subtitle':
          'Just had an Event and Clicked alot of pictures? Select a picture and Swipe sort the event quickly',
      'image': 'assets/onboarding_mode2.png',
      'mode': 'after_event',
    },
    {
      'title': 'Remove Duplicates',
      'subtitle':
          'Find and remove duplicate photos from your gallery effortlessly with our advanced duplicate detection algorithm.',
      'image': 'assets/onboarding_panel.png',
      'mode': 'remove_duplicates',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB57AF2), Color(0xFF54488f)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedIndex == 0 ? 'Home' : 'Trash',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (selectedIndex ==
                        1) // Show trash count when on trash tab
                      Consumer<PhotoSorterModel>(
                        builder: (context, sorter, child) {
                          return FutureBuilder<List<dynamic>>(
                            future: sorter.getDiscardedPhotos(),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.length ?? 0;
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$count photos',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      )
                    else
                      IconButton(
                        onPressed: () {
                          // Navigate to settings
                        },
                        icon: Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ),

              // Content based on selected tab
              Expanded(
                child: selectedIndex == 0
                    ? _buildHomeContent()
                    : _buildTrashContent(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Color(0xFF9566C5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Consumer<PhotoSorterModel>(
                builder: (context, sorter, child) {
                  return FutureBuilder<List<dynamic>>(
                    future: sorter.getDiscardedPhotos(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Stack(
                        children: [
                          Icon(Icons.delete_forever),
                          if (count > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
              label: 'Trash',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildModeCards(context),
      ),
    );
  }

  Widget _buildTrashContent() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.delete_forever, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trash',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Manage your discarded photos',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
              ],
            ),
          ),
          Expanded(
            child: Consumer<PhotoSorterModel>(
              builder: (context, sorter, child) {
                return FutureBuilder<List<dynamic>>(
                  future: sorter.getDiscardedPhotos(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final trashedPhotos = snapshot.data ?? [];

                    if (trashedPhotos.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 64,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No photos in trash',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Discarded photos will appear here',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${trashedPhotos.length} photo${trashedPhotos.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    TrashScreen.routeName,
                                  );
                                },
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                TrashScreen.routeName,
                              );
                            },
                            child: Container(
                              margin: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: GridView.builder(
                                padding: EdgeInsets.all(8),
                                physics: NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 4,
                                      mainAxisSpacing: 4,
                                      childAspectRatio: 1,
                                    ),
                                itemCount: trashedPhotos.length > 6
                                    ? 6
                                    : trashedPhotos.length,
                                itemBuilder: (context, index) {
                                  final photo = trashedPhotos[index];
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: FutureBuilder(
                                      future: photo.thumbnailDataWithSize(
                                        ThumbnailSize(200, 200),
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data as Uint8List,
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        return Container(
                                          color: Colors.grey[800],
                                          child: Icon(
                                            Icons.image,
                                            color: Colors.white54,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildModeCards(BuildContext context) {
    return modes.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> mode = entry.value;

      return ModeCard(
        title: mode['title'],
        subtitle: mode['subtitle'],
        imageAsset: mode['image'],
        onTap: () => _handleModeSelection(context, mode['mode'], index),
      );
    }).toList();
  }

  Future<void> _handleModeSelection(
    BuildContext context,
    String mode,
    int index,
  ) async {
    final sorter = context.read<PhotoSorterModel>();

    // Show loading if still initializing
    if (sorter.isInitializing) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading images...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );

      while (sorter.isInitializing) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      Navigator.of(context).pop();
    }

    // Ensure we have images loaded
    if (sorter.totalCount == 0) {
      await sorter.loadAllImages();
    }

    // Handle different modes
    switch (mode) {
      case 'clean_gallery':
        await sorter.useAll();
        Navigator.pushNamed(
          context,
          SwipeSortScreen.routeName,
          arguments: 'Clean Gallery',
        );
        break;

      case 'sweep_by_date':
        Navigator.pushNamed(context, DateSelectionScreen.routeName);
        break;

      case 'after_event':
        // TODO: Implement after-event mode
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('After-Event mode coming soon!'),
            backgroundColor: Colors.orange,
          ),
        );
        break;

      case 'remove_duplicates':
        // TODO: Implement duplicate removal mode
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Remove Duplicates mode coming soon!'),
            backgroundColor: Colors.blue,
          ),
        );
        break;
    }
  }
}

class ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageAsset;
  final VoidCallback onTap;

  const ModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          image: DecorationImage(
            image: AssetImage(imageAsset),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.4),
              BlendMode.darken,
            ),
            onError: (exception, stackTrace) {
              // Handle image loading error
            },
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.3,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
