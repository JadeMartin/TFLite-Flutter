import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
//import 'package:image/image.dart';

void main(){
  runApp(MyApp());
}

const String mobilenet = 'mobilenet';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TfliteHome(),
    );
  }
}

class TfliteHome extends StatefulWidget {
  @override
  _TfliteHomeState createState() => _TfliteHomeState();
}

class _TfliteHomeState extends State<TfliteHome> {
  File _image;
  double _imageWidth;
  double _imageHeight;
  bool _busy = false;
  final picker = ImagePicker();
  List _recognitions; 
  
  @override
  void initState() {
    super.initState();
    _busy = true;

    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try{
      String res;

      res = await Tflite.loadModel(
        model: "assets/tflite/ssd_mobilenet.tflite",
        labels: "assets/tflite/ssd_mobilenet.txt",
      );
      print(res);
    } on PlatformException{
      print("Failed to load tflite model");
    }
  }

  selectFromImagePicker() async {
    var image = await picker.getImage(source: ImageSource.gallery);
    if(image != null){
      setState(() {
        _busy = true;
      });
      predictImage(File(image.path));
    }
  }

  predictImage(File image) async {
    await mobileNet(image);

    FileImage(image).resolve(ImageConfiguration()).addListener(ImageStreamListener((ImageInfo info, bool _){
      setState(() {
        _imageWidth = info.image.height.toDouble();
        _imageHeight = info.image.height.toDouble();
      });
    }));

    setState(() {
      _image = image;
      _busy = false;
    });
  }

  mobileNet(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1
    );

    setState(() {
      _recognitions = recognitions;
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;

    Color blue = Colors.red;

    return _recognitions.map((re) {
      if(re["confidenceInClass"] >0.6) {
        return Positioned(
          left: re["rect"]["x"] * factorX,
          top: re["rect"]["y"] * factorY,
          width: re["rect"]["w"] * factorX,
          height: re["rect"]["h"] * factorY,
          child: Container(
            decoration: BoxDecoration(
                border: Border.all(
              color: blue,
              width: 3,
            )),
            child: Text(
              "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                background: Paint()..color = blue,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        );
      } else {
        return Container();
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {

    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];

    stackChildren.add(Positioned(
      top: 0.0,
      left: 0.0,
      width: size.width, 
      child: _image==null ? Text("No image selected") : Image.file(_image),
    ));

    stackChildren.addAll(renderBoxes(size));

    if(_busy){
      stackChildren.add(Center(child: CircularProgressIndicator(),));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('TFLite Example'),
      ),

      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.image),
        tooltip: "Pick Image from gallary",
        onPressed: selectFromImagePicker,
      ),

      body: Stack(
        children: stackChildren,
      ),
    );
  }
}