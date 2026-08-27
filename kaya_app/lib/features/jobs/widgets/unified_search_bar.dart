import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Search filter options - values represent WHAT CONTENT to display
/// - all: Show both jobs and workers
/// - showJobs: Display job listings (for workers to browse)
/// - showWorkers: Display worker profiles (for employers to browse)
enum SearchFilter { all, showJobs, showWorkers }

/// Unified Search Bar with Jobs/People filtering
/// Replaces mode switching with simple search filtering
class UnifiedSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final Function(SearchFilter) onFilterChanged;
  final SearchFilter currentFilter;
  final String? hintText;
  final List<SearchFilter>? visibleFilters; // Optional: limit which filters to show

  const UnifiedSearchBar({
    super.key,
    required this.onSearch,
    required this.onFilterChanged,
    this.currentFilter = SearchFilter.all,
    this.hintText,
    this.visibleFilters, // If null, shows all filters
  });

  @override
  State<UnifiedSearchBar> createState() => _UnifiedSearchBarState();
}

class _UnifiedSearchBarState extends State<UnifiedSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Input Field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: (value) {
              widget.onSearch(value);
            },
            decoration: InputDecoration(
              hintText: widget.hintText ?? _getHintText(),
              prefixIcon: Icon(
                _getSearchIcon(),
                color: AppColors.primary,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppColors.neutral500),
                      onPressed: () {
                        _controller.clear();
                        widget.onSearch('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        
        // Filter Toggle Buttons - conditionally show based on visibleFilters
        //
        // The spacer belongs inside the branch. Left outside it, an account
        // that gets no chips — a new one with neither profile — still got the
        // gap where the row would have been.
        if (_shouldShowFilterButtons()) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                /*
                    Worker, Employer, All - in that order.

                    Named after the side of the marketplace rather than what is
                    listed, because this is not a list filter any more: it
                    decides what the whole screen is about, activity included.
                    "Jobs" described half of what picking it does.
                */
                if (_isFilterVisible(SearchFilter.showJobs))
                  Expanded(
                    child: _FilterButton(
                      label: 'Worker',
                      isSelected: widget.currentFilter == SearchFilter.showJobs,
                      onTap: () => widget.onFilterChanged(SearchFilter.showJobs),
                    ),
                  ),
                if (_isFilterVisible(SearchFilter.showWorkers))
                  Expanded(
                    child: _FilterButton(
                      label: 'Employer',
                      isSelected: widget.currentFilter == SearchFilter.showWorkers,
                      onTap: () => widget.onFilterChanged(SearchFilter.showWorkers),
                    ),
                  ),
                if (_isFilterVisible(SearchFilter.all))
                  Expanded(
                    child: _FilterButton(
                      label: 'All',
                      isSelected: widget.currentFilter == SearchFilter.all,
                      onTap: () => widget.onFilterChanged(SearchFilter.all),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _isFilterVisible(SearchFilter filter) {
    if (widget.visibleFilters == null) return true;
    return widget.visibleFilters!.contains(filter);
  }

  bool _shouldShowFilterButtons() {
    // If visibleFilters is null, show all buttons
    if (widget.visibleFilters == null) return true;
    // If only one filter is visible, don't show buttons (no choice to make)
    if (widget.visibleFilters!.length <= 1) return false;
    return true;
  }

  String _getHintText() {
    switch (widget.currentFilter) {
      case SearchFilter.all:
        return 'Search jobs and workers...';
      case SearchFilter.showJobs:
        return 'Search jobs to apply...';
      case SearchFilter.showWorkers:
        return 'Search workers to hire...';
    }
  }

  IconData _getSearchIcon() {
    switch (widget.currentFilter) {
      case SearchFilter.all:
        return Icons.search;
      case SearchFilter.showJobs:
        return Icons.work_outline;
      case SearchFilter.showWorkers:
        return Icons.person_search;
    }
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.neutral700,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}