import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class RembgService {
  static Future<File> removeBackground(File inputFile) async {
    final bytes = await inputFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('无法解码图片');
    }

    final processed = await _advancedBackgroundRemoval(image);
    
    final tempDir = await getTemporaryDirectory();
    final outputPath = path.join(
      tempDir.path,
      'rembg_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodePng(processed));
    
    return outputFile;
  }

  static Future<img.Image> _advancedBackgroundRemoval(img.Image image) async {
    final result = img.Image(width: image.width, height: image.height);
    
    const edgeThreshold = 15;
    const colorThreshold = 45;
    
    final bgColor = _estimateBackgroundColor(image);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        final isEdge = (x < edgeThreshold || 
                       x >= image.width - edgeThreshold || 
                       y < edgeThreshold || 
                       y >= image.height - edgeThreshold);
        
        final colorDist = sqrt(
          pow(r - bgColor[0], 2) + 
          pow(g - bgColor[1], 2) + 
          pow(b - bgColor[2], 2)
        );
        
        final isSimilarToBg = colorDist < colorThreshold;
        
        if (isEdge || isSimilarToBg) {
          if (isSimilarToBg && !isEdge) {
            final alpha = (255 * (1 - min(colorDist / colorThreshold, 1.0))).toInt();
            result.setPixel(x, y, img.ColorRgba8(r, g, b, 255 - alpha));
          } else {
            result.setPixel(x, y, img.ColorRgba8(255, 255, 255, 0));
          }
        } else {
          result.setPixel(x, y, pixel);
        }
      }
    }
    
    return _refineMask(result);
  }

  static List<int> _estimateBackgroundColor(img.Image image) {
    final edgePixels = <List<int>>[];
    const sampleSize = 5;
    
    for (int i = 0; i < sampleSize; i++) {
      for (int j = 0; j < sampleSize; j++) {
        final x = (image.width * i / sampleSize).toInt();
        final y = (image.height * j / sampleSize).toInt();
        
        if (i == 0 || i == sampleSize - 1 || j == 0 || j == sampleSize - 1) {
          final pixel = image.getPixel(x, y);
          edgePixels.add([
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
          ]);
        }
      }
    }
    
    if (edgePixels.isEmpty) {
      return [255, 255, 255];
    }
    
    final avgR = edgePixels.map((p) => p[0]).reduce((a, b) => a + b) ~/ edgePixels.length;
    final avgG = edgePixels.map((p) => p[1]).reduce((a, b) => a + b) ~/ edgePixels.length;
    final avgB = edgePixels.map((p) => p[2]).reduce((a, b) => a + b) ~/ edgePixels.length;
    
    return [avgR, avgG, avgB];
  }

  static img.Image _refineMask(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final alpha = pixel.a.toInt();
        
        if (alpha > 0 && alpha < 255) {
          int neighborAlphaSum = 0;
          int count = 0;
          
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              
              final nx = x + dx;
              final ny = y + dy;
              
              if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
                final neighborPixel = image.getPixel(nx, ny);
                neighborAlphaSum += neighborPixel.a.toInt();
                count++;
              }
            }
          }
          
          final avgNeighborAlpha = count > 0 ? neighborAlphaSum ~/ count : alpha;
          final refinedAlpha = ((alpha + avgNeighborAlpha) / 2).toInt();
          
          result.setPixel(x, y, img.ColorRgba8(
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
            refinedAlpha,
          ));
        } else {
          result.setPixel(x, y, pixel);
        }
      }
    }
    
    return result;
  }
}

