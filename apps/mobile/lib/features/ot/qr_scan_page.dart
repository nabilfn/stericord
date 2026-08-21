import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/ot/point_of_use_verify_page.dart';
import 'package:stericord_mobile/features/packs/pack_repository.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> with SingleTickerProviderStateMixin {
  static const _frameSize = 250.0;

  final _controller = MobileScannerController();
  final _packRepository = PackRepository();
  late final AnimationController _scanLineController;
  bool _handling = false;
  bool _torchOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null || code.isEmpty) return;
    await _resolveCode(code);
  }

  Future<void> _resolveCode(String code) async {
    setState(() {
      _handling = true;
      _error = null;
    });
    await _controller.stop();

    try {
      final pack = await _packRepository.findPackByCode(code);
      if (pack == null) {
        setState(() => _error = 'No pack found for that code.');
        return;
      }
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PointOfUseVerifyPage(packId: pack.id)),
        );
      }
    } catch (e) {
      debugPrint('Pack lookup error: $e');
      setState(() => _error = 'Could not look up that pack. Try again.');
    } finally {
      if (mounted) {
        setState(() => _handling = false);
        await _controller.start();
      }
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  Future<void> _enterCodeManually() async {
    final controller = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          top: AppSpacing.xxl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enter pack code', style: AppTypography.sectionHeader),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Type the code printed on the pack if the QR can't be scanned.",
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Pack code'),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Look up pack'),
            ),
          ],
        ),
      ),
    );
    if (code != null && code.isNotEmpty) {
      await _resolveCode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Scan pack'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          const IgnorePointer(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(frameSize: _frameSize),
              child: SizedBox.expand(),
            ),
          ),
          Center(
            child: SizedBox(
              width: _frameSize,
              height: _frameSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.panel),
                child: AnimatedBuilder(
                  animation: _scanLineController,
                  builder: (context, _) => CustomPaint(
                    painter: _ScanLinePainter(progress: _scanLineController.value),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.xl,
            child: const Column(
              children: [
                Text(
                  'Align the QR code inside the frame',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.xxxl,
            child: Column(
              children: [
                if (_handling) const CircularProgressIndicator(color: Colors.white),
                if (_error != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                TextButton.icon(
                  onPressed: _enterCodeManually,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Enter code manually'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark translucent backdrop with a rounded-rect cut-out for the scan
/// frame, plus a bright border tracing the cut-out (redesign prompt
/// section 19: "full-screen camera, dark translucent overlay, clear
/// scanning frame, rounded corners").
class _ScannerOverlayPainter extends CustomPainter {
  final double frameSize;
  const _ScannerOverlayPainter({required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final backdrop = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final center = Offset(size.width / 2, size.height / 2);
    final frameRect = Rect.fromCenter(center: center, width: frameSize, height: frameSize);
    final frameRRect = RRect.fromRectAndRadius(frameRect, const Radius.circular(AppRadius.panel));

    final backdropPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(frameRRect);
    final overlayPath = Path.combine(PathOperation.difference, backdropPath, holePath);
    canvas.drawPath(overlayPath, backdrop);

    final borderPaint = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(frameRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) => oldDelegate.frameSize != frameSize;
}

/// A subtle animated line sweeping the height of the scan frame.
class _ScanLinePainter extends CustomPainter {
  final double progress;
  const _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.teal.withValues(alpha: 0), AppColors.teal, AppColors.teal.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, y - 1, size.width, 2));
    canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) => oldDelegate.progress != progress;
}
