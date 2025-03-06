import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key, required this.camera});

  final CameraDescription camera;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  bool _isPreviewVisible = true;
  String? _capturedImagePath;
  String _predictionResult = "Processing...";

  // initialize the interpreter variable
  Interpreter? interpreter;

  // Use a future to track model loading status
  late Future<void> _modelLoadingFuture;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Create a future that we can await in the UI
    _modelLoadingFuture = _loadModel();
  }

  void _initializeCamera() {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> _loadModel() async {
    try {
      // Initialize interpreter options
      final options = InterpreterOptions();

      // Attempt to load the model
      print("Loading model from assets/model.tflite...");
      interpreter =
          await Interpreter.fromAsset('assets/model.tflite', options: options);

      // Print model input and output shapes for debugging
      var inputTensor = interpreter!.getInputTensors()[0];
      var outputTensor = interpreter!.getOutputTensors()[0];
      print("✅ Model input shape: ${inputTensor.shape}");
      print("✅ Model output shape: ${outputTensor.shape}");
    } catch (e) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    interpreter?.close(); // close interpreter
    super.dispose();
  }

  int findMaxIndex(List<double> values) {
    double maxValue = -double.infinity;
    int maxIndex = 0;
    for (int j = 0; j < values.length; j++) {
      if (values[j] > maxValue) {
        maxValue = values[j];
        maxIndex = j;
      }
    }
    return maxIndex;
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      //  ensure model is loaded
      await _modelLoadingFuture;

      final image = await _controller.takePicture();
      setState(() {
        _capturedImagePath = image.path;
        _isPreviewVisible = false;
        _predictionResult = "Analyzing...";
      });

      await _predictSoilType(image.path);
    } catch (e) {
      setState(() {
        _predictionResult = "❌ Error capturing image: $e";
      });
      print("❌ Error capturing image: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker _picker = ImagePicker();
      // Pick an image from the gallery
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        setState(() {
          _predictionResult = "❌ No image selected.";
        });
        return;
      }

      setState(() {
        _capturedImagePath = image.path;
        _isPreviewVisible = false;
        _predictionResult = "Analyzing...";
      });

      await _predictSoilType(_capturedImagePath!);
    } catch (e) {
      setState(() {
        _predictionResult = "❌ Error picking image: $e";
      });
      print("❌ Error picking image: $e");
    }
  }

  Future<void> _predictSoilType(String imagePath) async {
    if (interpreter == null) {
      setState(() {
        _predictionResult = "❌ Error: Model not initialized";
      });
      print("❌ Error: Model is not initialized");
      return;
    }

    try {
      // Get model input and output tensors
      var inputTensor = interpreter!.getInputTensors()[0];
      var outputTensor = interpreter!.getOutputTensors()[0];

      // Get the shapes as List<int>
      List<int> inputShape = inputTensor.shape;
      List<int> outputShape = outputTensor.shape;

      print("✅ Processing with input shape: $inputShape");
      print("✅ Processing with output shape: $outputShape");

      // Determine input dimensions from the model
      int inputHeight = inputShape[1]; // Should be 256
      int inputWidth = inputShape[2]; // Should be 256
      int inputChannels = inputShape[3]; // Should be 3

      print(
          "✅ Using input dimensions: $inputHeight x $inputWidth x $inputChannels");

      // Load and preprocess the image
      File imageFile = File(imagePath);
      img.Image? image = img.decodeImage(await imageFile.readAsBytes());

      if (image == null) {
        setState(() {
          _predictionResult = "❌ Error: Could not decode image";
        });
        return;
      }

      // Resize to match the model's expected input dimensions (256x256)
      img.Image resized =
          img.copyResize(image, width: inputWidth, height: inputHeight);

      // Create correctly shaped input tensor
      // For a [1, 256, 256, 3] input shape
      var inputBytes =
          List<double>.filled(32 * inputHeight * inputWidth * inputChannels, 0);

      // Fill the input data with normalized RGB values
      int inputIndex = 0;
      for (int y = 0; y < inputHeight; y++) {
        for (int x = 0; x < inputWidth; x++) {
          final pixel = resized.getPixel(x, y);
          // Normalize to 0-1 range
          inputBytes[inputIndex++] = pixel.r / 255.0;
          inputBytes[inputIndex++] = pixel.g / 255.0;
          inputBytes[inputIndex++] = pixel.b / 255.0;
        }
      }

      // Reshape the flat input array to the model's input shape
      var inputBuffer = inputBytes.reshape(inputShape);

      // Create output buffer with the correct shape
      // For [32, 4] output shape
      var outputBuffer = List<double>.filled(outputShape[0] * outputShape[1], 0)
          .reshape(outputShape);

      // Run inference
      print("✅ Running inference...");
      interpreter!.run(inputBuffer, outputBuffer);
      print("✅ Inference complete");

      // After inference, print the raw output for debugging
      print("Model output: $outputBuffer");

      // Process the output based on your model's specific output format
      // The output shape [32, 4] suggests 32 predictions with 4 values each

      //take values from ooutput buffer to array
      List<double> predictions = [];
      for (int i = 0; i < outputShape[1]; i++) {
        predictions.add(outputBuffer[0][i]);
      }

      //find most confident prediction
      double maxConfidence = 0;
      int bestClassIndex = 0;

      for (int i = 1; i < predictions.length; i++) {
        if (predictions[i] > maxConfidence) {
          maxConfidence = predictions[i];
          bestClassIndex = i;
        }
      }

      // Convert the prediction to a meaningful result
      String soilType;
      if (bestClassIndex == 0) {
        soilType = "Black Soil - Suitable for Vegetables";
      } else if (bestClassIndex == 1) {
        soilType = "Clay Soil - Retains Water Well";
      } else if (bestClassIndex == 2) {
        soilType = "Red Soil - good for very few crops";
      } else if (bestClassIndex == 3) {
        soilType = "Alluvual soil - good for growing crops ";
      } else {
        soilType = "the index is unaccounted for";
      }

      setState(() {
        _predictionResult =
            "$soilType (Confidence: ${(maxConfidence * 100).toStringAsFixed(1)}%)";
      });

      print("✅ Prediction: $_predictionResult");
    } catch (e) {
      setState(() {
        _predictionResult = "❌ Error in prediction: $e";
      });
      print("❌ Error in prediction: $e");

      // Additional debugging
      try {
        var inputTensor = interpreter!.getInputTensors()[0];
        var outputTensor = interpreter!.getOutputTensors()[0];
        print("⚠️ Model expects input shape: ${inputTensor.shape}");
        print("⚠️ Model expects output shape: ${outputTensor.shape}");
      } catch (e2) {
        print("⚠️ Couldn't get tensor shapes: $e2");
      }
    }
  }

  void _clearImage() {
    setState(() {
      _capturedImagePath = null;
      _isPreviewVisible = true;
      _predictionResult = "Processing...";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 30),
            child: Text(
              "Take Picture",
              style: TextStyle(
                  color: Colors.black38,
                  fontWeight: FontWeight.bold,
                  fontSize: 22),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
          ),
          Expanded(
            child: Center(
              child: _capturedImagePath != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 320,
                          height: 420,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(_capturedImagePath!),
                                fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _predictionResult, // Display prediction
                          style: const TextStyle(
                              fontSize: 20,
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 25),
                        GestureDetector(
                          onTap: _clearImage,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.lightBlueAccent.withOpacity(0.6),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Text(
                              "Clear Image",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _isPreviewVisible
                      ? FutureBuilder<void>(
                          future: _initializeControllerFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 75),
                                child: Container(
                                  width: 350,
                                  height: 380,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: Colors.blueGrey, width: 2),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: CameraPreview(_controller),
                                  ),
                                ),
                              );
                            } else {
                              return const CircularProgressIndicator();
                            }
                          },
                        )
                      : const Text("Camera Preview Off"),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _pickImage, // Change to pick image from gallery
            heroTag: "gallery",
            backgroundColor: Colors.white30,
            child: const Icon(Icons.image), // Update icon if desired
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _takePicture,
            heroTag: "capture",
            backgroundColor: Colors.white30,
            child: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }
}
