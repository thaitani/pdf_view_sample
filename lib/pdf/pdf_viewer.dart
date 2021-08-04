import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:native_pdf_renderer/native_pdf_renderer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

const _pagingDuration = Duration(milliseconds: 750);
const _minScale = .5;
const _maxScale = 2.0;
const _toolBoxHeight = 48.0;
const _pdfSizeMagnification = 1;

class PdfViewer extends StatefulWidget {
  const PdfViewer({
    Key? key,
    required this.pdfDocument,
    this.scrollController,
    this.width,
    this.maxHeight,
    this.minHeight,
    this.pageController,
  })  : _isFullscreen = false,
        super(key: key);

  const PdfViewer._fullscreen({
    Key? key,
    required this.pdfDocument,
    this.scrollController,
    this.maxHeight,
    this.minHeight,
    this.pageController,
  })  : _isFullscreen = true,
        width = null,
        super(key: key);

  final Future<PdfDocument> pdfDocument;
  final ScrollController? scrollController;
  final double? width, maxHeight, minHeight;
  final bool _isFullscreen;
  final PageController? pageController;

  @override
  _PdfViewerState createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  final _pdfViewerKey = GlobalKey();
  TextEditingController get pageInputController => _pageInputController;
  late final _pageInputController = TextEditingController(
      text: ((widget.pageController?.initialPage ?? 0) + 1).toString());

  TextEditingController get scaleInputController => _scaleInputController;
  late final _scaleInputController = TextEditingController(text: '100');

  PhotoViewController get photoViewController => _photoViewController;
  late final _photoViewController = PhotoViewController()
    ..outputStateStream.listen((event) {
      final nowScale = event.scale;
      if (nowScale == null) {
        return;
      }
      scale = nowScale;
      final scaleText = (_scale * 100).round().toString();
      if (scaleText != scaleInputController.text) {
        scaleInputController.text = scaleText;
      }
    });

  PageController get pageController => _pageController;
  late final _pageController = widget.pageController ?? PageController();

  PhotoViewScaleStateController get photoViewScaleStateController =>
      _photoViewScaleStateController;
  late final _photoViewScaleStateController = PhotoViewScaleStateController();

  double _scale = double.nan;
  Size _pdfSize = Size.zero;
  int? _pdfPageCount;

  Size get pdfSize => _pdfSize * _scale;

  Size get fullscreenSize => MediaQuery.of(context).size * .9;

  Size divideSize(Size size1, Size size2) =>
      Size(size1.width / size2.width, size1.height / size2.height);

