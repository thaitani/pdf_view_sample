import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_pdf_view/native_pdf_view.dart';
import 'package:photo_view/photo_view.dart';

const _pagingDuration = Duration(milliseconds: 750);
const _maxScaleMagnification = 2.0;

final _zoomState = GlobalKey<__ZoomSliderState>();

class PdfViewer extends StatefulWidget {
  const PdfViewer({
    Key key,
    this.initialPage = 1,
    this.height,
    @required this.pdfDocument,
  }) : super(key: key);

  final int initialPage;
  final Future<PdfDocument> pdfDocument;
  final double height;
  @override
  _PdfViewerState createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  PdfController _pdfController;
  TextEditingController _pageInputController;
  PhotoViewController _photoViewController;
  bool _isTextChange;
  bool _build = false;

  @override
  void initState() {
    _pdfController = PdfController(
      document: widget.pdfDocument,
      initialPage: widget.initialPage,
    );
    _pageInputController = TextEditingController();
    _photoViewController = PhotoViewController()
      ..outputStateStream.listen((value) {
        setState(() => _build = true);
      });
    _isTextChange = false;
    super.initState();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    _pageInputController.dispose();
    _photoViewController.dispose();
    super.dispose();
  }

  Widget _pageBuilder(
    PdfPageImage pageImage,
    bool isCurrentIndex,
    AnimationController animationController,
  ) {
    return PhotoView(
      key: Key(pageImage.hashCode.toString()),
      imageProvider: MemoryImage(pageImage.bytes),
      controller: _photoViewController,
      backgroundDecoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      maxScale: _zoomState.currentState?.maxScale,
      minScale: _zoomState.currentState?.minScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    const _loadingView = Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: _OperationArea(
            pageInputController: _pageInputController,
            pdfController: _pdfController,
            setIsTextChange: (isTextChange) =>
                setState(() => _isTextChange = isTextChange),
          ),
        ),
        Stack(
          alignment: Alignment.topCenter,
          children: [
            SizedBox(
              height: widget.height ?? MediaQuery.of(context).size.height * .8,
              child: PdfView(
                documentLoader: _loadingView,
                pageLoader: _loadingView,
                controller: _pdfController,
                pageBuilder: _pageBuilder,
                onDocumentLoaded: (document) {
                  _pageInputController.text = _pdfController.page.toString();
                  setState(() {});
                  // TODO(haitani): ライブラリのinitialPageが修正されたら削除
                  if (widget.initialPage != 1) {
                    Timer(const Duration(seconds: 1),
                        () => _pdfController.jumpToPage(widget.initialPage));
                  }
                },
                onPageChanged: (page) {
                  if (!_isTextChange) {
                    _pageInputController.text = page.toString();
                  }
                },
              ),
            ),
            if (_build)
              _ZoomSlider(
                key: _zoomState,
                photoViewController: _photoViewController,
              ),
          ],
        ),
      ],
    );
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
