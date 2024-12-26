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

  const DibsicalListItem({
    Key? key,
    required this.creative,
    this.onLike,
    this.onComment,
    this.onShare,
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
    
    // Only update if visibility changed significantly
    if ((visibleFraction - _lastVisibleFraction).abs() > 0.1) {
      _lastVisibleFraction = visibleFraction;
      final wasVisible = _isVisible;
      _isVisible = visibleFraction > 0.7; // Increased threshold for center-most item

      if (wasVisible != _isVisible) {
        if (_isVisible) {
          // Pause all other media and play this one
          _mediaManager.pauseAllExcept(widget.creative.id);
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
      future: _mediaManager.getVideoController(url),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget('Unable to play this video format');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        _videoController = snapshot.data;
        if (!_isInitialized) {
          _isInitialized = true;
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: _isVisible && _mediaManager.isCurrentlyPlaying(widget.creative.id),
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

  Widget _buildAudioPlayer(String url) {
    return FutureBuilder<AudioPlayer>(
      future: _mediaManager.getAudioPlayer(url),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget('Unable to load audio');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        _audioPlayer = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildImage(widget.creative.mthumbUrl),
              ),
              const SizedBox(height: 16),
              StreamBuilder<Duration?>(
                stream: _audioPlayer!.durationStream,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: _audioPlayer!.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      // Ensure position doesn't exceed duration
                      final currentPosition = position > duration ? duration : position;
                      final maxDuration = duration.inMilliseconds > 0 
                          ? duration.inMilliseconds.toDouble()
                          : 1.0;  // Prevent zero max value
                          
                      return Column(
                        children: [
                          Slider(
                            value: currentPosition.inMilliseconds.toDouble().clamp(0, maxDuration),
                            max: maxDuration,
                            activeColor: Colors.blue,
                            onChanged: (value) {
                              if (duration.inMilliseconds > 0) {
                                _audioPlayer!.seek(Duration(milliseconds: value.toInt()));
                              }
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(currentPosition),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () {
                      final newPosition = _audioPlayer!.position - const Duration(seconds: 10);
                      _audioPlayer!.seek(newPosition);
                    },
                  ),
                  const SizedBox(width: 16),
                  StreamBuilder<PlayerState>(
                    stream: _audioPlayer!.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final processingState = playerState?.processingState;
                      final playing = playerState?.playing;

                      if (processingState == ProcessingState.loading ||
                          processingState == ProcessingState.buffering) {
                        return Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(8),
                          child: const CircularProgressIndicator(),
                        );
                      }

                      if (playing != true) {
                        return IconButton(
                          icon: const Icon(Icons.play_circle_filled),
                          iconSize: 48,
                          onPressed: _isVisible ? _audioPlayer!.play : null,
                        );
                      }

                      return IconButton(
                        icon: const Icon(Icons.pause_circle_filled),
                        iconSize: 48,
                        onPressed: _audioPlayer!.pause,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    onPressed: () {
                      final newPosition = _audioPlayer!.position + const Duration(seconds: 10);
                      _audioPlayer!.seek(newPosition);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
      case 'mp3':
        return _buildAudioPlayer(creative.dibbedUrl);
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