  double get initialScale {
    final box = _pdfViewerKey.currentContext?.findRenderObject() as RenderBox?;
    final screenSize = widget._isFullscreen ? fullscreenSize : box?.size;
    final maxInitialScale = widget._isFullscreen ? 1.5 : 1.0;
    if (_pdfSize == Size.zero || screenSize == null) {
      return 1;
    }
    return divideSize(screenSize, _pdfSize)
        .shortestSide
        .clamp(_minScale, maxInitialScale);
  }

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
  void dispose() {
    pageInputController.dispose();
    photoViewController.dispose();
    pageController.dispose();
    photoViewScaleStateController.dispose();
    scaleInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: _pdfViewerKey,
      builder: (_, constraint) {
        final width = widget.width ?? constraint.maxWidth;
        final height =
            pdfSize.height.isNaN ? fullscreenSize.height : pdfSize.height;
        final viewerSize = Size(width, height);
        final pdfMarginW = (width - pdfSize.width) / 2;
        final pdfMarginH = (height - pdfSize.height) / 2 + _toolBoxHeight;
        final pdfMargin = Offset(pdfMarginW, pdfMarginH);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          constraints: constraint.copyWith(
            maxHeight: widget.maxHeight,
            minHeight: widget.minHeight,
          ),
          height: height + _toolBoxHeight * 2,
          width: width,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              FutureBuilder<PdfDocument>(
                future: widget.pdfDocument,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return _PdfView(
                      pdfDocument: snapshot.data!,
                      pageController: pageController,
                      photoViewController: photoViewController,
                      pageInputController: pageInputController,
                      photoViewScaleStateController:
                          photoViewScaleStateController,
                      setPdfInfo: (Size size, int? pageCount) {
                        pdfSize = size;
                        pdfPageCount = pageCount!;
                      },
                      isFullscreen: widget._isFullscreen,
                      initialScale: initialScale,
                      pdfMargin: pdfMargin,
                      viewSize: viewerSize,
                    );
                  }
                  if (snapshot.hasError) {
                    return const SizedBox.shrink();
                  }
                  return const _LoadingView();
                },
              ),
              if (!_scale.isNaN) ...[
                _ToolBox(
                  pdfViewerKey: _pdfViewerKey,
                  pdfDocument: widget.pdfDocument,
                  isFullscreen: widget._isFullscreen,
                  pageController: pageController,
                  pageInputController: pageInputController,
                  scaleInputController: scaleInputController,
                  pageCount: _pdfPageCount,
                  photoViewController: photoViewController,
                  scrollController: widget.scrollController,
                  pdfSize: pdfSize,
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}

class _ToolBox extends StatefulWidget {
  const _ToolBox({
    Key? key,
    required this.pdfViewerKey,
    required this.pdfDocument,
    required this.isFullscreen,
    required this.pageController,
    required this.pageInputController,
    required this.scaleInputController,
    required this.photoViewController,
    required this.pageCount,
    required this.pdfSize,
    this.scrollController,
  }) : super(key: key);

  final GlobalKey pdfViewerKey;
  final Future<PdfDocument> pdfDocument;
  final bool isFullscreen;
  final PageController pageController;
  final PhotoViewController photoViewController;
  final TextEditingController pageInputController;
  final TextEditingController scaleInputController;
  final ScrollController? scrollController;
  final int? pageCount;
  final Size pdfSize;

  @override
  _ToolBoxState createState() => _ToolBoxState();
}

class _ToolBoxState extends State<_ToolBox> {
  double get width {
    final RenderBox box =
        widget.pdfViewerKey.currentContext?.findRenderObject() as RenderBox;
    return widget.pdfSize.width.clamp(double.minPositive, box.size.width);
  }

  double get marginV =>
      _toolBoxHeight + (widget.scrollController?.position.maxScrollExtent ?? 0);

  double get marginH => width / 7;

  Future<void> _onTapFullscreenButton(BuildContext context) async {
    if (widget.isFullscreen) {
      Navigator.pop(context, widget.pageController.page?.toInt());
    } else {
      final page = await showDialog(
        context: context,
        builder: (_) => _FullscreenPdfView(
          pdfDocument: widget.pdfDocument,
          pageController: widget.pageController,
        ),
      );
      if (page != null) {
        widget.pageController.jumpToPage(page);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buttonArea = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PageInputField(
          pageController: widget.pageController,
          pageInputController: widget.pageInputController,
          pageCount: widget.pageCount,
        ),
        _ZoomInputField(
          photoViewController: widget.photoViewController,
          scaleInputController: widget.scaleInputController,
          pdfSize: widget.pdfSize,
        ),
        _FullscreenButton(
          isFullscreen: widget.isFullscreen,
          onPressed: () => _onTapFullscreenButton(context),
        ),
      ],
    );
    if (width < 290) {
      buttonArea = SingleChildScrollView(
          scrollDirection: Axis.horizontal, child: buttonArea);
    }
    return Positioned(
      top: 0,
      height: _toolBoxHeight,
      width: width,
      child: Opacity(
        opacity: .9,
        child: Container(
          color: Theme.of(context).primaryColor,
          child: buttonArea,
        ),
      ),
    );
  }
}

class _PageInputField extends StatelessWidget {
  const _PageInputField({
    Key? key,
    required this.pageController,
    required this.pageInputController,
    required this.pageCount,
  }) : super(key: key);

  final PageController pageController;
  final TextEditingController pageInputController;
  final int? pageCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          onEditingComplete: () {
            final page = int.tryParse(pageInputController.text);
            if (page == null) {
              return;
            }
            final num newPage = (page - 1).clamp(0, pageCount!);
            pageController.jumpToPage(newPage as int);
          },
        ),
      ),
    );
  }
}

