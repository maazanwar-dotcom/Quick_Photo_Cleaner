import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:quick_photo_sorter/services/photo_sorter_model.dart';
import 'package:quick_photo_sorter/screens/swipe_sort_screen.dart';
import 'dart:typed_data';

class DateSelectionScreen extends StatefulWidget {
  static const routeName = '/date-selection';

  const DateSelectionScreen({super.key});

  @override
  State<DateSelectionScreen> createState() => _DateSelectionScreenState();
}

class _DateSelectionScreenState extends State<DateSelectionScreen> {
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  Map<String, List<AssetEntity>> _photosByDate = {};
  Map<String, Uint8List?> _thumbnailCache = {};
  bool _isLoading = true;
  bool _hasShownLegend = false;

  @override
  void initState() {
    super.initState();
    _loadPhotosByDate();
  }

  Future<void> _loadPhotosByDate() async {
    setState(() {
      _isLoading = true;
    });

    final sorter = context.read<PhotoSorterModel>();

    // Ensure photos are loaded
    if (sorter.totalCount == 0) {
      await sorter.loadAllImages();
    }

    // Group photos by date
    final allPhotos = sorter.getAllPhotos();
    final Map<String, List<AssetEntity>> groupedPhotos = {};

    for (final photo in allPhotos) {
      final createDate = photo.createDateTime;
      final dateKey =
          '${createDate.year}-${createDate.month.toString().padLeft(2, '0')}-${createDate.day.toString().padLeft(2, '0')}';

      if (groupedPhotos[dateKey] == null) {
        groupedPhotos[dateKey] = [];
      }
      groupedPhotos[dateKey]!.add(photo);
    }

    // Load thumbnails for preview (first photo of each date)
    for (final entry in groupedPhotos.entries) {
      if (entry.value.isNotEmpty) {
        try {
          final thumbnail = await entry.value.first.thumbnailDataWithSize(
            const ThumbnailSize(150, 150),
          );
          _thumbnailCache[entry.key] = thumbnail;
        } catch (e) {
          _thumbnailCache[entry.key] = null;
        }
      }
    }

    setState(() {
      _photosByDate = groupedPhotos;
      _isLoading = false;
    });

    // Show color legend dialog after loading
    if (!_hasShownLegend) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showColorLegendDialog();
      });
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _parseDate(String dateKey) {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]), // year
      int.parse(parts[1]), // month
      int.parse(parts[2]), // day
    );
  }

  // Show color legend dialog
  void _showColorLegendDialog() {
    _hasShownLegend = true;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2d2d2d),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.palette, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Photo Count Legend',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Days with photos are color-coded by count:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildDialogColorLegend(
                Colors.green.withOpacity(0.8),
                'Less than 5 photos',
              ),
              const SizedBox(height: 12),
              _buildDialogColorLegend(
                Colors.orange.withOpacity(0.8),
                '5 to 9 photos',
              ),
              const SizedBox(height: 12),
              _buildDialogColorLegend(
                Colors.red.withOpacity(0.8),
                '10 to 19 photos',
              ),
              const SizedBox(height: 12),
              _buildDialogColorLegend(
                Colors.purple.withOpacity(0.8),
                '20 or more photos',
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap on any colored day to see and sort those photos!',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Got it!',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper method to build dialog color legend items
  Widget _buildDialogColorLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }

  // Helper method to get color based on photo count
  Color _getPhotoCountColor(int photoCount) {
    if (photoCount == 0) return Colors.transparent;
    if (photoCount < 5) return Colors.green.withOpacity(0.7); // Few photos
    if (photoCount < 10)
      return Colors.orange.withOpacity(0.7); // Moderate photos
    if (photoCount < 20) return Colors.red.withOpacity(0.7); // Many photos
    return Colors.purple.withOpacity(0.7); // Very many photos
  }

  // Helper method to build color legend items
  Widget _buildColorLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2d2d2d),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedDate = DateTime(
                      _focusedDate.year,
                      _focusedDate.month - 1,
                    );
                  });
                },
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              Text(
                '${_getMonthName(_focusedDate.month)} ${_focusedDate.year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedDate = DateTime(
                      _focusedDate.year,
                      _focusedDate.month + 1,
                    );
                  });
                },
                icon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final lastDayOfMonth = DateTime(
      _focusedDate.year,
      _focusedDate.month + 1,
      0,
    );
    final startDate = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday % 7),
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.9, // Increased to give more height
        crossAxisSpacing: 6, // Reduced spacing
        mainAxisSpacing: 6, // Reduced spacing
      ),
      itemCount: 42, // 6 weeks * 7 days
      itemBuilder: (context, index) {
        final date = startDate.add(Duration(days: index));
        final dateKey = _formatDateKey(date);
        final photosForDate = _photosByDate[dateKey] ?? [];
        final isCurrentMonth = date.month == _focusedDate.month;
        final isSelected = dateKey == _formatDateKey(_selectedDate);
        final hasPhotos = photosForDate.isNotEmpty;
        final photoCountColor = _getPhotoCountColor(photosForDate.length);

        return GestureDetector(
          onTap: hasPhotos ? () => _selectDate(date) : null,
          child: Container(
            decoration: BoxDecoration(
              color: isCurrentMonth
                  ? (isSelected
                        ? Colors.blue.withOpacity(0.3)
                        : (hasPhotos
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.blue, width: 2)
                  : (hasPhotos
                        ? Border.all(color: photoCountColor, width: 2)
                        : null),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Date number
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isCurrentMonth
                        ? (hasPhotos
                              ? Colors.white
                              : Colors.white.withOpacity(0.3))
                        : Colors.white.withOpacity(0.1),
                    fontSize: 16,
                    fontWeight: hasPhotos ? FontWeight.bold : FontWeight.normal,
                  ),
                ),

                if (hasPhotos) ...[
                  const SizedBox(height: 2), // Reduced spacing
                  // Photo thumbnail with color indicator
                  Container(
                    width: 28, // Slightly smaller
                    height: 28, // Slightly smaller
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4), // Smaller radius
                      color: Colors.grey[800],
                      border: Border.all(
                        color: photoCountColor,
                        width: 1.5, // Thinner border
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: _thumbnailCache[dateKey] != null
                          ? Image.memory(
                              _thumbnailCache[dateKey]!,
                              fit: BoxFit.cover,
                            )
                          : const Icon(
                              Icons.image,
                              color: Colors.white54,
                              size: 14, // Smaller icon
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  Future<void> _startSortingForDate() async {
    final dateKey = _formatDateKey(_selectedDate);
    final photosForDate = _photosByDate[dateKey];

    if (photosForDate == null || photosForDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photos found for selected date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Preparing photos...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    // Set photos for date in the sorter
    final sorter = context.read<PhotoSorterModel>();
    await sorter.usePhotosFromList(photosForDate);

    Navigator.of(context).pop(); // Close loading dialog

    // Navigate to swipe sort screen
    Navigator.pushNamed(
      context,
      SwipeSortScreen.routeName,
      arguments: 'Sweep By Date - ${_formatDisplayDate(_selectedDate)}',
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatDisplayDate(DateTime date) {
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _formatDateKey(_selectedDate);
    final selectedDatePhotos = _photosByDate[dateKey] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Sweep By Date',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading photos by date...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildCalendarHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCalendarGrid(),
                        if (selectedDatePhotos.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDisplayDate(_selectedDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '${selectedDatePhotos.length} photo${selectedDatePhotos.length != 1 ? 's' : ''} found',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _getPhotoCountColor(
                                          selectedDatePhotos.length,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Photo preview grid
                                SizedBox(
                                  height: 80, // Reduced height
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: selectedDatePhotos.length > 8
                                        ? 8
                                        : selectedDatePhotos.length,
                                    itemBuilder: (context, index) {
                                      final photo = selectedDatePhotos[index];
                                      return Container(
                                        width: 70, // Slightly smaller
                                        margin: const EdgeInsets.only(
                                          right: 6,
                                        ), // Reduced margin
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          color: Colors.grey[800],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: FutureBuilder<Uint8List?>(
                                            future: photo.thumbnailDataWithSize(
                                              const ThumbnailSize(
                                                150,
                                                150,
                                              ), // Smaller thumbnail
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData &&
                                                  snapshot.data != null) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return const Center(
                                                child: Icon(
                                                  Icons.image,
                                                  color: Colors.white54,
                                                  size: 20, // Smaller icon
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (selectedDatePhotos.length > 8)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '... and ${selectedDatePhotos.length - 8} more photos',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: selectedDatePhotos.isNotEmpty
          ? Container(
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
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _startSortingForDate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swipe, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Start Sorting ${selectedDatePhotos.length} Photo${selectedDatePhotos.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
