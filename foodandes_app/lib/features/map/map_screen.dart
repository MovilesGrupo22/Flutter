import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/shared/widgets/custom_bottom_navbar.dart';

class MapScreen extends StatelessWidget {
  static const String routeName = '/map';

  const MapScreen({super.key});

  Widget _buildMarker(String rating, double left, double top) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Color(0xFFC84332),
          shape: BoxShape.circle,
        ),
        child: Text(
          rating,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      bottomNavigationBar: const CustomBottomNavbar(currentIndex: 1),
      body: Stack(
        children: [
          Container(
            color: const Color(0xFFF3EFE8),
            child: CustomPaint(
              size: Size.infinite,
              painter: _MapPainter(),
            ),
          ),
          Positioned(
            top: 90,
            left: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFF2B400),
                    child: Text('U'),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Universidad de los Andes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          _buildMarker('4.7', 95, 260),
          _buildMarker('4.5', 210, 170),
          _buildMarker('4.6', 240, 320),
          _buildMarker('4.8', 180, 470),
          Positioned(
            bottom: 32,
            right: 24,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {},
              child: const Icon(Icons.navigation, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFDCD4C9)
      ..strokeWidth = 1;

    final diagonalPaint = Paint()
      ..color = const Color(0xFFC8BEB1)
      ..strokeWidth = 10;

    for (double x = 0; x < size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = 0; y < size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (double y = 0; y < size.height; y += 160) {
      canvas.drawLine(
        Offset(0, y + 40),
        Offset(size.width, y + 140),
        diagonalPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}