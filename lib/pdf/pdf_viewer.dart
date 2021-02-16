import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_pdf_view/native_pdf_view.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

const _pagingDuration = Duration(milliseconds: 750);
const _maxScaleMagnification = 2.0;

class PdfViewer extends StatefulWidget {
  const PdfViewer({
    Key key,
    this.initialPage = 0,
    @required this.pdfDocument,
    this.width,
    this.height,
  }) : super(key: key);

  final int initialPage;
  final Future<PdfDocument> pdfDocument;
  final double width, height;
  @override
  _PdfViewerState createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  TextEditingController _pageInputController;
  PhotoViewController _photoViewController;
  PageController _pageController;
  double _scale = double.nan;
  Size _pdfSize = Size.zero;

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

  @override
  void initState() {
    _pageController = PageController(initialPage: widget.initialPage);
    _pageInputController = TextEditingController();
    _photoViewController = PhotoViewController()
      ..outputStateStream.listen((event) {
        scale = event.scale;
        print(event);
      });
    super.initState();
  }

  @override
  void dispose() {
    _pageInputController.dispose();
    _photoViewController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OptionalSizedChild(
        width: widget.width,
        height: widget.height,
        builder: (width, height) {
          print('max $width, $height');
          const pagingButtonWidth = 108.0;
          final pagingButtonHeight = pdfHeight.clamp(0, height);
          final pagingButtonPositionH =
              ((width - pdfWidth) / 2 - pagingButtonWidth).clamp(0, width);
          final pagingButtonPositionV =
              height > pdfHeight ? (height - pdfHeight) / 2 : 0;
          return Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              FutureBuilder<PdfDocument>(
                future: widget.pdfDocument,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final pdfDocument = snapshot.data;
                    return _PdfView(
                      pdfDocument: pdfDocument,
                      pageController: _pageController,
                      photoViewController: _photoViewController,
                      setPdfSize: (Size size) => pdfSize = size,
                    );
                  }
                  return const _LoadingView();
                },
              ),
              if (!_scale.isNaN) ...[
                Positioned(
                  top: pagingButtonPositionV,
                  left: pagingButtonPositionH,
                  child: _PagingButton(
                    height: pagingButtonHeight,
                    width: pagingButtonWidth,
                    isNext: false,
                    pageController: _pageController,
                  ),
                ),
                Positioned(
                  top: pagingButtonPositionV,
                  right: pagingButtonPositionH,
                  child: _PagingButton(
                    height: pagingButtonHeight,
                    width: pagingButtonWidth,
                    isNext: true,
                    pageController: _pageController,
                  ),
                ),
              ]
            ],
          );
        });
  }
}

class _OperationArea extends StatelessWidget {
  const _OperationArea({
    Key key,
    this.pdfController,
    this.pageInputController,
    this.setIsTextChange,
  }) : super(key: key);

  final PdfController pdfController;
  final TextEditingController pageInputController;
  final void Function(bool) setIsTextChange;

  Widget _pagingButton({bool nextPage}) {
    final paging =
        nextPage ? pdfController.nextPage : pdfController.previousPage;
    final icon = nextPage ? Icons.navigate_next : Icons.navigate_before;
    return SizedBox(
      height: 38,
      child: FlatButton(
        child: Icon(icon, size: 24),
        shape: const CircleBorder(),
        onPressed: () {
          setIsTextChange(false);
          paging(
            curve: Curves.ease,
            duration: _pagingDuration,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onPageTextChange = (value) {
      final intValue = int.tryParse(value);
      if (intValue == null) {
        return;
      }
      setIsTextChange(true);
      if (intValue > pdfController.pagesCount) {
        pdfController.jumpToPage(pdfController.pagesCount);
        pageInputController.text = pdfController.pagesCount.toString();
        pageInputController.selection =
            TextSelection.collapsed(offset: pageInputController.text.length);
      } else {
        pdfController.jumpToPage(intValue);
      }
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pagingButton(nextPage: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: 48,
            child: TextField(
              maxLength: 3,
              controller: pageInputController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9]')),
              ],
              decoration: InputDecoration(
                suffixText: '/ ${pdfController.pagesCount}',
                counter: const SizedBox.shrink(),
                contentPadding: const EdgeInsets.all(0),
              ),
              onChanged: onPageTextChange,
            ),
          ),
        ),
        _pagingButton(nextPage: true),
      ],
    );
  }
}

class _ZoomSlider extends StatefulWidget {
  const _ZoomSlider({
    Key key,
    this.photoViewController,
  }) : super(key: key);

