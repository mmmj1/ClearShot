import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clear Shot',
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    });

    return Scaffold(
      body: Center(
        child: Text(
          'ClearShot',
          style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _children = [
    ImagePickerDemo(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Main',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
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
    _urlController.text = 'http://8.138.119.19:8000/upload/';
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
      _showSnackBar('请先选择图片并输入有效的URL');
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

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        http.Response res = await http.Response.fromStream(response);
        Uint8List responseData = res.bodyBytes;
        _blendImages(responseData);
        await _saveToHistory(responseData);
        if (mounted) {
          _showSnackBar('图片上传和混合成功');
        }
      } else {
        if (mounted) {
          _showSnackBar('图片上传失败. 错误代码: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('图片上传过程中发生错误: $e');
      }
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

  Future<void> _saveToHistory(Uint8List responseData) async {
    if (_image == null || _blendedImage == null) {
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final historyDir = Directory('${directory.path}/history');
      if (!await historyDir.exists()) {
        await historyDir.create();
      }
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final imageDir = Directory('${historyDir.path}/$timestamp');
      await imageDir.create();

      final originalImageFile = File('${imageDir.path}/original.png');
      final blendedImageFile = File('${imageDir.path}/blended.png');

      await originalImageFile.writeAsBytes(_image!.readAsBytesSync());
      await blendedImageFile.writeAsBytes(responseData);

      print('图片已保存到: ${imageDir.path}');
    } catch (e) {
      print('保存图片过程中发生错误: $e');
    }
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

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Directory> _directories = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final directory = await getTemporaryDirectory();
      final historyDir = Directory('${directory.path}/history');
      if (await historyDir.exists()) {
        final directories = historyDir
            .listSync()
            .where((entity) => entity is Directory)
            .map((entity) => entity as Directory)
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));

        setState(() {
          _directories = directories;
        });
      }
    } catch (e) {
      print('加载历史记录过程中发生错误: $e');
    }
  }

  void _openDetailScreen(Directory directory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(directory: directory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
      ),
      body: _directories.isEmpty
          ? Center(child: Text('No history available.'))
          : ListView.builder(
        itemCount: _directories.length,
        itemBuilder: (context, index) {
          final directory = _directories[index];
          final originalImageFile = File('${directory.path}/original.png');

          return FutureBuilder<Uint8List>(
            future: originalImageFile.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasData) {
                  return Container(
                    height: 150, // Increased height for each item
                    child: ListTile(
                      leading: Image.memory(snapshot.data!, width: 100, height: 100, fit: BoxFit.cover),
                      title: Text(directory.path.split('/').last),
                      onTap: () => _openDetailScreen(directory),
                    ),
                  );
                } else {
                  return Container(
                    height: 150, // Increased height for each item
                    child: ListTile(
                      leading: Icon(Icons.broken_image),
                      title: Text('Failed to load image'),
                    ),
                  );
                }
              } else {
                return Container(
                  height: 150, // Increased height for each item
                  child: ListTile(
                    leading: CircularProgressIndicator(),
                    title: Text('Loading...'),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class DetailScreen extends StatefulWidget {
  final Directory directory;

  DetailScreen({required this.directory});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isImageMaximized = false;

  @override
  Widget build(BuildContext context) {
    final originalImageFile = File('${widget.directory.path}/original.png');
    final blendedImageFile = File('${widget.directory.path}/blended.png');

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FutureBuilder<Uint8List>(
              future: originalImageFile.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData) {
                    return Image.memory(snapshot.data!, width: 200, height: 200, fit: BoxFit.cover);
                  } else {
                    return Icon(Icons.broken_image, size: 100);
                  }
                } else {
                  return CircularProgressIndicator();
                }
              },
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isImageMaximized = !_isImageMaximized;
                });
              },
              child: FutureBuilder<Uint8List>(
                future: blendedImageFile.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasData) {
                      return _isImageMaximized
                          ? Expanded(child: Image.memory(snapshot.data!))
                          : Image.memory(snapshot.data!, width: 200, height: 200, fit: BoxFit.cover);
                    } else {
                      return Icon(Icons.broken_image, size: 100);
                    }
                  } else {
                    return CircularProgressIndicator();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
