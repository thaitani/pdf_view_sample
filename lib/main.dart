import 'package:flutter/material.dart';
import 'package:pdf_view/pdf/pdf_viewer.dart';
import 'package:pdfx/pdfx.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      darkTheme: ThemeData.dark(useMaterial3: true),
      theme: ThemeData.light(useMaterial3: true),
      home: _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  @override
  __HomeState createState() => __HomeState();
}

class __HomeState extends State<_Home> {
  int pdfIndex = 0;
  final scrollController = ScrollController();
  final pdfNameList = [
    'assets/tmp.pdf',
    'assets/tmp2.pdf',
    'assets/tmp3.pdf',
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('test'),
      ),
      body: SingleChildScrollView(
        controller: scrollController,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: PdfViewer(
                  key: Key(pdfNameList[pdfIndex]),
                  pdfDocument: PdfDocument.openAsset(pdfNameList[pdfIndex]),
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
            final newIndex = pdfIndex + 1;
            pdfIndex = newIndex < pdfNameList.length ? newIndex : 0;
          });
        },
      ),
    );
  }
}