  final PhotoViewController photoViewController;
  @override
  __ZoomSliderState createState() => __ZoomSliderState();
}

class __ZoomSliderState extends State<_ZoomSlider> {
  double _initialScale;
  double _opacity;

  double get maxScale => _initialScale * _maxScaleMagnification;
  double get minScale => _initialScale;

  final _onOpacity = .9;
  final _offOpacity = .3;

  void reset() {
    _initialScale = widget.photoViewController?.scale ?? .3;
  }

  @override
  void initState() {
    _opacity = _offOpacity;
    reset();
    super.initState();
  }

  Widget _zoomButton(bool zoom) {
    final icon = zoom ? Icons.zoom_in : Icons.zoom_out;
    return InkWell(
      child: Icon(
        icon,
        size: 24,
        color: Theme.of(context).colorScheme.background,
      ),
      onTap: () {
        final interval = _initialScale * .1;
        final nowValue = widget.photoViewController.scale;
        final newValue = zoom ? nowValue + interval : nowValue - interval;
        widget.photoViewController.scale = newValue.clamp(minScale, maxScale);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => setState(() {
        _opacity = _onOpacity;
      }),
      onExit: (event) => setState(() {
        _opacity = _offOpacity;
      }),
      child: Opacity(
        opacity: _opacity,
        child: Row(
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
                value: widget.photoViewController.scale,
                max: maxScale,
                min: minScale,
                onChanged: (value) {
                  widget.photoViewController.scale = value;
                },
              ),
            ),
            _zoomButton(true),
          ],
        ),
      ),
    );
  }
}

class _PdfView extends StatelessWidget {
  const _PdfView({
    Key key,
    this.pdfDocument,
    this.pageController,
    this.photoViewController,
    this.setPdfSize,
  }) : super(key: key);

  final PdfDocument pdfDocument;
  final PageController pageController;
  final PhotoViewController photoViewController;
  final void Function(Size pdfSize) setPdfSize;

  @override
  Widget build(BuildContext context) {
    final getPdfImage = (int pageNumber) async {
      final page = await pdfDocument.getPage(pageNumber);
      setPdfSize(Size(page.width.toDouble(), page.height.toDouble()));
      print('pdf ${page.width}, ${page.height}');
      return await page.render(
        width: page.width,
        height: page.height,
      );
    };
    return PhotoViewGallery.builder(
      builder: (BuildContext context, int index) {
        return PhotoViewGalleryPageOptions.customChild(
          child: FutureBuilder(
            future: getPdfImage(index + 1),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return PhotoView(
                  controller: photoViewController,
                  imageProvider: MemoryImage(snapshot.data.bytes),
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  filterQuality: FilterQuality.high,
                );
              }
              return const _LoadingView();
            },
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.contained * 2,
        );
      },
      itemCount: pdfDocument.pagesCount,
      loadingBuilder: (context, event) {
        return const _LoadingView();
      },
      backgroundDecoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      pageController: pageController,
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
  }) : super(key: key);
  final double height;
  final double width;
  final bool isNext;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final paging =
        isNext ? pageController.nextPage : pageController.previousPage;
    final begin =
        isNext ? FractionalOffset.centerLeft : FractionalOffset.centerRight;
    final end =
        isNext ? FractionalOffset.centerRight : FractionalOffset.centerLeft;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            Colors.transparent,
            Theme.of(context).cardColor.withOpacity(0.4),
          ],
          stops: const [0.0, 1],
        ),
      ),
      height: height,
      width: width,
      child: FlatButton(
        child: Icon(
          isNext ? Icons.navigate_next : Icons.navigate_before,
          size: 32,
        ),
        onPressed: () => paging(
          duration: _pagingDuration,
          curve: Curves.ease,
        ),
      ),
    );
  }
}

class _OptionalSizedChild extends StatelessWidget {
  const _OptionalSizedChild({
    @required this.width,
    @required this.height,
    @required this.builder,
  });

  final double width, height;
  final Widget Function(double, double) builder;

  @override
  Widget build(BuildContext context) {
    if (width != null && height != null) {
      return SizedBox(
        width: width,
        height: height,
        child: builder(width, height),
      );
    }
    return LayoutBuilder(
      builder: (context, dimens) {
        final w = width ?? dimens.maxWidth;
        final h = height ?? dimens.maxHeight;
        return SizedBox(
          width: w,
          height: h,
          child: builder(w, h),
        );
      },
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
