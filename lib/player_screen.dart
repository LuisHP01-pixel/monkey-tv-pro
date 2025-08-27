import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String channelName;
  final String channelLogo;
  final String channelId;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.channelName,
    required this.channelLogo,
    required this.channelId,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _isBuffering = false;
  bool _showControls = true;
  String? _errorMessage;
  bool _isFullscreen = false;
  late Orientation _currentOrientation;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
    _initializeVideo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentOrientation = MediaQuery.of(context).orientation;
  }

  Future<void> _loadFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    if (!mounted) return;
    setState(() {
      _isFavorite = favorites.contains(widget.channelId);
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    
    if (!mounted) return;
    setState(() {
      if (_isFavorite) {
        favorites.remove(widget.channelId);
      } else {
        favorites.add(widget.channelId);
      }
      _isFavorite = !_isFavorite;
    });
    
    await prefs.setStringList('favorites', favorites);
  }

  Future<void> _initializeVideo() async {
    try {
      String videoUrl = widget.streamUrl;
      
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      _controller.addListener(() {
        if (!mounted) return;
        final isBuffering = _controller.value.isBuffering;
        if (isBuffering != _isBuffering) {
          setState(() {
            _isBuffering = isBuffering;
          });
        }
        
        if (_controller.value.hasError) {
          setState(() {
            _errorMessage = "Error en el video: ${_controller.value.errorDescription}";
            _isLoading = false;
          });
        }
      });

      await _controller.initialize();
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      await _controller.play();
      _controller.setLooping(true);

    } catch (error) {
       if (!mounted) return;
      setState(() {
        _errorMessage = "Error al cargar el stream: $error";
        _isLoading = false;
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _toggleFullscreen() async {
    if (_isFullscreen) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // <-- CORRECCIÓN AQUÍ
        children: [ // <-- CORRECCIÓN AQUÍ
          CircularProgressIndicator(color: Colors.orange),
          SizedBox(height: 16),
          Text(
            'Inicializando...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // <-- CORRECCIÓN AQUÍ
          children: [ // <-- CORRECCIÓN AQUÍ
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Error al cargar el stream',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initializeVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.isInitialized
            ? _controller.value.aspectRatio
            : 16 / 9,
        child: VideoPlayer(_controller),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: SafeArea(
                child: BackButton(
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10, size: 40, color: Colors.white),
                    onPressed: () async {
                      final position = await _controller.position;
                      if (position != null) {
                        await _controller.seekTo(position - const Duration(seconds: 10));
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      size: 60,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      });
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.forward_10, size: 40, color: Colors.white),
                    onPressed: () async {
                      final position = await _controller.position;
                      if (position != null) {
                        await _controller.seekTo(position + const Duration(seconds: 10));
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _controller.value.isInitialized
            ? GestureDetector(
                onTap: _toggleControls,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildVideoPlayer(),
                    if (_isBuffering)
                      const CircularProgressIndicator(color: Colors.orange),
                    _buildControlsOverlay(),
                  ],
                ),
              )
            : _isLoading
                ? _buildLoadingIndicator()
                : _buildErrorWidget(),
      ),
    );
  }
}