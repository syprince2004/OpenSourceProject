import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../services/detection_service.dart';
import '../widgets/detection_painter.dart';
import '../models/detection_result.dart';
import 'package:image/image.dart' as img;
import 'chat_screen.dart';
import '../utils/prompt_generator.dart';

class HomeScreen extends StatefulWidget {
  final CameraDescription? camera;
  const HomeScreen({super.key, this.camera});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  File? _image;
  final ImagePicker picker = ImagePicker();
  List<dynamic> _detections = []; // YOLO 서버에서 받은 원본 데이터
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.camera == null) return;

    _cameraController = CameraController(
      widget.camera!,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _cameraController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    }).catchError((e) {
      print("카메라 초기화 실패: $e");
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true; // 처리 시작
      _detections = []; // 이전 결과 초기화
    });

    try {
      final image = await _cameraController!.takePicture();

      // 이미지는 setState 밖에서 File 객체로만 만든다
      final imageFile = File(image.path);

      final result = await uploadImageToServer(imageFile, context);

      // 모든 통신이 끝난 후, 이미지와 결과를 한 번에 업데이트
      if (mounted) {
        setState(() {
          _image = imageFile;
          _detections = result;
        });
      }
    } catch (e) {
      print("사진 촬영/업로드 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('사진 처리에 실패했습니다.')));
      }
    } finally {
      // 성공하든 실패하든 처리가 끝나면 로딩 상태를 해제
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // 중복 클릭 방지
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true; // 처리 시작
      _detections = []; // 이전 결과 초기화
    });

    try {
      final XFile? picked = await picker.pickImage(source: source);
      if (!mounted || picked == null) {
        // 사용자가 선택을 취소한 경우, 로딩 상태를 다시 false로 되돌려줌
        setState(() => _isProcessing = false);
        return;
      }

      final imageFile = File(picked.path);

      // --- 리사이징 코드 ---
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception("이미지 디코딩 실패");
      final resizedImage = img.copyResize(image, width: 1080);
      final resizedImageBytes = img.encodeJpg(resizedImage, quality: 85);
      final tempDir = await Directory.systemTemp.createTemp();
      final resizedFile = await File('${tempDir.path}/resized_image.jpg')
          .writeAsBytes(resizedImageBytes);
      // --- 리사이징 끝 ---

      final result = await uploadImageToServer(resizedFile, context);

      // 모든 통신이 끝난 후, 이미지와 결과를 한 번에 업데이트
      if (mounted) {
        print('Detections from server: $result');
        setState(() {
          _image = resizedFile;
          _detections = result;
        });
      }
    } catch (e) {
      print("갤러리 이미지 선택/업로드 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('이미지를 불러오는 데 실패했습니다.')));
      }
    } finally {
      // 성공하든 실패하든 처리가 끝나면 로딩 상태를 해제
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<ui.Image> _getImageInfo(File file) async {
    final data = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Widget _buildDetectedImage() {
    if (_image == null) {
      return const Center(child: Text('촬영된 사진이 여기에 표시됩니다.'));
    }

    // Stack을 사용하여 이미지 위에 로딩 위젯을 겹쳐서 표시
    return Stack(
      alignment: Alignment.center,
      children: [
        // 기존 LayoutBuilder와 FutureBuilder 로직은 그대로 유지
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;

            return FutureBuilder<ui.Image>(
              future: _getImageInfo(_image!),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final originalWidth = snapshot.data!.width.toDouble();
                  final originalHeight = snapshot.data!.height.toDouble();

                  // 화면에 맞게 비율 유지하며 크기 조정
                  double displayWidth, displayHeight;
                  final imageRatio = originalWidth / originalHeight;
                  final containerRatio = maxWidth / maxHeight;

                  if (imageRatio > containerRatio) {
                    displayWidth = maxWidth;
                    displayHeight = maxWidth / imageRatio;
                  } else {
                    displayHeight = maxHeight;
                    displayWidth = maxHeight * imageRatio;
                  }

                  final scaleX = displayWidth / originalWidth;
                  final scaleY = displayHeight / originalHeight;

                  return Center(
                    child: SizedBox(
                      width: displayWidth,
                      height: displayHeight,
                      child: Stack(
                        children: [
                          Image.file(
                            _image!,
                            width: displayWidth,
                            height: displayHeight,
                            fit: BoxFit.fill,
                          ),
                          CustomPaint(
                            size: Size(displayWidth, displayHeight),
                            painter: DetectionPainter(
                              _detections,
                              scaleX: scaleX,
                              scaleY: scaleY,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            );
          },
        ),
        // _isProcessing이 true일 때만 화면 위에 반투명한 검은색 배경과 로딩 아이콘을 보여줌
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('객체를 탐지하고 있습니다...',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Check App'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 안내 문구
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '반갑습니다.\n깔끔한 방 정리를 돕겠습니다!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),

            const SizedBox(height: 12),
            // 버튼 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    // 처리 중일 때는 null을 전달하여 버튼을 비활성화
                    onPressed: _isProcessing ? null : _takePicture,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('사진 찍기'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    // 처리 중일 때는 null을 전달하여 버튼을 비활성화
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('갤러리에서 불러오기'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    // 처리 중일 때는 null을 전달하여 버튼을 비활성화
                    onPressed: _isProcessing ? null : _analyzeWithAI,
                    icon: const Icon(Icons.psychology),
                    label: const Text('AI 분석 요청 및 대화하기'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 카메라 프리뷰
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isCameraInitialized
                      ? CameraPreview(_cameraController!)
                      : const Center(child: Text('카메라 초기화 중...')),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 인식된 이미지 + 결과
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildDetectedImage(),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeWithAI() async {
    if (_detections.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 사진을 분석하여 객체를 탐지해주세요.')));
      return;
    }

    // 서버에서 받은 dynamic 리스트를 DetectionResult 객체 리스트로 파싱
    final parsedDetections = _detections
        .map((e) => DetectionResult.fromJson(e as Map<String, dynamic>))
        .toList();

    // PromptGenerator를 사용하여 첫 메시지 생성
    final initialMessage =
        PromptGenerator.createInitialMessage(parsedDetections);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(initialAnalysis: initialMessage),
      ),
    );
  }
}
