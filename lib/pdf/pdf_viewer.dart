import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:native_pdf_renderer/native_pdf_renderer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

const _pagingDuration = Duration(milliseconds: 750);
const _minScale = 1.0;
const _maxScaleMagnification = 1.5;
const _fullscreenMagnification = 1.2;
double _maxScale(bool isFullscreen) =>
    _minScale *
    _maxScaleMagnification *
    (isFullscreen ? _fullscreenMagnification : 1);

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
    this.scrollController,
    this.maxHeight,
  })  : _isFullscreen = true,
        padding = EdgeInsets.zero,
        width = null,
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
  final _pdfViewerKey = GlobalKey();
  TextEditingController _pageInputController;
  PhotoViewController _photoViewController;
  PhotoViewScaleStateController _photoViewScaleStateController;
  PageController _pageController;
  double _scale = double.nan;
  Size _pdfSize = Size.zero;
  int _pdfPageCount;

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

  set pdfPageCount(int page) {
    if (page != _pdfPageCount) {
      setState(() => _pdfPageCount = page);
    }
  }

  @override
  void initState() {
    _pageController = PageController(initialPage: widget.initialPage);
    _pageInputController =
        TextEditingController(text: (widget.initialPage + 1).toString());
    _photoViewController = PhotoViewController()
      ..outputStateStream.listen((event) {
        scale = event.scale;
        print(event);
      });
    _photoViewScaleStateController = PhotoViewScaleStateController();
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
      key: _pdfViewerKey,
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
                      pageInputController: _pageInputController,
                      setPdfInfo: (Size size, int pageCount) {
                        pdfSize = size;
                        pdfPageCount = pageCount;
                      },
                      isFullscreen: widget._isFullscreen,
                      pdfMargin: Offset(pdfMarginLeft, pdfMarginTop),
                    );
                  }
                  return const _LoadingView();
                },
              ),
              if (!_scale.isNaN) ...[
                // TODO(haitani): 画面サイズが小さい時見えないボタンにする
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
                  pdfViewerKey: _pdfViewerKey,
                  pdfViewerPadding: widget.padding,
                  pdfDocument: widget.pdfDocument,
                  isFullscreen: widget._isFullscreen,
                  pageController: _pageController,
                  pageInputController: _pageInputController,
                  pageCount: _pdfPageCount,
                  photoViewController: _photoViewController,
                  scrollController: widget.scrollController,
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}

class _OperationArea extends StatefulWidget {
  const _OperationArea({
    Key key,
    @required this.pdfViewerKey,
    @required this.pdfViewerPadding,
    @required this.pdfDocument,
    @required this.isFullscreen,
    @required this.pageController,
    @required this.pageInputController,
    @required this.photoViewController,
    @required this.pageCount,
    this.scrollController,
  }) : super(key: key);

  final GlobalKey pdfViewerKey;
  final EdgeInsets pdfViewerPadding;
  final Future<PdfDocument> pdfDocument;
  final bool isFullscreen;
  final PageController pageController;
  final PhotoViewController photoViewController;
  final TextEditingController pageInputController;
  final int pageCount;
  final ScrollController scrollController;

  @override
  __OperationAreaState createState() => __OperationAreaState();
}

class __OperationAreaState extends State<_OperationArea> {
  static const height = 48.0;
  static const width = 450.0;

  double top = 0;
  double left;
  double opacity = .4;
  double scrollOffset = 0;
  double get marginV =>
      height +
      (widget.scrollController?.position?.maxScrollExtent ?? 0) +
      widget.pdfViewerPadding.vertical;
  double get marginH => 60 + widget.pdfViewerPadding.horizontal;

  Future<void> _onTapFullscreenButton(BuildContext context) async {
    if (widget.isFullscreen) {
      Navigator.pop(context, widget.pageController.page.toInt());
    } else {
      final page = await showDialog(
        context: context,
        builder: (_) => _FullscreenPdfView(
          pdfDocument: widget.pdfDocument,
          pageController: widget.pageController,
          initialPage: widget.pageController.page.toInt(),
        ),
      );
      if (page != null) {
        widget.pageController.jumpToPage(page);
      }
    }
  }