class _ZoomInputField extends StatelessWidget {
  const _ZoomInputField({
    Key? key,
    required this.photoViewController,
    required this.scaleInputController,
    required this.pdfSize,
  }) : super(key: key);

  final PhotoViewController photoViewController;
  final TextEditingController scaleInputController;
  final Size pdfSize;

  Widget _zoomButton(bool zoom) {
    final icon = zoom ? Icons.zoom_in : Icons.zoom_out;
    final disable = zoom
        ? photoViewController.scale! >= _maxScale
        : photoViewController.scale! <= _minScale;
    return IconButton(
      icon: Icon(icon),
      onPressed: disable
          ? null
          : () {
              const interval = .1;
              final nowValue = photoViewController.scale;
              final roundValue =
                  (zoom ? (nowValue! * 10).ceil() : (nowValue! * 10).floor()) /
                      10;
              final separateValue =
                  zoom ? nowValue + interval : nowValue - interval;
              final newValue =
                  roundValue != nowValue ? roundValue : separateValue;
              photoViewController.scale = newValue.clamp(_minScale, _maxScale);
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _zoomButton(false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: 48,
            child: TextField(
              maxLength: 3,
              controller: scaleInputController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9]')),
              ],
              decoration: const InputDecoration(
                suffixText: '%',
                counter: SizedBox.shrink(),
                contentPadding: EdgeInsets.all(0),
              ),
              onEditingComplete: () {
                final scale = int.tryParse(scaleInputController.text);
                if (scale == null) {
                  return;
                }
                photoViewController.scale =
                    (scale / 100).clamp(_minScale, _maxScale);
              },
            ),
          ),
        ),
        _zoomButton(true),
      ],
    );
  }
}

class _PdfView extends StatelessWidget {
  const _PdfView({
    Key? key,
    required this.pdfDocument,
    required this.pageController,
    required this.photoViewController,
    required this.photoViewScaleStateController,
    required this.pageInputController,
    required this.setPdfInfo,
    required this.isFullscreen,
    required this.pdfMargin,
    required this.initialScale,
    required this.viewSize,
  }) : super(key: key);

  final PdfDocument pdfDocument;
  final PageController pageController;
  final PhotoViewController photoViewController;
  final TextEditingController pageInputController;
  final PhotoViewScaleStateController photoViewScaleStateController;
  final void Function(Size pdfSize, int? pageCount) setPdfInfo;
  final bool isFullscreen;
  final Offset pdfMargin;
  final double initialScale;
  final Size viewSize;

