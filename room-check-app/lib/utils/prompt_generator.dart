import '../models/detection_result.dart';

class PromptGenerator {
  // 다른 곳에서 객체 생성 없이 바로 호출할 수 있도록 static 메소드로 만들었음
  static String createInitialMessage(List<DetectionResult> detections) {
    final buffer = StringBuffer();

    buffer.writeln('방 사진을 분석한 결과는 다음과 같습니다:\n');

    for (var d in detections) {
      final confidence = (d.confidence * 100).toStringAsFixed(1);
      buffer.writeln(
        '- ${d.label} (신뢰도: $confidence%, 위치: x=${d.x.toStringAsFixed(1)}, y=${d.y.toStringAsFixed(1)}, 너비=${d.width.toStringAsFixed(1)}, 높이=${d.height.toStringAsFixed(1)})',
      );
    }

    buffer.writeln('\n1. 방의 전반적인 정리 상태, 어떤 물건부터 정리하는 것이 좋을지 우선순위를 알려주세요.');
    buffer.writeln('2. 각 물건을 어떻게 정리하면 좋을지 구체적인 방법을 알려주세요.');

    return buffer.toString();
  }
}
