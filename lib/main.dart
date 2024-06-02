import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clear Shot',
      home: ImagePickerDemo(),
    );
  }
}

class ImagePickerDemo extends StatefulWidget {
  @override
  _ImagePickerDemoState createState() => _ImagePickerDemoState();
}

class _ImagePickerDemoState extends State<ImagePickerDemo> {
  TextEditingController _urlController = TextEditingController();
  File? _image;
  img.Image? _blendedImage;
  final picker = ImagePicker();
  double _sliderValue = 0.5;

  @override
  void initState() {
    super.initState();
    _urlController.text = 'http://frp-fly.top:57409/upload/'; // Initialize URL text field
    //http://10.37.36.216:8000/upload/
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<void> _uploadImage() async {
    if (_image == null || _urlController.text.isEmpty) {
      return;
    }

    var url = Uri.parse(_urlController.text);
    var request = http.MultipartRequest('POST', url);
    request.headers['accept'] = 'application/json';
    request.headers['Content-Type'] = 'multipart/form-data';

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      _image!.path,
    ));

    request.fields['sliderValue'] = _sliderValue.toString();

    var response = await request.send();
    if (response.statusCode == 200) {
      http.Response res = await http.Response.fromStream(response);
      Uint8List responseData = res.bodyBytes;
      _blendImages(responseData);
      _showSnackBar('Image uploaded and blended successfully');
    } else {
      _showSnackBar('Failed to upload image. Error code: ${response.statusCode}');
    }
  }

  void _blendImages(Uint8List responseData) {
    if (_image == null) {
      return;
    }

    img.Image image1 = img.decodeImage(_image!.readAsBytesSync())!;
    img.Image image2 = img.decodeImage(responseData)!;

    img.Image resizedImage2 = img.copyResize(image2, width: image1.width, height: image1.height);
    img.Image blendedImage = img.Image(image1.width, image1.height);

    for (int y = 0; y < image1.height; y++) {
      for (int x = 0; x < image1.width; x++) {
        int pixel1 = image1.getPixel(x, y);
        int pixel2 = resizedImage2.getPixel(x, y);

        int r1 = img.getRed(pixel1);
        int g1 = img.getGreen(pixel1);
        int b1 = img.getBlue(pixel1);
        int a1 = img.getAlpha(pixel1);

        int r2 = img.getRed(pixel2);
        int g2 = img.getGreen(pixel2);
        int b2 = img.getBlue(pixel2);
        int a2 = img.getAlpha(pixel2);

        int r = (r1 * _sliderValue + r2 * (1 - _sliderValue)).toInt();
        int g = (g1 * _sliderValue + g2 * (1 - _sliderValue)).toInt();
        int b = (b1 * _sliderValue + b2 * (1 - _sliderValue)).toInt();
        int a = (a1 * _sliderValue + a2 * (1 - _sliderValue)).toInt();

        blendedImage.setPixel(x, y, img.getColor(r, g, b, a));
      }
    }

    setState(() {
      _blendedImage = blendedImage;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ClearShot'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _image == null ? Text('No image selected.') : Image.file(_image!),
              SizedBox(height: 20),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Backend URL',
                  hintText: 'Enter backend URL',
                ),
              ),
              SizedBox(height: 20),
              Slider(
                value: _sliderValue,
                min: 0,
                max: 1,
                divisions: 100,
                label: _sliderValue.toStringAsFixed(2),
                onChanged: (double value) {
                  setState(() {
                    _sliderValue = value;
                    if (_blendedImage != null) {
                      _blendImages(Uint8List.fromList(img.encodePng(_blendedImage!)));
                    }
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Pick Image from Gallery'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _uploadImage,
                child: Text('Upload Image to Backend'),
              ),
              SizedBox(height: 20),
              _blendedImage == null
                  ? Text('No blended image.')
                  : Image.memory(Uint8List.fromList(img.encodePng(_blendedImage!))),
            ],
          ),
        ),
      ),
    );
  }
}
