import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/task_model.dart';

class PurityDetector {
  static Future<Purity> detect(File imageFile) async {
    final stopwatch = Stopwatch()..start();
    
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('无法解码图片');
    }

    final bv = _calculateBackgroundVariance(image);
    final ec = _calculateEdgeContinuity(image);
    final ps = _calculatePurityScore(bv, ec);
    
    stopwatch.stop();

    return Purity(
      ps: ps,
      bv: bv,
      ec: ec,
      tool: 'image_lib',
    );
  }

  static double _calculateBackgroundVariance(img.Image image) {
    final List<int> edgePixels = [];
    final width = image.width;
    final edgeThickness = min(width, image.height) ~/ 20;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < width; x++) {
        if (x < edgeThickness || x >= width - edgeThickness ||
            y < edgeThickness || y >= image.height - edgeThickness) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          final brightness = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
          edgePixels.add(brightness);
        }
      }
    }

    if (edgePixels.isEmpty) return 0;

    final mean = edgePixels.reduce((a, b) => a + b) / edgePixels.length;
    final variance = edgePixels
        .map((v) => pow(v - mean, 2))
        .reduce((a, b) => a + b) / edgePixels.length;

    return min(variance, 255.0);
  }

  static double _calculateEdgeContinuity(img.Image image) {
    final width = image.width;
    int continuousCount = 0;
    int totalCount = 0;

    final edgePixels = <int>[];
    for (int x = 0; x < width; x++) {
      final pixel = image.getPixel(x, 0);
      final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();
      edgePixels.add(brightness);
    }

    for (int i = 0; i < edgePixels.length - 1; i++) {
      totalCount++;
      if ((edgePixels[i] - edgePixels[i + 1]).abs() < 20) {
        continuousCount++;
      }
    }

    return totalCount > 0 ? continuousCount / totalCount : 0;
  }

  static double _calculatePurityScore(double bv, double ec) {
    final score = 100 - (bv * 0.2 + (1 - ec) * 50);
    return max(0, min(100, score));
  }
}

