import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../models/creatives.dart';
import '../services/api_service.dart';
import '../utils/keep_alive_wrapper.dart';
import 'dibsical_list_item.dart';
import '../services/media_controller_manager.dart';

class DibsList extends StatefulWidget {
  const DibsList({Key? key}) : super(key: key);

  @override
  State<DibsList> createState() => _DibsListState();
}

class _DibsListState extends State<DibsList> {
  static const _pageSize = ApiService.itemsPerPage;
  final PagingController<int, Creative> _pagingController =
  PagingController(firstPageKey: 1);
  final _mediaManager = MediaControllerManager();
  final _scrollController = ScrollController();
  final _apiService = ApiService();
  Timer? _scrollThrottleTimer;

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _scrollController.dispose();
    _mediaManager.clearCache();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || (_scrollThrottleTimer?.isActive ?? false)) {
      return;
    }
    _scrollThrottleTimer?.cancel();
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 100), () {
      final visibleRange = _getVisibleItemRange();
      if (visibleRange != null) {
        _preloadVideosInRange(visibleRange.start, visibleRange.end);
      }
    });
  }

  final Set<int> preloadedIndices = {};

  void _preloadVideosInRange(int startIndex, int endIndex) {
    final items = _pagingController.itemList;
    if (items == null || items.isEmpty) return;

    const preloadWindow = 3;

    for (int i = max(0, startIndex - preloadWindow);
    i <= min(items.length - 1, endIndex + preloadWindow);
    i++) {
      final item = items[i];
      if (item.dataType?.toLowerCase() == 'video' &&
          item.dibbedUrl.isNotEmpty &&
          !preloadedIndices.contains(i)) {
        preloadedIndices.add(i);
        _mediaManager.preInitializeVideos([MapEntry(i, item.dibbedUrl)]);
      }
    }
    // print("[CACHE] indices has been $preloadedIndices");
  }

  Range? _getVisibleItemRange() {
    if (!_scrollController.hasClients || _pagingController.itemList == null) return null;

    final List<Creative> items = _pagingController.itemList!;
    if (items.isEmpty) return null;

    final viewportStart = _scrollController.offset;
    final viewportEnd = viewportStart + _scrollController.position.viewportDimension;
    const estimatedItemHeight = 550.0;

    final startIndex = (viewportStart / estimatedItemHeight).floor().clamp(0, items.length - 1);
    final endIndex = (viewportEnd / estimatedItemHeight).ceil().clamp(0, items.length - 1);

    return Range(startIndex, endIndex);
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await _apiService.fetchCreatives(page: pageKey);
      final isLastPage = newItems.length < _pageSize;

      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(newItems, nextPageKey);
      }

      if (pageKey == 1) {
        _preloadVideosInRange(0, newItems.length - 1);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
          return Center(
            child: SizedBox(
              width: maxWidth,
              child: RefreshIndicator(
                onRefresh: () async {
                  _mediaManager.clearCache();
                  _pagingController.refresh();
                },
                child: PagedListView<int, Creative>(
                  scrollController: _scrollController,
                  pagingController: _pagingController,
                  builderDelegate: PagedChildBuilderDelegate<Creative>(
                    itemBuilder: (context, creative, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: DibsicalListItem(
                        creative: creative,
                        onLike: () {},
                        onComment: () {},
                        onShare: () {}, index: index,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class Range {
  final int start;
  final int end;

  Range(this.start, this.end);
}


