import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

// Design system colors
const backgroundPrimary = Color(0xFFFBF3E4);
const linesDivider = Color(0xFFD6D0C3);
const textPrimary = Color(0xFF313131);
const textTertiary = Color(0xFF6F6C65);
const brandColor = Color(0xFF445727);

/// Custom emoji bottom sheet with precise design specifications
/// This leverages emoji_picker_flutter's full functionality while maintaining custom UI
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
  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Emoji Picker with custom configuration
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EmojiPicker(
                textEditingController: widget.controller,
                onEmojiSelected: (category, emoji) {
                  // Close the bottom sheet after selection
                  Navigator.of(context).pop();
                },
                config: Config(
                  height: 450,
                  checkPlatformCompatibility: true,
                  viewOrderConfig: const ViewOrderConfig(
                    top: EmojiPickerItem.searchBar,
                    middle: EmojiPickerItem.emojiView,
                    bottom: EmojiPickerItem.categoryBar,
                  ),
                  emojiTextStyle: widget.emojiTextStyle,
                  emojiViewConfig: const EmojiViewConfig(
                    backgroundColor: backgroundPrimary,
                    columns: 7,
                    emojiSizeMax: 28,
                    verticalSpacing: 16,
                    horizontalSpacing: 16,
                    gridPadding: EdgeInsets.zero,
                    recentsLimit: 21,
                    noRecents: Text(
                      'No recent emojis',
                      style: TextStyle(
                        fontSize: 14,
                        color: textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  skinToneConfig: const SkinToneConfig(
                    enabled: true,
                    dialogBackgroundColor: backgroundPrimary,
                    indicatorColor: brandColor,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: backgroundPrimary,
                    dividerColor: linesDivider,
                    indicatorColor: brandColor,
                    iconColorSelected: textPrimary,
                    iconColor: textTertiary,
                    tabBarHeight: 46,
                    categoryIcons: const CategoryIcons(
                      recentIcon: Icons.access_time_outlined,
                      smileyIcon: Icons.emoji_emotions_outlined,
                      animalIcon: Icons.pets_outlined,
                      foodIcon: Icons.restaurant_outlined,
                      activityIcon: Icons.sports_soccer_outlined,
                      travelIcon: Icons.directions_car_outlined,
                      objectIcon: Icons.lightbulb_outline,
                      symbolIcon: Icons.emoji_symbols_outlined,
                      flagIcon: Icons.flag_outlined,
                    ),
                    customCategoryView:
                        (config, state, tabController, pageController) {
                      return _CustomCategoryView(
                        config: config,
                        state: state,
                        tabController: tabController,
                        pageController: pageController,
                      );
                    },
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                    backgroundColor: backgroundPrimary,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: backgroundPrimary,
                    buttonIconColor: textTertiary,
                    hintText: 'Search emoji',
                    hintTextStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.02 * 14,
                      color: textTertiary,
                    ),
                    customSearchView: (config, state, showEmojiView) {
                      return _CustomSearchView(
                        config,
                        state,
                        showEmojiView,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 34),
        ],
      ),
    );
  }
}

/// Custom category view that matches our design
class _CustomCategoryView extends StatefulWidget {
  final Config config;
  final EmojiViewState state;
  final TabController tabController;
  final PageController pageController;

  const _CustomCategoryView({
    required this.config,
    required this.state,
    required this.tabController,
    required this.pageController,
  });

  @override
  State<_CustomCategoryView> createState() => _CustomCategoryViewState();
}

class _CustomCategoryViewState extends State<_CustomCategoryView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.config.categoryViewConfig.backgroundColor,
      height: widget.config.categoryViewConfig.tabBarHeight,
      child: TabBar(
        labelColor: widget.config.categoryViewConfig.iconColorSelected,
        indicatorColor: widget.config.categoryViewConfig.indicatorColor,
        unselectedLabelColor: widget.config.categoryViewConfig.iconColor,
        dividerColor: widget.config.categoryViewConfig.dividerColor,
        controller: widget.tabController,
        labelPadding: const EdgeInsets.only(top: 1.0),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: BoxDecoration(
          shape: BoxShape.circle,
          color:
              widget.config.categoryViewConfig.indicatorColor.withOpacity(0.1),
        ),
        onTap: (index) {
          widget.pageController.jumpToPage(index);
        },
        tabs: widget.state.categoryEmoji
            .asMap()
            .entries
            .map<Widget>((item) => _buildCategory(item.value.category))
            .toList(),
      ),
    );
  }

  Widget _buildCategory(Category category) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(
          getIconForCategory(
            widget.config.categoryViewConfig.categoryIcons,
            category,
          ),
          size: 20,
        ),
      ),
    );
  }
}

/// Custom search view implementation
class _CustomSearchView extends SearchView {
  const _CustomSearchView(
    super.config,
    super.state,
    super.showEmojiView,
  );

  @override
  _CustomSearchViewState createState() => _CustomSearchViewState();
}

class _CustomSearchViewState extends SearchViewState {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final emojiSize =
          widget.config.emojiViewConfig.getEmojiSize(constraints.maxWidth);
      final emojiBoxSize =
          widget.config.emojiViewConfig.getEmojiBoxSize(constraints.maxWidth);
      return Container(
        color: widget.config.searchViewConfig.backgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (results.isNotEmpty)
              SizedBox(
                height: emojiBoxSize + 8.0,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  scrollDirection: Axis.horizontal,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    return buildEmoji(
                      results[index],
                      emojiSize,
                      emojiBoxSize,
                    );
                  },
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: widget.showEmojiView,
                  color: widget.config.searchViewConfig.buttonIconColor,
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 20.0,
                  ),
                ),
                Expanded(
                  child: TextField(
                    onChanged: onTextInputChanged,
                    focusNode: focusNode,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.02 * 14,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: widget.config.searchViewConfig.hintText,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.02 * 14,
                        color: textTertiary,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
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
