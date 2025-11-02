import 'package:flutter/material.dart';

class FullScreenImage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImage({
    required this.imageUrls,
    this.initialIndex = 0,
    super.key, // FIX: Use super.key
  });

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (details == null) return;

    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = details.localPosition;
      
      // FIX: Replace deprecated translate and scale with modern methods
      final zoomMatrix = Matrix4.identity()
        ..translate(-position.dx * 2, -position.dy * 2) // Translation vector
        ..scale(3.0); // Scale factor
        
      _transformationController.value = zoomMatrix;
    }
  }
  
  // Helper to safely reset transformation when changing pages
  void _resetZoom() {
    if (_transformationController.value != Matrix4.identity()) {
        _transformationController.value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Icon(
            Icons.image_not_supported,
            color: Colors.white70,
            size: 80,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.imageUrls.length}'),
      ),
      body: GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
              _resetZoom(); // Reset zoom when page changes
            });
          },
          itemBuilder: (context, index) {
            final imageUrl = widget.imageUrls[index];
            return Center(
              // Only apply transformation controller to the current page view
              child: InteractiveViewer(
                // Only provide transformation controller if this is the current page, 
                // allowing others to use default behavior or reset easily.
                transformationController: index == _currentIndex ? _transformationController : null,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 1.0,
                maxScale: 5.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(
                    Icons.broken_image,
                    size: 80,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}