  void _onDragEnd(DraggableDetails detail) {
    final RenderBox box = widget.pdfViewerKey.currentContext.findRenderObject();
    setState(() {
      top = (detail.offset.dy -
              box.localToGlobal(Offset.zero).dy -
              widget.pdfViewerPadding.top -
              scrollOffset)
          .clamp(0, box.size.height - marginV);
      left = (detail.offset.dx -
              box.localToGlobal(Offset.zero).dx -
              widget.pdfViewerPadding.left)
          .clamp(0, box.size.width - marginH);
    });
  }

  void _setScrollOffset() {
    if (mounted) {
      setState(() {
        scrollOffset = widget.scrollController.offset;
      });
    }
  }

  @override
  void initState() {
    widget.scrollController?.addListener(_setScrollOffset);
    super.initState();
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_setScrollOffset);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _OperationArea oldWidget) {
    final RenderBox box = widget.pdfViewerKey.currentContext.findRenderObject();
    setState(() {
      top = top.clamp(0, box.size.height - marginV);
      left = left?.clamp(0, box.size.width - marginH);
    });
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top + scrollOffset,
      left: left,
      height: height,
      width: width,
      child: MouseRegion(
        onHover: (e) => setState(() => opacity = .9),
        onExit: (e) => setState(() => opacity = .4),
        child: Opacity(
          opacity: opacity,
          child: Container(
            color: Theme.of(context).primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DragArea(
                  height: height,
                  width: width,
                  onDragEnd: _onDragEnd,
                ),
                _PageInputField(
                  pageController: widget.pageController,
                  pageInputController: widget.pageInputController,
                  pageCount: widget.pageCount,
                ),
                _ZoomSlider(
                  isFullscreen: widget.isFullscreen,
                  photoViewController: widget.photoViewController,
                ),
                _FullscreenButton(
                  isFullscreen: widget.isFullscreen,
                  onPressed: () => _onTapFullscreenButton(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragArea extends StatelessWidget {
  const _DragArea({Key key, this.height, this.width, this.onDragEnd})
      : super(key: key);

  final double height;
  final double width;
  final DragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: Draggable(
        onDragEnd: onDragEnd,
        feedback: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(border: Border.all()),
        ),
        child: const Icon(
          Icons.drag_indicator_sharp,
          size: 28,
        ),
      ),
    );
  }
}

class _PageInputField extends StatelessWidget {
  const _PageInputField({
    Key key,
    @required this.pageController,
    @required this.pageInputController,
    @required this.pageCount,
  }) : super(key: key);

  final PageController pageController;
  final TextEditingController pageInputController;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 48,
        child: TextField(
          maxLength: 3,
          controller: pageInputController,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9]')),
          ],
          decoration: InputDecoration(
            suffixText: '/$pageCount',
            counter: const SizedBox.shrink(),
            contentPadding: const EdgeInsets.all(0),
          ),
          onChanged: (value) {
            final page = int.tryParse(value);
            if (page == null) {
              return;
            }
            final newPage = (page - 1).clamp(0, pageCount);
            pageController.jumpToPage(newPage);
          },
        ),
      ),
    );
  }
}

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({
    Key key,
    @required this.photoViewController,
    @required this.isFullscreen,
  }) : super(key: key);

  final PhotoViewController photoViewController;
  final bool isFullscreen;

  @override
  Widget build(BuildContext context) {
    Widget _zoomButton(bool zoom) {
      final icon = zoom ? Icons.zoom_in : Icons.zoom_out;
      return IconButton(
        icon: Icon(icon),
        onPressed: () {
          final interval = (_maxScale(isFullscreen) - _minScale) * .2;
          final nowValue = photoViewController.scale;
          final newValue = zoom ? nowValue + interval : nowValue - interval;
          photoViewController.scale =
              newValue.clamp(_minScale, _maxScale(isFullscreen));
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
            max: _maxScale(isFullscreen),
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
    @required this.pdfDocument,
    @required this.pageController,
    @required this.photoViewController,
    @required this.photoViewScaleStateController,
    @required this.pageInputController,
    @required this.setPdfInfo,
    @required this.isFullscreen,
    @required this.pdfMargin,
  }) : super(key: key);

  final PdfDocument pdfDocument;
  final PageController pageController;
  final PhotoViewController photoViewController;
  final TextEditingController pageInputController;
  final PhotoViewScaleStateController photoViewScaleStateController;
  final void Function(Size pdfSize, int pageCount) setPdfInfo;
  final bool isFullscreen;
  final Offset pdfMargin;

  @override
  Widget build(BuildContext context) {
    final getPdfImage = (int pageNumber) async {
      final page = await pdfDocument.getPage(pageNumber);
      setPdfInfo(
        Size(page.width.toDouble(), page.height.toDouble()),
        pdfDocument.pagesCount,
      );
      return await page.render(
        width: page.width,
        height: page.height,
      );
    };
    return PhotoViewGallery.builder(
      builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
        child: FutureBuilder<PdfPageImage>(
          future: getPdfImage(index + 1),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final pdfData = snapshot.data;
              return Stack(
                children: [
                  PhotoView(
                    controller: photoViewController,
                    scaleStateController: photoViewScaleStateController,
                    imageProvider: MemoryImage(pdfData.bytes),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    filterQuality: FilterQuality.high,
                    initialScale: _minScale,
                    minScale: _minScale,
                    maxScale: _maxScale(isFullscreen),
                  ),
                  if (!(pdfMargin.dx.isNaN || pdfMargin.dy.isNaN) &&
                      pdfData.annotations != null)
                    _AnnotationLayer(
                      annotations: pdfData.annotations,
                      scale: photoViewController.scale,
                      offset: pdfMargin,
                    ),
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
      onPageChanged: (page) {
        final pageStr = (page + 1).toString();
        if (pageStr != pageInputController.text) {
          pageInputController.text = pageStr;
        }
      },
    );
  }
}

class _AnnotationLayer extends StatelessWidget {
  const _AnnotationLayer({
    Key key,
    @required this.annotations,
    this.scale = 1.0,
    this.offset = Offset.zero,
  }) : super(key: key);
  final List<PdfAnnotation> annotations;
  final double scale;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final annotation in annotations)
          if (annotation.subtype == 'Link' && annotation.url != null)
            Positioned.fromRect(
              rect: (annotation.rect * scale).shift(offset),
              child: InkWell(
                onTap: () async {
                  final url = annotation.url;
                  final result = await canLaunch(url);
                  if (result) {
                    await launch(url);
                  }
                },
              ),
            ),
      ],
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
    @required this.isFullscreen,
    @required this.onPressed,
  }) : super(key: key);

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
    this.initialPage = 0,
    @required this.pdfDocument,
    this.pageController,
  }) : super(key: key);

  final int initialPage;
  final Future<PdfDocument> pdfDocument;
  final PageController pageController;
  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<_PdfViewerState>();
    final scrollController = ScrollController();
    return Scaffold(
      body: WillPopScope(
        onWillPop: () async {
          final page = key.currentState._pageController.page.toInt();
          pageController.jumpToPage(page);
          return true;
        },
        child: Center(
          child: SingleChildScrollView(
            controller: scrollController,
            child: PdfViewer._fullscreen(
              key: key,
              pdfDocument: pdfDocument,
              initialPage: initialPage,
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );
  }
}

extension RectEx on Rect {
  Rect operator *(double multiple) {
    return Rect.fromLTRB(
      left * multiple,
      top * multiple,
      right * multiple,
      bottom * multiple,
    );
  }
}
