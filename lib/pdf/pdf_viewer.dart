import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_pdf_renderer/native_pdf_renderer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

const _pagingDuration = Duration(milliseconds: 750);
const _minScale = 1.0;
const _maxScaleMagnification = 1.5;
const _fullscreenMagnification = 1.2;
const _maxScale = _minScale * _maxScaleMagnification;

class PdfViewer extends StatefulWidget {
  const PdfViewer({
    Key key,
    this.initialPage = 0,
    @required this.pdfDocument,
    this.scrollController,
    this.width,
    this.maxHeight,
    this.padding = EdgeInsets.zero,
  })  : _isFullscreen = false,
        super(key: key);

  const PdfViewer._fullscreen({
    Key key,
    this.initialPage = 0,
    @required this.pdfDocument,
    this.maxHeight,
  })  : _isFullscreen = true,
        padding = EdgeInsets.zero,
        width = null,
        scrollController = null,
        super(key: key);

  final int initialPage;
  final Future<PdfDocument> pdfDocument;
  final ScrollController scrollController;
  final double width, maxHeight;
  final EdgeInsets padding;
  final bool _isFullscreen;

  @override
  _PdfViewerState createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  TextEditingController _pageInputController;
  PhotoViewController _photoViewController;
  PhotoViewScaleStateController _photoViewScaleStateController;
  PageController _pageController;
  double _scale = double.nan;
  Size _pdfSize = Size.zero;
  double _pagingButtonOffset = 0;

  double get pdfHeight => _pdfSize.height * _scale;
  double get pdfWidth => _pdfSize.width * _scale;

  set scale(double scale) {
    if (scale != _scale) {
      setState(() => _scale = scale);
    }
  }

  set pdfSize(Size size) {
    if (size != _pdfSize) {
      setState(() => _pdfSize = size);
    }
  }

  set pagingButtonOffset(double offset) {
    if (offset != _pagingButtonOffset) {
      setState(() => _pagingButtonOffset = offset);
    }
  }

  @override
  void initState() {
    _pageController = PageController(initialPage: widget.initialPage);
    _pageInputController = TextEditingController();
    _photoViewController = PhotoViewController()
      ..outputStateStream.listen((event) {
        scale = event.scale;
        print(event);
      });
    _photoViewScaleStateController = PhotoViewScaleStateController();
    // widget.scrollController?.addListener(() {
    //   pagingButtonOffset = widget.scrollController.offset;
    // });
    super.initState();
  }

