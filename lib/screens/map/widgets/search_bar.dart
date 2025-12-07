import 'package:flutter/material.dart';

class SearchBarSection extends StatelessWidget {
  const SearchBarSection({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSubmitted,
    required this.onClear,
    required this.searchResults,
    required this.onResultTap,
    required this.onResultMarkerTap,
    required this.searchError,
    required this.isSearching,
    this.showDynamicIsland = false,
    this.actions = const [],
    this.onActionTap,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final List<SearchResultItem> searchResults;
  final void Function(SearchResultItem) onResultTap;
  final void Function(SearchResultItem) onResultMarkerTap;
  final String? searchError;
  final bool isSearching;
  final bool showDynamicIsland;
  final List<DynamicIslandAction> actions;
  final void Function(DynamicIslandAction action)? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchField(),
        _buildDynamicIsland(context),
        const SizedBox(height: 8),
        _buildSearchResults(context),
        if (searchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              searchError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF5A3FFF), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '충전소 이름으로 검색',
                isCollapsed: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
            ),
          ),
          if (isSearching)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          if (!isSearching)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClear,
              splashRadius: 18,
            ),
        ],
      ),
    );
  }

  Widget _buildDynamicIsland(BuildContext context) {
    final bool shouldShow = showDynamicIsland && actions.isNotEmpty;
    final Map<String, List<DynamicIslandAction>> grouped = {};
    for (final action in actions) {
      final key = action.category ?? '추천';
      grouped.putIfAbsent(key, () => []).add(action);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: shouldShow
          ? Container(
              key: const ValueKey('dynamic_island'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.88),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.trending_up, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        '내 주변의 시설',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...grouped.entries.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.key,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...group.value.asMap().entries.map(
                                (entry) => _DynamicIslandSuggestion(
                                  rank: entry.key + 1,
                                  action: entry.value,
                                  onTap: onActionTap != null
                                      ? () => onActionTap?.call(entry.value)
                                      : null,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (searchResults.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = searchResults[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.blue.shade900,
              child: Text('${index + 1}'),
            ),
            title: Text(item.name),
            subtitle: Text(item.subtitle ?? ''),
            onTap: () => onResultTap(item),
            trailing: IconButton(
              icon: const Icon(Icons.pin_drop_outlined),
              onPressed: () => onResultMarkerTap(item),
            ),
          );
        },
      ),
    );
  }
}

class SearchResultItem {
  SearchResultItem({
    required this.name,
    required this.lat,
    required this.lng,
    this.subtitle,
    this.h2,
    this.ev,
  });

  final String name;
  final String? subtitle;
  final double lat;
  final double lng;
  final Object? h2;
  final Object? ev;
}

class DynamicIslandAction {
  const DynamicIslandAction({
    required this.id,
    required this.label,
    required this.icon,
    this.color,
    this.subtitle,
    this.category,
    this.lat,
    this.lng,
    this.payload,
    this.type,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final String? category;
  final double? lat;
  final double? lng;
  final Object? payload;
  final String? type;
}

class _DynamicIslandSuggestion extends StatelessWidget {
  const _DynamicIslandSuggestion({
    required this.rank,
    required this.action,
    this.onTap,
  });

  final int rank;
  final DynamicIslandAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = action.color ?? Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(action.icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (action.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          action.subtitle!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
