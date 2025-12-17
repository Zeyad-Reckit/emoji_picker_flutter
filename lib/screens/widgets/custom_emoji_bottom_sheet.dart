import 'dart:async';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

// Design system colors
const backgroundPrimary = Color(0xFFFBF3E4);
const linesDivider = Color(0xFFD6D0C3);
const textPrimary = Color(0xFF313131);
const textTertiary = Color(0xFF6F6C65);
const brandColor = Color(0xFF445727);

/// Custom emoji bottom sheet with WhatsApp-style layout
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

  Map<Category, List<Emoji>> _categoryEmojis = {};
  List<RecentEmoji> _recentEmojis = [];
  List<Emoji> _suggestedEmojis = [];
  List<Emoji> _searchResults = [];
  bool _isSearching = false;
  bool _dataLoaded = false;
  Timer? _searchDebounce;
  bool _isScrolling = false;
  Category _selectedCategory = Category.SMILEYS;

  static const List<Category> _orderedCategories = [
    Category.SMILEYS,
    Category.ANIMALS,
    Category.FOODS,
    Category.TRAVEL,
    Category.ACTIVITIES,
    Category.OBJECTS,
    Category.SYMBOLS,
    Category.FLAGS,
  ];

  static const int _itemsPerRow = 7;

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

    final Map<Category, List<Emoji>> categorized = {};
    for (var categoryEmoji in state.categoryEmoji) {
      final category = categoryEmoji.category;
      if (!categorized.containsKey(category)) {
        categorized[category] = [];
      }
      categorized[category]!.addAll(categoryEmoji.emoji);
    }

    final suggestedEmojiStrings = [
      '❤️',
      '👍',
      '🔥',
      '👀',
      '😂',
      '🙌',
      '😍',
      '🎉',
    ];
    final List<Emoji> suggested = [];
    for (var emojiStr in suggestedEmojiStrings) {
      bool found = false;
      for (var categoryList in categorized.values) {
        if (found) break;
        for (var emoji in categoryList) {
          if (emoji.emoji == emojiStr) {
            suggested.add(emoji);
            found = true;
            break;
          }
        }
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
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _performSearch(_searchController.text),
    );
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

    final allEmojis = _categoryEmojis.values.expand((list) => list).toList();
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
    widget.controller.text += emoji.emoji;

    await _emojiPickerUtils.addEmojiToRecentlyUsed(
      key: GlobalKey<EmojiPickerState>(),
      emoji: Emoji(emoji.emoji, emoji.name),
    );

    await _loadRecentEmojis();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _updateSelectedCategoryOnScroll() {
    if (_isScrolling || !_scrollController.hasClients) return;

    final scrollPosition = _scrollController.offset;
    double currentPosition = 0;

    if (scrollPosition < 10) {
      if (_selectedCategory != Category.RECENT) {
        setState(() => _selectedCategory = Category.RECENT);
      }
      return;
    }

    if (_suggestedEmojis.isNotEmpty) currentPosition += 79;
    if (_recentEmojis.isNotEmpty) currentPosition += 79;

    for (var category in _orderedCategories) {
      final emojis = _categoryEmojis[category];
      if (emojis == null || emojis.isEmpty) continue;

      final categoryHeight = 36 + ((emojis.length / _itemsPerRow).ceil() * 51);

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
    final roughPosition = _calculateCategoryPosition(category);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentPosition = _scrollController.offset;
    final jumpDistance = (roughPosition - currentPosition).abs();
    final viewportHeight = _scrollController.position.viewportDimension;

    if (jumpDistance > viewportHeight * 0.8) {
      _scrollController
          .animateTo(
        roughPosition.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      )
          .then((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _calculateAndScrollToCategory(category);
          } else {
            _isScrolling = false;
          }
        });
      });
    } else {
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

    if (_suggestedEmojis.isNotEmpty) position += 79;
    if (_recentEmojis.isNotEmpty) position += 79;

    for (var cat in _orderedCategories) {
      if (cat == category) break;

      final emojis = _categoryEmojis[cat];
      if (emojis != null && emojis.isNotEmpty) {
        position += 36;
        position += ((emojis.length / _itemsPerRow).ceil()) * 51;
      }
    }

    return position;
  }

  void _calculateAndScrollToCategory(Category category) {
    if (!_scrollController.hasClients) {
      _isScrolling = false;
      return;
    }

    final targetPosition = _calculateCategoryPosition(category);
    final maxScroll = _scrollController.position.maxScrollExtent;

    _scrollController
        .animateTo(
      targetPosition.clamp(0.0, maxScroll),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSearchBar(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _dataLoaded
                    ? _buildEmojiList()
                    : const Center(child: CircularProgressIndicator()),
              ),
              _buildCategoryTabs(),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(
                      color: brandColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 34),
            ],
          ),
        ),

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

  Widget _buildEmojiList() {
    if (_isSearching) {
      return _buildSearchResults();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          if (_suggestedEmojis.isNotEmpty)
            SliverToBoxAdapter(child: _buildSuggestedRow()),
          if (_recentEmojis.isNotEmpty)
            SliverToBoxAdapter(child: _buildRecentRow()),
          ..._orderedCategories.where((category) {
            final emojis = _categoryEmojis[category];
            return emojis != null && emojis.isNotEmpty;
          }).map((category) => _buildCategorySliver(category)),
        ],
      ),
    );
  }

  Widget _buildCategorySliver(Category category) {
    final emojis = _categoryEmojis[category]!;
    final rowCount = (emojis.length / _itemsPerRow).ceil();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _getCategoryName(category),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.26,
                  color: textPrimary,
                ),
              ),
            );
          }

          final rowIndex = index - 1;
          if (rowIndex >= rowCount) return null;

          return _buildEmojiRow(emojis, rowIndex);
        },
        childCount: rowCount + 1,
      ),
    );
  }

  Widget _buildEmojiRow(List<Emoji> emojis, int rowIndex) {
    final start = rowIndex * _itemsPerRow;
    final end = (start + _itemsPerRow).clamp(0, emojis.length);
    final rowEmojis = emojis.sublist(start, end);

    final rowWidgets = <Widget>[];
    for (int i = 0; i < _itemsPerRow; i++) {
      final widget = i < rowEmojis.length
          ? _buildEmojiItem(rowEmojis[i])
          : const SizedBox(width: 35, height: 35);

      rowWidgets.add(
        Padding(
          padding: EdgeInsets.only(right: i < _itemsPerRow - 1 ? 16 : 0),
          child: widget,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround, // Changed from spaceAround
        children: rowWidgets,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border.all(color: linesDivider, width: 1),
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
        _buildEmojiRow(_suggestedEmojis, 0),
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
        _buildEmojiRow(_recentEmojis.map((e) => e.emoji).toList(), 0),
      ],
    );
  }

  Widget _buildSearchResults() {
    final rowCount = (_searchResults.length / _itemsPerRow).ceil();

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
                if (index >= rowCount) return null;
                return _buildEmojiRow(_searchResults, index);
              },
              childCount: rowCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiItem(Emoji emoji) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _onEmojiTapped(emoji),
        child: SizedBox(
          width: 35,
          height: 35,
          child: Center(
            child: Text(
              emoji.emoji,
              style: widget.emojiTextStyle.copyWith(fontSize: 28),
            ),
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