  @override
  void dispose() {
    _pageInputController.dispose();
    _photoViewController.dispose();
    _pageController.dispose();
    _photoViewScaleStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraint) {
        final width = widget.width ?? constraint.maxWidth;
        final height = pdfHeight.isNaN
            ? MediaQuery.of(context).size.height
            : (pdfHeight * 1.05);
        print('max $width, $height');
        print('pdf $pdfWidth, $pdfHeight');
        const pagingButtonWidth = 108.0;
        final pagingButtonHeight = pdfHeight;

        final pdfMarginLeft = (width - pdfWidth) / 2 - widget.padding.left;
        final pdfMarginTop = (height - pdfHeight) / 2 - widget.padding.top;

        final pagingButtonPositionH = (pdfMarginLeft - pagingButtonWidth)
            .clamp(double.minPositive, width);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: widget.padding,
          constraints: constraint.copyWith(
            maxHeight: widget.maxHeight,
          ),
          height: height,
          width: width,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FutureBuilder<PdfDocument>(
                future: widget.pdfDocument,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return _PdfView(
                      pdfDocument: snapshot.data,
                      pageController: _pageController,
                      photoViewController: _photoViewController,
                      photoViewScaleStateController:
                          _photoViewScaleStateController,
                      setPdfSize: (Size size) => pdfSize = size,
                      isFullscreen: widget._isFullscreen,
                      pdfMarginLeft: pdfMarginLeft,
                      pdfMarginTop: pdfMarginTop,
                    );
                  }
                  return const _LoadingView();
                },
              ),
              if (!_scale.isNaN) ...[
                if (width > 580) ...[
                  _PagingButton(
                    height: pagingButtonHeight,
                    width: pagingButtonWidth,
                    isNext: false,
                    pageController: _pageController,
                    hPosition: pagingButtonPositionH,
                  ),
                  _PagingButton(
                    height: pagingButtonHeight,
                    width: pagingButtonWidth,
                    isNext: true,
                    pageController: _pageController,
                    hPosition: pagingButtonPositionH,
                  ),
                ],
                _OperationArea(
                  pdfDocument: widget.pdfDocument,
                  isFullscreen: widget._isFullscreen,
                  pageController: _pageController,
                  photoViewController: _photoViewController,
                  pdfWidth: pdfWidth,
                  pdfHeight: pdfHeight,
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}

class _OperationArea extends StatelessWidget {
  const _OperationArea({
    Key key,
    this.pdfDocument,
    this.isFullscreen,
    this.pageController,
    this.pageInputController,
    this.photoViewController,
    this.pdfHeight,
    this.pdfWidth,
  }) : super(key: key);

  final Future<PdfDocument> pdfDocument;
  final bool isFullscreen;
  final PageController pageController;
  final PhotoViewController photoViewController;
  final double pdfWidth, pdfHeight;
  final TextEditingController pageInputController;

  Future<void> _tapFullscreenButton(BuildContext context) async {
    if (isFullscreen) {
      Navigator.pop(context);
    } else {
      await showDialog(
        context: context,
        builder: (_) => _FullscreenPdfView(
          pdfDocument: pdfDocument,
          initialPage: pageController.page.toInt(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      width: pdfWidth,
      top: 0,
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 48,
            child: TextField(
              maxLength: 3,
              controller: pageInputController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9]')),
              ],
              decoration: InputDecoration(
                suffixText: '/ ${pageController.page}',
                counter: const SizedBox.shrink(),
                contentPadding: const EdgeInsets.all(0),
              ),
              onChanged: (value) {},
            ),
          ),
          _ZoomSlider(
            isFullscreen: isFullscreen,
            photoViewController: photoViewController,
          ),
          _FullscreenButton(
            isFullscreen: isFullscreen,
            onPressed: () => _tapFullscreenButton(context),
          ),
        ],
      ),
    );
  }
}

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({
    Key key,
    this.photoViewController,
    this.isFullscreen,
  }) : super(key: key);

  final PhotoViewController photoViewController;
  final bool isFullscreen;

  @override
  Widget build(BuildContext context) {
    Widget _zoomButton(bool zoom) {
      final icon = zoom ? Icons.zoom_in : Icons.zoom_out;
      return IconButton(
        icon: Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.background,
        ),
        onPressed: () {
          const interval = (_maxScale - _minScale) * .2;
          final nowValue = photoViewController.scale;
          final newValue = zoom ? nowValue + interval : nowValue - interval;
          photoViewController.scale = newValue.clamp(_minScale, _maxScale);
        },
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _zoomButton(false),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 6,
              pressedElevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: photoViewController.scale,
            max: _maxScale,
            min: _minScale,
            onChanged: (value) {
              photoViewController.scale = value;
            },
          ),
        ),
        _zoomButton(true),
      ],
    );
  }
}

class _PdfView extends StatelessWidget {
  const _PdfView({
    Key key,
    this.pdfDocument,
    this.pageController,
    this.photoViewController,
    this.photoViewScaleStateController,
    this.setPdfSize,
    this.isFullscreen,
    this.pdfMarginLeft,
    this.pdfMarginTop,
  }) : super(key: key);

  final PdfDocument pdfDocument;
  final PageController pageController;
  final PhotoViewController photoViewController;
  final PhotoViewScaleStateController photoViewScaleStateController;
  final void Function(Size pdfSize) setPdfSize;
  final bool isFullscreen;
  final double pdfMarginLeft, pdfMarginTop;

