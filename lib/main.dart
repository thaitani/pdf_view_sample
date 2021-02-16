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
      home: _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  @override
  __HomeState createState() => __HomeState();
}

class __HomeState extends State<_Home> {
  bool pdf = true;
  final scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('test'),
      ),
      body: Builder(
        builder: (context) => SingleChildScrollView(
          controller: scrollController,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: PdfViewer(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  pdfDocument: PdfDocument.openAsset(
                      pdf ? 'assets/tmp.pdf' : 'assets/tmp2.pdf'),
                  scrollController: scrollController,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.replay),
        onPressed: () {
          setState(() {
            pdf = !pdf;
          });
        },
      ),
    );
  }
}
