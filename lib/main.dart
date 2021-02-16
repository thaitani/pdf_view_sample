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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('test'),
      ),
      body: Builder(
        builder: (context) => SingleChildScrollView(
          child: Center(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: 1200,
              child: Card(
                child: PdfViewer(
                  pdfDocument: PdfDocument.openAsset(
                      pdf ? 'assets/tmp.pdf' : 'assets/tmp2.pdf'),
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