  @override
  Widget build(BuildContext context) {
    final getPdfImage = (int pageNumber) async {
      final page = await pdfDocument.getPage(pageNumber);
      setPdfSize(Size(page.width.toDouble(), page.height.toDouble()));
      return await page.render(
        width: page.width,
        height: page.height,
      );
    };
    return PhotoViewGallery.builder(
      builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
        child: FutureBuilder(
          future: getPdfImage(index + 1),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Stack(
                children: [
                  PhotoView(
                    controller: photoViewController,
                    scaleStateController: photoViewScaleStateController,
                    imageProvider: MemoryImage(snapshot.data.bytes),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    filterQuality: FilterQuality.high,
                    initialScale: isFullscreen
                        ? PhotoViewComputedScale.contained
                        : _minScale,
                    minScale: _minScale,
                    maxScale: isFullscreen
                        ? _maxScale * _fullscreenMagnification
                        : _maxScale,
                  ),
                  if (!(pdfMarginLeft.isNaN || pdfMarginTop.isNaN))
                    Positioned(
                      top: 316.346 * photoViewController.scale + pdfMarginTop,
                      left: 56.6929 * photoViewController.scale + pdfMarginLeft,
                      width: 215.752 * photoViewController.scale,
                      height: 10 * photoViewController.scale,
                      child: InkWell(
                        onTap: () async {
                          const url = 'https://www.antennahouse.com/';
                          final result = await canLaunch(url);
                          if (result) {
                            await launch(url);
                          }
                        },
                      ),
                    )
                ],
              );
            }
            return const _LoadingView();
          },
        ),
      ),
      itemCount: pdfDocument.pagesCount,
      loadingBuilder: (context, event) => const _LoadingView(),
      backgroundDecoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      pageController: pageController,
      onPageChanged: (page) => print(page),
    );
  }
}

class _PagingButton extends StatelessWidget {
  const _PagingButton({
    Key key,
    this.height,
    this.width,
    @required this.isNext,
    @required this.pageController,
    this.hPosition,
  }) : super(key: key);
  final double height;
  final double width;
  final bool isNext;
  final PageController pageController;
  final double hPosition;

  @override
  Widget build(BuildContext context) {
    final paging =
        isNext ? pageController.nextPage : pageController.previousPage;
    final begin =
        isNext ? FractionalOffset.centerLeft : FractionalOffset.centerRight;
    final end =
        isNext ? FractionalOffset.centerRight : FractionalOffset.centerLeft;
    final icon = isNext ? Icons.navigate_next : Icons.navigate_before;
    return Positioned(
      right: isNext ? hPosition : null,
      left: isNext ? null : hPosition,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [
              Colors.transparent,
              Theme.of(context).cardColor.withOpacity(0.4),
            ],
            stops: const [0, 1],
          ),
        ),
        height: height,
        width: width,
        child: FlatButton(
          child: Icon(
            icon,
            size: 32,
          ),
          onPressed: () => paging(
            duration: _pagingDuration,
            curve: Curves.ease,
          ),
        ),
      ),
    );
  }
}

class _FullscreenButton extends StatelessWidget {
  const _FullscreenButton({
    Key key,
    this.isFullscreen,
    this.pdfWidth,
    this.onPressed,
  }) : super(key: key);

  final double pdfWidth;
  final bool isFullscreen;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
      ),
      onPressed: onPressed,
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({Key key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _FullscreenPdfView extends StatelessWidget {
  const _FullscreenPdfView({
    Key key,
    this.initialPage,
    @required this.pdfDocument,
  }) : super(key: key);

  final int initialPage;
  final Future<PdfDocument> pdfDocument;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: PdfViewer._fullscreen(
          pdfDocument: pdfDocument,
          initialPage: initialPage,
          maxHeight: MediaQuery.of(context).size.height,
        ),
      ),
    );
  }
}