  @override
  Widget build(BuildContext context) {
    final getPdfImage = (int pageNumber) async {
      final page = await pdfDocument.getPage(pageNumber);
      setPdfInfo(
        Size(page.width!.toDouble(), page.height!.toDouble()),
        pdfDocument.pagesCount,
      );
      return await page.render(
        width: page.width! * _pdfSizeMagnification,
        height: page.height! * _pdfSizeMagnification,
      );
    };
    return PhotoViewGallery.builder(
      builder: (context, index) => PhotoViewGalleryPageOptions.customChild(
        disableGestures: true,
        child: FutureBuilder<PdfPageImage?>(
          future: getPdfImage(index + 1),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final pdfData = snapshot.data!;
              final scale = photoViewController.scale ?? 1;
              final pdfSize =
                  Size(pdfData.width!.toDouble(), pdfData.height!.toDouble()) *
                      scale;
              final pagingButtonWidth = pdfSize.shortestSide * .2;
              final annotations = pdfData.annotations;
              return Stack(
                alignment: Alignment.center,
                children: [
                  PhotoView(
                    controller: photoViewController,
                    scaleStateController: photoViewScaleStateController,
                    imageProvider: MemoryImage(pdfData.bytes, scale: .5),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    filterQuality: FilterQuality.high,
                    initialScale: initialScale,
                    minScale: _minScale,
                    maxScale: _maxScale,
                  ),
                  _PagingButton(
                    height: pdfSize.height,
                    width: pagingButtonWidth,
                    isNext: false,
                    pageController: pageController,
                    hPosition: (pdfMargin.dx - pagingButtonWidth)
                        .clamp(double.minPositive, viewSize.width),
                    visible: viewSize.width > 580,
                  ),
                  _PagingButton(
                    height: pdfSize.height,
                    width: pagingButtonWidth,
                    isNext: true,
                    pageController: pageController,
                    hPosition: (pdfMargin.dx - pagingButtonWidth)
                        .clamp(double.minPositive, viewSize.width),
                    visible: viewSize.width > 580,
                  ),
                  if (!(pdfMargin.dx.isNaN || pdfMargin.dy.isNaN) &&
                      annotations != null)
                    _AnnotationLayer(
                      annotations: annotations,
                      scale: scale,
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
    Key? key,
    required this.annotations,
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
                  final url = annotation.url!;
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
    Key? key,
    this.height,
    this.width,
    required this.isNext,
    required this.pageController,
    this.hPosition,
    this.visible = true,
  }) : super(key: key);
  final double? height, width;
  final bool isNext;
  final PageController pageController;
  final double? hPosition;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final paging =
        isNext ? pageController.nextPage : pageController.previousPage;
    final begin =
        isNext ? FractionalOffset.centerLeft : FractionalOffset.centerRight;
    final end =
        isNext ? FractionalOffset.centerRight : FractionalOffset.centerLeft;
    final icon = isNext ? Icons.navigate_next : Icons.navigate_before;
    final pagingAction = () => paging(
          duration: _pagingDuration,
          curve: Curves.ease,
        );
    return Positioned(
      right: isNext ? hPosition : null,
      left: isNext ? null : hPosition,
      child: visible
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: begin,
                  end: end,
                  colors: [
                    Colors.transparent,
                    Theme.of(context).cardColor.withOpacity(0.1),
                  ],
                  stops: const [0, 1],
                ),
              ),
              height: height,
              width: width,
              child: TextButton(
                child: Icon(
                  icon,
                  size: 32,
                ),
                onPressed: pagingAction,
              ),
            )
          : SizedBox(
              width: width,
              height: height,
              child: GestureDetector(onTap: pagingAction),
            ),
    );
  }
}

class _FullscreenButton extends StatelessWidget {
  const _FullscreenButton({
    Key? key,
    required this.isFullscreen,
    required this.onPressed,
  }) : super(key: key);

  final bool isFullscreen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: IconButton(
        icon: Icon(
          isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _FullscreenPdfView extends StatelessWidget {
  const _FullscreenPdfView({
    Key? key,
    required this.pdfDocument,
    required this.pageController,
  }) : super(key: key);

  final Future<PdfDocument> pdfDocument;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<_PdfViewerState>();
    final scrollController = ScrollController();
    return Scaffold(
      body: WillPopScope(
        onWillPop: () async {
          final page = key.currentState?.pageController.page?.toInt();
          if (page != null) {
            pageController.jumpToPage(page);
          }
          return true;
        },
        child: Center(
          child: SingleChildScrollView(
            controller: scrollController,
            child: PdfViewer._fullscreen(
              key: key,
              pdfDocument: pdfDocument,
              pageController: PageController(
                  initialPage: pageController.page?.toInt() ?? 0),
              scrollController: scrollController,
              // minHeight: MediaQuery.of(context).size.height,
            ),
          ),
        ),
      ),
    );
  }
}

extension _RectEx on Rect {
  Rect operator *(double multiple) => Rect.fromLTRB(
        left * multiple,
        top * multiple,
        right * multiple,
        bottom * multiple,
      );
}
