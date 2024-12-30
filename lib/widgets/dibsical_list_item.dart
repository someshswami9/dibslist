import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/creatives.dart';
import '../services/media_controller_manager.dart';



class DibsicalListItem extends StatefulWidget {
  final Creative creative;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final int index;

  const DibsicalListItem({
    Key? key,
    required this.creative,
    this.onLike,
    this.onComment,
    this.onShare, required this.index,
  }) : super(key: key);

  @override
  State<DibsicalListItem> createState() => _DibsicalListItemState();
}

class _DibsicalListItemState extends State<DibsicalListItem> with WidgetsBindingObserver {
  final _mediaManager = MediaControllerManager();
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  AudioPlayer? _audioPlayer;
  bool _isVisible = false;
  bool _isInitialized = false;
  double _lastVisibleFraction = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Only dispose local controllers, cache is managed by MediaControllerManager
    if (_chewieController != null) {
      _chewieController!.dispose();
    }
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final visibleFraction = info.visibleFraction;

    if ((visibleFraction - _lastVisibleFraction).abs() > 0.1) {
      _lastVisibleFraction = visibleFraction;
      final wasVisible = _isVisible;
      _isVisible = visibleFraction > 0.7;

      // Add this line to track visibility in cache manager
      if (widget.creative.dataType?.toLowerCase() == 'video') {
        _mediaManager.setVideoVisibility(widget.creative.dibbedUrl, _isVisible);
      }

      if (wasVisible != _isVisible) {
        if (_isVisible) {
          _mediaManager.pauseAllExcept(widget.creative.dibbedUrl);
          _playMedia();
        } else {
          _pauseMedia();
        }
      }
    }
  }

  void _playMedia() {
    if (widget.creative.dataType?.toLowerCase() == 'video' && _videoController != null) {
      _videoController!.play();
    } else if (widget.creative.dataType?.toLowerCase() == 'mp3' && _audioPlayer != null) {
      _audioPlayer!.play();
    }
  }

  void _pauseMedia() {
    if (widget.creative.dataType?.toLowerCase() == 'video' && _videoController != null) {
      _videoController!.pause();
    } else if (widget.creative.dataType?.toLowerCase() == 'mp3' && _audioPlayer != null) {
      _audioPlayer!.pause();
    }
  }

  Widget _buildVideoPlayer(String url) {
    return FutureBuilder<VideoPlayerController>(
      future: _mediaManager.getVideoController(url, widget.index),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        _videoController = snapshot.data;
        if (!_isInitialized) {
          _isInitialized = true;
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            looping: false,
            aspectRatio: _videoController!.value.aspectRatio,
            allowedScreenSleep: false,
            allowPlaybackSpeedChanging: false,
            errorBuilder: (context, errorMessage) => _buildErrorWidget('Video playback error'),
          );
        }

        return Chewie(controller: _chewieController!);
      },
    );
  }


  Widget _buildImage(String url) {
    return ExtendedImage.network(
      url,
      fit: BoxFit.cover,
      cache: true,
      enableLoadState: true,
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return const Center(child: CircularProgressIndicator());
          case LoadState.completed:
            return ExtendedRawImage(
              image: state.extendedImageInfo?.image,
              fit: BoxFit.cover,
            );
          case LoadState.failed:
            return const Center(child: Icon(Icons.error));
        }
      },
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[300], size: 48),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(Creative creative) {
    switch (creative.dataType?.toLowerCase()) {
      case 'video':
        return _buildVideoPlayer(creative.dibbedUrl);
      default:
        return _buildImage(creative.mthumbUrl);
    }
  }

  Widget _buildActionButton(IconData icon, VoidCallback? onPressed, {Color? color}) {
    return InkWell(
      onTap: onPressed,
      child: Icon(
        icon,
        size: 24,
        color: color ?? Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('media-${widget.creative.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: widget.creative.profileInfo?.photo?.isEmpty ?? true
                          ? Colors.blue[100]
                          : null,
                      backgroundImage: widget.creative.profileInfo?.photo?.isNotEmpty ?? false
                          ? NetworkImage(widget.creative.profileInfo!.photo!)
                          : null,
                      child: widget.creative.profileInfo?.photo?.isEmpty ?? true
                          ? Text(
                              widget.creative.profileInfo?.fullname?.isNotEmpty ?? false
                                  ? widget.creative.profileInfo!.fullname![0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.creative.profileInfo?.fullname ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              // Media content
              SizedBox(
                height: 400,
                child: Center(
                  child: _buildMediaContent(widget.creative),
                ),
              ),
              // Engagement stats and action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row
                    Row(
                      children: [
                        Text(
                          widget.creative.localNotifyTs,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.creative.likes} likes',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${widget.creative.comments ?? 0} comments',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Action buttons
                    Row(
                      children: [
                        _buildActionButton(
                          widget.creative.liked ? Icons.favorite : Icons.favorite_border,
                          widget.onLike,
                          color: widget.creative.liked ? Colors.red : null,
                        ),
                        const SizedBox(width: 16),
                        _buildActionButton(Icons.chat_bubble_outline, widget.onComment),
                        const SizedBox(width: 16),
                        _buildActionButton(Icons.share, widget.onShare),
                        const Spacer(),
                        _buildActionButton(Icons.bookmark_border, null),
                      ],
                    ),
                  ],
                ),
              ),
              // Tags
              if (widget.creative.tagsList != null && widget.creative.tagsList!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    children: widget.creative.tagsList!.map((tag) => Chip(
                      label: Text(
                        tag,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue[50],
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    )).toList(),
                  ),
                ),
              // Comment input
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        // Handle comment submission
                      },
                      color: Colors.blue,
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
