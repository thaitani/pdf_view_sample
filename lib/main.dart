import 'package:flutter/material.dart';
import 'package:native_pdf_view/native_pdf_view.dart';
import 'package:pdf_view/pdf/pdf_viewer.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      darkTheme: ThemeData.dark(),
      theme: ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: Text('test'),
        ),
        body: SingleChildScrollView(
          child: Card(
            child: PdfViewer(
              pdfDocument: PdfDocument.openAsset('assets/tmp.pdf'),
            ),
          ),
        ),
      ),
    );
  }
}
