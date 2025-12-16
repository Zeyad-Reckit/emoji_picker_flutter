import 'dart:async';
import 'dart:math';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

// Design system colors
const backgroundPrimary = Color(0xFFFBF3E4);
const linesDivider = Color(0xFFD6D0C3);
const textPrimary = Color(0xFF313131);
const textTertiary = Color(0xFF6F6C65);
const brandColor = Color(0xFF445727);

/// Custom emoji bottom sheet with Figma layout:
/// Search bar -> Suggested row -> Recent row -> All categories vertically
/// OPTIMIZED for performance with lazy loading
class CustomEmojiBottomSheet extends StatefulWidget {
  final EmojiTextEditingController controller;
  final TextStyle emojiTextStyle;

  const CustomEmojiBottomSheet({
    super.key,
    required this.controller,
    required this.emojiTextStyle,
  });

  @override
  State<CustomEmojiBottomSheet> createState() => _CustomEmojiBottomSheetState();
}

class _CustomEmojiBottomSheetState extends State<CustomEmojiBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final _emojiPickerUtils = EmojiPickerUtils();

  // Emoji data extracted from package
  Map<Category, List<Emoji>> _categoryEmojis = {};
  List<RecentEmoji> _recentEmojis = [];
  List<Emoji> _suggestedEmojis = [];
  List<Emoji> _searchResults = [];
  bool _isSearching = false;
  bool _dataLoaded = false;

  // Search debounce
  Timer? _searchDebounce;

  // Ordered categories for display
  final List<Category> _orderedCategories = [
    Category.SMILEYS,
    Category.ANIMALS,
    Category.FOODS,
    Category.TRAVEL,
    Category.ACTIVITIES,
    Category.OBJECTS,
    Category.SYMBOLS,
    Category.FLAGS,
  ];

  // Flag to prevent multiple scroll animations
  bool _isScrolling = false;

  // Track selected category
  Category _selectedCategory = Category.SMILEYS;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
    _scrollController.addListener(_updateSelectedCategoryOnScroll);
    _loadRecentEmojis();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onEmojiDataLoaded(EmojiViewState state) {
    if (_dataLoaded) return;

    // Extract emoji data from state
    final Map<Category, List<Emoji>> categorized = {};

    for (var categoryEmoji in state.categoryEmoji) {
      final category = categoryEmoji.category;
      if (!categorized.containsKey(category)) {
        categorized[category] = [];
      }
      // CategoryEmoji contains a list of Emoji objects
      categorized[category]!.addAll(categoryEmoji.emoji);
    }

    // Load suggested emojis
    final suggestedEmojiStrings = ['😊', '❤️', '😂', '👍', '🔥', '🎉', '😍'];
    final List<Emoji> suggested = [];

    for (var emojiStr in suggestedEmojiStrings) {
      for (var categoryList in categorized.values) {
        for (var emoji in categoryList) {
          if (emoji.emoji == emojiStr) {
            suggested.add(emoji);
            break;
          }
        }
        if (suggested.length == suggestedEmojiStrings.length) break;
      }
    }

    setState(() {
      _categoryEmojis = categorized;
      _suggestedEmojis = suggested;
      _dataLoaded = true;
    });
  }

  Future<void> _loadRecentEmojis() async {
    try {
      final recentEmojis = await _emojiPickerUtils.getRecentEmojis();
      setState(() {
        _recentEmojis = recentEmojis;
      });
    } catch (e) {
      debugPrint('Error loading recent emojis: $e');
    }
  }

  void _handleSearchChange() {
    // Debounce search for better performance
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  void _performSearch(String query) {
    final trimmedQuery = query.toLowerCase().trim();

    if (trimmedQuery.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    // Search across all emojis
    final allEmojis = <Emoji>[];
    for (var categoryList in _categoryEmojis.values) {
      allEmojis.addAll(categoryList);
    }

    final results = allEmojis
        .where((emoji) =>
            emoji.name.toLowerCase().contains(trimmedQuery) ||
            emoji.emoji.contains(trimmedQuery))
        .toList();

    setState(() {
      _isSearching = true;
      _searchResults = results;
    });
  }

  Future<void> _onEmojiTapped(Emoji emoji) async {
    // Insert emoji into text controller
    widget.controller.text += emoji.emoji;

    // Add to recent using package API
    await _emojiPickerUtils.addEmojiToRecentlyUsed(
      key: GlobalKey<EmojiPickerState>(),
      emoji: Emoji(emoji.emoji, emoji.name),
    );

    // Reload recent emojis
    await _loadRecentEmojis();

    // Close sheet
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _updateSelectedCategoryOnScroll() {
    if (_isScrolling || !_scrollController.hasClients) return;

    final scrollPosition = _scrollController.offset;
    double currentPosition = 0;

    // Check if at top (Recent/Suggested area)
    if (scrollPosition < 10) {
      if (_selectedCategory != Category.RECENT) {
        setState(() => _selectedCategory = Category.RECENT);
      }
      return;
    }

    // Add suggested height
    if (_suggestedEmojis.isNotEmpty) {
      currentPosition += 79;
    }

    // Add recent height
    if (_recentEmojis.isNotEmpty) {
      currentPosition += 79;
    }

    // Find which category we're in
    for (var category in _orderedCategories) {
      final emojis = _categoryEmojis[category];
      if (emojis == null || emojis.isEmpty) continue;

      final categoryHeight = 36 + ((emojis.length / 7).ceil() * 51);

      if (scrollPosition < currentPosition + categoryHeight) {
        if (_selectedCategory != category) {
          setState(() => _selectedCategory = category);
        }
        return;
      }

      currentPosition += categoryHeight;
    }
  }

  void _scrollToCategory(Category category) {
    if (!_scrollController.hasClients || _isScrolling) return;

    _isScrolling = true;

    // Update selected immediately
    setState(() {
      _selectedCategory = category;
    });

    if (category == Category.RECENT) {
      _scrollController
          .animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      )
          .then((_) {
        _isScrolling = false;
      });
      return;
    }

    // For far jumps (e.g., first to last category), we need to:
    // 1. First scroll near the target to trigger lazy loading
    // 2. Wait for layout to complete
    // 3. Then scroll to exact position
    _scrollToCategoryWithPreload(category);
  }

  void _scrollToCategoryWithPreload(Category category) {
    // Calculate rough position
    final roughPosition = _calculateCategoryPosition(category);
    final maxScroll = _scrollController.position.maxScrollExtent;

    // If we're jumping far (more than viewport height), preload first
    final currentPosition = _scrollController.offset;
    final jumpDistance = (roughPosition - currentPosition).abs();
    final viewportHeight = _scrollController.position.viewportDimension;

    if (jumpDistance > viewportHeight * 0.8) {
      // Big jump - scroll to approximate position first to trigger lazy loading
      _scrollController
          .animateTo(
        roughPosition.clamp(0.0, maxScroll), // 50px before target
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      )
          .then((_) {
        // Wait for layout, then scroll to exact position
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _calculateAndScrollToCategory(category);
          } else {
            _isScrolling = false;
          }
        });
      });
    } else {
      // Small jump - scroll directly
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _calculateAndScrollToCategory(category);
        } else {
          _isScrolling = false;
        }
      });
    }
  }

  double _calculateCategoryPosition(Category category) {
    double position = 0;

    if (_suggestedEmojis.isNotEmpty) {
      position += 79;
    }
    if (_recentEmojis.isNotEmpty) {
      position += 79;
    }

    for (var cat in _orderedCategories) {
      if (cat == category) break;

      final emojis = _categoryEmojis[cat];
      if (emojis != null && emojis.isNotEmpty) {
        position += 36; // Header
        position += ((emojis.length / 7).ceil()) * 51; // Rows
      }
    }

    return position;
  }

  void _calculateAndScrollToCategory(Category category) {
    if (!_scrollController.hasClients) {
      _isScrolling = false;
      return;
    }

    // Use the helper method to calculate position
    final categoryHeaderPosition = _calculateCategoryPosition(category);

    // The scroll position should place the category header at the top of
    // the visible scroll area (position 0 of the scrollable viewport)
    // So we scroll to exactly where the header starts
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetPosition = categoryHeaderPosition.clamp(0.0, maxScroll);

    _scrollController
        .animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    )
        .then((_) {
      if (mounted) {
        _isScrolling = false;
      }
    });
  }

  String _getCategoryName(Category category) {
    switch (category) {
      case Category.SMILEYS:
        return 'Smileys & Emotion';
      case Category.ANIMALS:
        return 'Animals & Nature';
      case Category.FOODS:
        return 'Food & Drink';
      case Category.TRAVEL:
        return 'Travel & Places';
      case Category.ACTIVITIES:
        return 'Activities';
      case Category.OBJECTS:
        return 'Objects';
      case Category.SYMBOLS:
        return 'Symbols';
      case Category.FLAGS:
        return 'Flags';
      case Category.RECENT:
        return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main visible UI
        Container(
          height: 505,
          decoration: const BoxDecoration(
            color: backgroundPrimary,
            border: Border(
              top: BorderSide(color: linesDivider, width: 1),
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 66,
                  height: 4,
                  decoration: BoxDecoration(
                    color: linesDivider,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Fixed Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSearchBar(),
              ),
              const SizedBox(height: 16),

              // Scrollable content - OPTIMIZED with CustomScrollView
              Expanded(
                child: _dataLoaded
                    ? _buildOptimizedEmojiList()
                    : const Center(child: CircularProgressIndicator()),
              ),

              // Category Tabs (Fixed at bottom)
              _buildCategoryTabs(),
              const SizedBox(height: 34),
            ],
          ),
        ),

        // Hidden EmojiPicker to extract data
        Offstage(
          child: SizedBox(
            height: 1,
            width: 1,
            child: EmojiPicker(
              textEditingController: widget.controller,
              onEmojiSelected: (_, __) {},
              config: Config(
                height: 1,
                checkPlatformCompatibility: true,
                emojiViewConfig: const EmojiViewConfig(
                  emojiSizeMax: 1,
                  columns: 1,
                ),
                categoryViewConfig: CategoryViewConfig(
                  customCategoryView:
                      (config, state, tabController, pageController) {
                    // Extract emoji data from state
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _onEmojiDataLoaded(state);
                    });
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // OPTIMIZED: Use CustomScrollView with Slivers for lazy loading
  Widget _buildOptimizedEmojiList() {
    if (_isSearching) {
      return _buildSearchResults();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Suggested emojis
          if (_suggestedEmojis.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSuggestedRow()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // Recent emojis
          if (_recentEmojis.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildRecentRow()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // All categories with lazy loading
          ..._orderedCategories.where((category) {
            final emojis = _categoryEmojis[category];
            return emojis != null && emojis.isNotEmpty;
          }).map((category) {
            return _buildCategorySliverList(category);
          }),
        ],
      ),
    );
  }

  // OPTIMIZED: Build category as SliverList for lazy loading
  Widget _buildCategorySliverList(Category category) {
    final emojis = _categoryEmojis[category]!;
    const itemsPerRow = 7;
    final rowCount = (emojis.length / itemsPerRow).ceil();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // First item is the header
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    _getCategoryName(category),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.26,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          // Build emoji row
          final rowIndex = index - 1;
          if (rowIndex >= rowCount) return null;

          return _buildEmojiRow(emojis, rowIndex);
        },
        childCount: rowCount + 1, // +1 for header
      ),
    );
  }

  // OPTIMIZED: Build single row of emojis
  Widget _buildEmojiRow(List<Emoji> emojis, int rowIndex) {
    const itemsPerRow = 7;
    final start = rowIndex * itemsPerRow;
    final end = (start + itemsPerRow).clamp(0, emojis.length);
    final rowEmojis = emojis.sublist(start, end);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: rowEmojis.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(
              right: entry.key < rowEmojis.length - 1 ? 16 : 0,
            ),
            child: _buildEmojiItem(entry.value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border.all(color: linesDivider, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(
            Icons.search,
            size: 20,
            color: textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.28,
                color: textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.28,
                  color: textTertiary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildSuggestedRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggested',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.28,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 35,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestedEmojis.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _buildEmojiItem(_suggestedEmojis[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.28,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 35,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: min(7, _recentEmojis.length),
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final emoji = _recentEmojis[index];
              // Find the Emoji for this recent emoji
              Emoji? foundEmoji;
              for (var categoryList in _categoryEmojis.values) {
                for (var e in categoryList) {
                  if (e.emoji == emoji.emoji.emoji) {
                    foundEmoji = e;
                    break;
                  }
                }
                if (foundEmoji != null) break;
              }
              return foundEmoji != null
                  ? _buildEmojiItem(foundEmoji)
                  : const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          const SliverToBoxAdapter(
            child: Text(
              'Search Results',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.28,
                color: textPrimary,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                const itemsPerRow = 7;
                final rowCount = (_searchResults.length / itemsPerRow).ceil();
                if (index >= rowCount) return null;
                return _buildEmojiRow(_searchResults, index);
              },
              childCount: (_searchResults.length / 7).ceil(),
            ),
          ),
        ],
      ),
    );
  }

  // OPTIMIZED: Add RepaintBoundary to prevent unnecessary repaints
  Widget _buildEmojiItem(Emoji emoji) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _onEmojiTapped(emoji),
        child: Container(
          width: 35,
          height: 35,
          alignment: Alignment.center,
          child: Text(
            emoji.emoji,
            style: widget.emojiTextStyle.copyWith(fontSize: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 46,
      color: backgroundPrimary,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCategoryTab(Category.RECENT, Icons.access_time_outlined),
            _buildCategoryTab(Category.SMILEYS, Icons.emoji_emotions_outlined),
            _buildCategoryTab(Category.ANIMALS, Icons.pets_outlined),
            _buildCategoryTab(Category.FOODS, Icons.restaurant_outlined),
            _buildCategoryTab(Category.TRAVEL, Icons.directions_car_outlined),
            _buildCategoryTab(
                Category.ACTIVITIES, Icons.sports_soccer_outlined),
            _buildCategoryTab(Category.OBJECTS, Icons.lightbulb_outline),
            _buildCategoryTab(Category.SYMBOLS, Icons.emoji_symbols_outlined),
            _buildCategoryTab(Category.FLAGS, Icons.flag_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(Category category, IconData icon) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: InkWell(
        onTap: () => _scrollToCategory(category),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? brandColor.withValues(alpha: 0.12)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? brandColor : textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the custom emoji bottom sheet
Future<void> showCustomEmojiPicker({
  required BuildContext context,
  required EmojiTextEditingController controller,
  required TextStyle emojiTextStyle,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CustomEmojiBottomSheet(
      controller: controller,
      emojiTextStyle: emojiTextStyle,
    ),
  );
}
