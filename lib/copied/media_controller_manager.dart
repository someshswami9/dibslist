import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

class MediaControllerManager {
  static final MediaControllerManager _instance = MediaControllerManager._internal();
  factory MediaControllerManager() => _instance;

  MediaControllerManager._internal();

  // Platform-specific cache limits
  static const int _maxCacheAndroid = 10;
  
  final _videoControllers = LinkedHashMap<String, VideoPlayerController>();
  
  int get maxCacheSize => defaultTargetPlatform == TargetPlatform.iOS 
      ? 10
      : _maxCacheAndroid;

  int get videoCacheSize => _videoControllers.length;

  final Set<String> _preloadingSet = {};

  Future<void> preloadVideos(List<String> urls) async {
    for (final url in urls) {
      if (_videoControllers.containsKey(url) || _preloadingSet.contains(url)) {
        continue; // Skip already cached or preloading URLs
      }

      _preloadingSet.add(url);
      try {
        await _initializeVideo(url);
      } catch (e) {
        print('Error preloading video $url: $e');
      } finally {
        _preloadingSet.remove(url);
      }
    }
  }


  void _logCacheStatus(String action, {String? itemId}) {
    print('[LOG] Cache Status - $action ${itemId != null ? '(Item: $itemId)' : ''}');
    print('[LOG] Video Controllers: ${_videoControllers.length}/$maxCacheSize');
  }

  Future<VideoPlayerController> getVideoController(String url) async {
    if (_videoControllers.containsKey(url)) {
      final controller = _videoControllers[url];
      if (controller?.value.isInitialized == true) {
        return controller!;
      } else {
        _videoControllers.remove(url);
      }
    }

    // Recycle older controllers if cache limit exceeded
    if (_videoControllers.length >= maxCacheSize) {
      final oldestUrl = _videoControllers.keys.first;
      await pauseAndRecycle(oldestUrl);
    }

    // Initialize new controller
    final controller = VideoPlayerController.network(url);
    await controller.initialize();
    _videoControllers[url] = controller;
    return controller;
  }

  Future<void> pauseAndRecycle(String url) async {
    final controller = _videoControllers.remove(url);
    if (controller != null) {
      await controller.pause();
      // Optionally reset it if needed
    }
  }



  Future<void> preInitializeVideos(List<String> urls) async {
    if (urls.isEmpty) return;
    
    print('[DIBSITEM] Received ${urls.length} URLs for pre-initialization');
    print('[DIBSITEM] Current cache status - Videos: ${_videoControllers.length}/$maxCacheSize');
    
    // Calculate how many items we need to remove to accommodate new videos
    final requiredSlots = urls.length;
    final availableSlots = maxCacheSize - _videoControllers.length;
    final needToRemove = (requiredSlots - availableSlots).clamp(0, _videoControllers.length);
    
    if (needToRemove > 0) {
      print('[DIBSITEM] Need to remove $needToRemove controllers to make space');
      final urlsToRemove = _videoControllers.keys.take(needToRemove).toList();
      for (final url in urlsToRemove) {
        print('[DIBSITEM] Removing controller for URL: $url');
        await disposeController(url);
      }
    }

    // Initialize new videos up to cache limit with parallel initialization
    final futures = <Future<void>>[];
    for (final url in urls) {
      if (_videoControllers.length >= maxCacheSize) break;
      if (!_videoControllers.containsKey(url)) {
        futures.add(_initializeVideo(url));
      }
    }

    // Wait for all initializations to complete
    if (futures.isNotEmpty) {
      print('[DIBSITEM] Starting parallel initialization of ${futures.length} videos');
      try {
        await Future.wait(futures);
        print('[DIBSITEM] Successfully initialized ${futures.length} videos');
      } catch (e) {
        print('[DIBSITEM] Error during parallel initialization: $e');
      }
    }
  }


  Future<void> _initializeVideo(String url) async {
    if (_videoControllers.containsKey(url)) return;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      _videoControllers[url] = controller;
      _logCacheStatus('Initialized Video Controller');
    } catch (e) {
      print('Error initializing video $url: $e');
      rethrow; // Allow errors to propagate if needed
    }
  }



  Future<void> disposeController(String url) async {

    final videoController = _videoControllers.remove(url);
    if (videoController != null) {
      await videoController.dispose();
    }

  }

  void clearCache() {
    print('[DIBSITEM] Clearing entire cache');
    _logCacheStatus('Before Clear');

    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();

    _logCacheStatus('After Clear');
  }

  void pauseAllExcept(String itemId) {
    print('[DIBSITEM] Pausing all media except item: $itemId');
    for (var controller in _videoControllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
    _logCacheStatus('After Pause All', itemId: itemId);
  }

  void removeFromCache(String url) {
    if (_videoControllers.containsKey(url)) {
      _videoControllers[url]?.dispose();
      _videoControllers.remove(url);
    }
    _logCacheStatus('After Remove');
  }

  bool isCurrentlyPlaying(String itemId) {
    return false; // Default implementation
  }
}
