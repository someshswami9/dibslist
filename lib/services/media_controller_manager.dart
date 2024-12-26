import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class MediaControllerManager {
  static final MediaControllerManager _instance =
      MediaControllerManager._internal();

  factory MediaControllerManager() => _instance;

  MediaControllerManager._internal();

  // Platform-specific cache limits
  static const int _maxCacheAndroid = 10;
  static const int _maxCacheIos = 10;

  // Using LinkedHashMap to maintain insertion order
  final Map<String, _CachedVideoController> _videoControllers = {};
  final Set<String> _preloadingSet = {};
  final Queue<String> _accessOrder = Queue<String>();

  int get maxCacheSize => defaultTargetPlatform == TargetPlatform.iOS
      ? _maxCacheIos
      : _maxCacheAndroid;

  Future<void> preInitializeVideos(List<String> urls) async {
    if (urls.isEmpty) return;

    print('[CACHE] Starting pre-initialization for ${urls.length} videos');
    print(
        '[CACHE] Current cache size: ${_videoControllers.length}/$maxCacheSize');

    // Sort URLs by priority (visible ones first, then non-cached ones)
    final prioritizedUrls = urls
        .where((url) =>
            !_videoControllers.containsKey(url) &&
            !_preloadingSet.contains(url))
        .toList();

    if (prioritizedUrls.isEmpty) {
      print('[CACHE] All URLs are already cached or being processed');
      return;
    }

    // Remove least recently used controllers if needed
    while (_videoControllers.length + prioritizedUrls.length > maxCacheSize) {
      await _removeLeastRecentlyUsed();
    }

    // Initialize new controllers in parallel
    final futures = <Future<void>>[];
    for (final url in prioritizedUrls) {
      if (_videoControllers.length >= maxCacheSize) break;
      futures.add(_initializeVideo(url));
    }

    if (futures.isNotEmpty) {
      print('[CACHE] Initializing ${futures.length} new videos');
      try {
        await Future.wait(futures);
        print('[CACHE] Successfully initialized ${futures.length} videos');
      } catch (e) {
        print('[CACHE] Error during initialization: $e');
      }
    }
  }

  Future<void> _initializeVideo(String url) async {
    if (_videoControllers.containsKey(url) || _preloadingSet.contains(url)) {
      return;
    }

    _preloadingSet.add(url);
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      _videoControllers[url] = _CachedVideoController(controller);
      _accessOrder.add(url);

      print('[CACHE] Successfully initialized video: $url');
      _updateCacheStatus('Initialize');
    } catch (e) {
      print('[CACHE] Error initializing video $url: $e');
    } finally {
      _preloadingSet.remove(url);
    }
  }

  Future<VideoPlayerController> getVideoController(String url) async {
    if (_videoControllers.containsKey(url)) {
      final cached = _videoControllers[url]!;
      cached.markAccessed();

      // Update access order
      _accessOrder.remove(url);
      _accessOrder.add(url);

      return cached.controller;
    }

    // Make space if needed
    if (_videoControllers.length >= maxCacheSize) {
      await _removeLeastRecentlyUsed();
    }

    // Initialize new controller
    await _initializeVideo(url);
    return _videoControllers[url]!.controller;
  }

  Future<void> _removeLeastRecentlyUsed() async {
    if (_accessOrder.isEmpty) return;

    // Find the least recently used non-visible controller
    String? urlToRemove;
    for (final url in _accessOrder) {
      final cached = _videoControllers[url];
      if (cached != null && !cached.isVisible) {
        urlToRemove = url;
        break;
      }
    }

    if (urlToRemove != null) {
      await _safelyDisposeController(urlToRemove);
      _accessOrder.remove(urlToRemove);
      print('[CACHE] Removed least recently used video: $urlToRemove');
    }
  }

  Future<void> _safelyDisposeController(String url) async {
    try {
      final cached = _videoControllers.remove(url);
      if (cached != null) {
        await cached.controller.pause();
        await cached.controller.dispose();
      }
    } catch (e) {
      print('[CACHE] Error disposing controller for $url: $e');
    }
  }

  void setVideoVisibility(String url, bool isVisible) {
    final cached = _videoControllers[url];
    if (cached != null) {
      cached.isVisible = isVisible;
      if (isVisible) {
        // Update access order for visible videos
        _accessOrder.remove(url);
        _accessOrder.add(url);
      }
    }
  }

  void _updateCacheStatus(String action) {
    print(
        '[CACHE] $action - Current cache size: ${_videoControllers.length}/$maxCacheSize');
    print('[CACHE] Access order: ${_accessOrder.toList()}');
  }

  void clearCache() {
    print('[CACHE] Clearing entire cache');

    for (final cached in _videoControllers.values) {
      cached.controller.dispose();
    }
    _videoControllers.clear();
    _accessOrder.clear();

    print('[CACHE] Cache cleared');
  }

  void pauseAllExcept(String currentUrl) {
    for (final entry in _videoControllers.entries) {
      if (entry.key != currentUrl && entry.value.controller.value.isPlaying) {
        entry.value.controller.pause();
      }
    }
  }

  bool isCurrentlyPlaying(String itemId) {
    return false; // Default implementation
  }
}

class _CachedVideoController {
  final VideoPlayerController controller;
  DateTime lastAccessTime;
  bool isVisible;

  _CachedVideoController(this.controller)
      : lastAccessTime = DateTime.now(),
        isVisible = false;

  void markAccessed() {
    lastAccessTime = DateTime.now();
  }
}
