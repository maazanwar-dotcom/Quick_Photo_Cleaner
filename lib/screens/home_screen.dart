import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_photo_sorter/screens/swipe_sort_screen.dart';
import 'package:quick_photo_sorter/services/photo_sorter_model.dart';

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
    },
    {
      'title': 'Sweep By Date',
      'subtitle': 'Select a Date and swipe to sort pictures by date',
      'image': 'assets/onboarding_mode3.png',
    },
    {
      'title': 'After-Event CleanUp Mode',
      'subtitle':
          'Just had an Event and Clicked alot of pictures? Select a picture and Swipe sort the event quickly',
      'image': 'assets/onboarding_mode2.png',
    },
    {
      'title': 'Remove Duplicates',
      'subtitle':
          'Find and remove duplicate photos from your gallery effortlessly with our advanced duplicate detection algorithm.',
      'image': 'assets/onboarding_panel.png',
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
                      'Home',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Navigate to settings
                      },
                      icon: Icon(Icons.settings, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              // Mode Cards
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildModeCards(context),
                  ),
                ),
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

            // Handle navigation logic here
            if (index == 1) {
              // Navigate to trash screen
              // Navigator.pushNamed(context, '/trash');
            }
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.delete_forever),
              label: 'Trash',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModeCards(BuildContext context) {
    return modes.map((mode) {
      return ModeCard(
        title: mode['title'],
        subtitle: mode['subtitle'],
        imageAsset: mode['image'],
        onTap: () async {
          final sorter = context.read<PhotoSorterModel>();
          if (sorter.totalCount == 0) {
            // First time only: load & reset
            await sorter.loadAllImages();
            sorter.useAll();
          }
          // Then navigate—no further resetting
          Navigator.pushNamed(
            context,
            SwipeSortScreen.routeName,
            arguments: 'Clean Gallery',
          );
        },
      );
    }).toList();
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
