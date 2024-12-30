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

  Future<void> preInitializeVideos(List<MapEntry<int, String>> preloadData) async {
    if (preloadData.isEmpty) return;

    for (final entry in preloadData) {
      final index = entry.key;
      final url = entry.value;

      if (_videoControllers.containsKey(url)) {
        continue;
      } else if (_preloadingSet.contains(url)) {
        continue;
      } else {

        await _initializeVideo(url, index);
      }
    }
  }

  Future<void> _initializeVideo(String url, int? index) async {
    if (_videoControllers.containsKey(url) || _preloadingSet.contains(url)) {
      print("[CACHE] Initializing video at index $index but contains key already");
      return;
    }


    try {
      print("[CACHE] Initializing video at index $index");
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      _videoControllers[url] = _CachedVideoController(controller);
      _accessOrder.add(url);
      _preloadingSet.add(url);
      _updateCacheStatus('Initialized at index $index');
      print("[cache] video controller list has been ${_videoControllers.length}");
    } catch (e) {
      print('[CACHE] Error initializing video  at index $index message $e');
    } finally {
      _preloadingSet.remove(url);
    }
  }

  Future<VideoPlayerController> getVideoController(String url, int index) async {
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
    print("[CACHE] called initialized from get Controller at index $index");
    await _initializeVideo(url, index);
    return _videoControllers[url]!.controller;
  }

  Future<void> _removeLeastRecentlyUsed() async {
    if (_accessOrder.isEmpty) return;

    String? urlToRemove;
    for (final url in _accessOrder) {
      final cached = _videoControllers[url];
      if (cached != null && !cached.isVisible) {
        urlToRemove = url;
        break;
      }
    }

    if (urlToRemove != null) {
      final index = _getVideoIndex(urlToRemove);
      print('[CACHE] Removing least recently used video at index $index');
      await _safelyDisposeController(urlToRemove);
      _accessOrder.remove(urlToRemove);
    }
  }

  Future<void> _safelyDisposeController(String url) async {
    try {
      final cached = _videoControllers.remove(url);
      if (cached != null) {
        // Find index for logging
        final index = _getVideoIndex(url);

        print('[CACHE] Disposing video at index $index');

        await cached.controller.pause();
        await cached.controller.dispose();

        print('[CACHE] Video at index $index has been disposed');
      }
    } catch (e) {
      print('[CACHE] Error disposing controller for ${url.substring(0, 10)}: $e');
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

  int _getVideoIndex(String url) {
    // Assuming you have access to a global or passed mapping of indices to URLs.
    final preloadData = _accessOrder.toList();
    final index = preloadData.indexOf(url);
    return index >= 0 ? index : -1; // Return -1 if index not found
  }

  void _updateCacheStatus(String action) {
    print(
        '[CACHE] $action - Current cache size: ${_videoControllers.length}/$maxCacheSize');
    print('[CACHE] Access order length: ${_accessOrder.length}');
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
