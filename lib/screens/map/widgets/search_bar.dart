import 'package:flutter/material.dart';

class SearchBarSection extends StatelessWidget {
  const SearchBarSection({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
    required this.searchResults,
    required this.onResultTap,
    required this.onResultMarkerTap,
    required this.searchError,
    required this.isSearching,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final List<SearchResultItem> searchResults;
  final void Function(SearchResultItem) onResultTap;
  final void Function(SearchResultItem) onResultMarkerTap;
  final String? searchError;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchField(),
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
