// lib/core/services/camera_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — CAMERA LIFECYCLE MANAGER v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ injectBothControllers() stores front+back separately — zero-cost switching
// ✅ clearInjectedControllers() (plural) — fixes EvidenceService crash
// ✅ clearInjectedController() (singular alias) — backward compat
// ✅ _switchTo() uses injected controllers first, hardware fallback only
// ✅ fullDispose() clears injected refs WITHOUT disposing (SOS screen owns them)
// ✅ isDisposed guards on every notifyListeners() call
// ✅ Hardware mount only when no injection available
// ✅ Flash/exposure/focus configured on every mount
// ─────────────────────────────────────────────────────────────────────────────

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

enum CameraFacing { front, back }

enum CameraState {
  uninitialized,
  initializing,
  ready,
  recording,
  error,
}

class CameraManager extends ChangeNotifier {
  CameraManager._internal();
  static final CameraManager instance = CameraManager._internal();
  factory CameraManager() => instance;

  // ── Active controller (whichever facing is current) ──────────────────────
  CameraController? _controller;
  CameraController? get controller => _controller;

  // ── Injected controllers from SOS screen (owned by SOS screen) ──────────
  CameraController? _injectedBack;
  CameraController? _injectedFront;

  // ── Hardware camera descriptions ─────────────────────────────────────────
  List<CameraDescription> _cameras     = [];
  CameraDescription?      _frontCamera;
  CameraDescription?      _backCamera;

  CameraFacing _activeFacing         = CameraFacing.back;
  CameraFacing get activeFacing      => _activeFacing;

  bool _controllerIsInjected = false;
  bool _isMounting           = false;
  bool _isDisposed           = false;

  CameraState _state = CameraState.uninitialized;
  CameraState get state => _state;

  bool get isReady     => _state == CameraState.ready;
  bool get isRecording => _state == CameraState.recording;

  bool get hasFrontCamera =>
      _frontCamera != null || _injectedFront != null;
  bool get hasBackCamera  =>
      _backCamera  != null || _injectedBack  != null;
  bool get canSwitch      => hasFrontCamera && hasBackCamera;

  bool get hasController =>
      _controller != null && (_controller!.value.isInitialized);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  static const ResolutionPreset _backResolution  = ResolutionPreset.veryHigh;
  static const ResolutionPreset _frontResolution = ResolutionPreset.high;

  // ═══════════════════════════════════════════════════════════════════════════
  // INJECTION — SOS screen injects both cameras after initialization
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> injectBothControllers({
    required CameraController back,
    required CameraController front,
  }) async {
    _injectedBack          = back;
    _injectedFront         = front;
    _controller            = back;
    _activeFacing          = CameraFacing.back;
    _controllerIsInjected  = true;
    _state                 = CameraState.ready;
    debugPrint(
      '[CameraManager] Both controllers injected — '
          'back(veryHigh) + front(high)',
    );
    _safeNotify();
  }

  Future<void> injectBackController(CameraController ctrl) async {
    if (!_controllerIsInjected) {
      await _disposeOwnController();
    }
    _injectedBack         = ctrl;
    _controller           = ctrl;
    _activeFacing         = CameraFacing.back;
    _controllerIsInjected = true;
    _state                = CameraState.ready;
    debugPrint('[CameraManager] Back controller injected');
    _safeNotify();
  }

  /// Clear injected refs WITHOUT disposing — SOS screen owns the controllers.
  /// Called when SOS screen disposes its own controllers.
  void clearInjectedControllers() {
    if (!_controllerIsInjected) return;
    _injectedBack         = null;
    _injectedFront        = null;
    _controller           = null;
    _controllerIsInjected = false;
    _state                = CameraState.uninitialized;
    debugPrint('[CameraManager] Injected controllers cleared');
    _safeNotify();
  }

  /// Singular alias — backward compatibility with EvidenceService
  void clearInjectedController() => clearInjectedControllers();

  // ═══════════════════════════════════════════════════════════════════════════
  // HARDWARE INITIALIZATION (fallback when no injection available)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initialize({
    CameraFacing facing = CameraFacing.back,
  }) async {
    if (_isDisposed || _isMounting) return;
    if (_state == CameraState.initializing) return;
    _isDisposed = false;
    _setState(CameraState.initializing);
    try {
      final ok = await _ensureCamerasAvailable();
      if (!ok) return;
      await _mountController(facing);
    } catch (e) {
      _setError('Camera init failed: $e');
    }
  }

  Future<bool> _ensureCamerasAvailable() async {
    if (_cameras.isNotEmpty &&
        _frontCamera != null &&
        _backCamera  != null) {
      return true;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _setError('No cameras available on device');
        return false;
      }
      for (final cam in _cameras) {
        if (cam.lensDirection == CameraLensDirection.back) {
          _backCamera  ??= cam;
        }
        if (cam.lensDirection == CameraLensDirection.front) {
          _frontCamera ??= cam;
        }
      }
      return true;
    } catch (e) {
      _setError('Camera query failed: $e');
      return false;
    }
  }

  Future<void> _mountController(CameraFacing facing) async {
    if (_isMounting || _isDisposed) return;
    _isMounting = true;
    try {
      await _disposeOwnController();
      final ok = await _ensureCamerasAvailable();
      if (!ok) return;

      final desc   = facing == CameraFacing.back
          ? (_backCamera  ?? _cameras.first)
          : (_frontCamera ?? _cameras.first);
      final preset = facing == CameraFacing.back
          ? _backResolution
          : _frontResolution;

      final ctrl = CameraController(
        desc,
        preset,
        enableAudio:      true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();

      try { await ctrl.setFlashMode(FlashMode.off);        } catch (_) {}
      try { await ctrl.setExposureMode(ExposureMode.auto); } catch (_) {}
      try { await ctrl.setFocusMode(FocusMode.auto);       } catch (_) {}

      if (_isDisposed) {
        await ctrl.dispose();
        return;
      }

      _controller           = ctrl;
      _activeFacing         = facing;
      _controllerIsInjected = false;
      _setState(CameraState.ready);
      debugPrint(
        '[CameraManager] Hardware ${facing.name.toUpperCase()} mounted ($preset)',
      );
    } catch (e) {
      _setError('Mount failed (${facing.name}): $e');
    } finally {
      _isMounting = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CAMERA SWITCHING — uses injected controllers first (zero hardware cost)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> switchCamera() async {
    if (_isMounting || _isDisposed) return false;
    final next = _activeFacing == CameraFacing.back
        ? CameraFacing.front
        : CameraFacing.back;
    await _switchTo(next);
    return isReady;
  }

  Future<bool> switchToFront() async {
    if (_activeFacing == CameraFacing.front && isReady && hasController) {
      return true;
    }
    if (_isMounting || _isDisposed) return false;
    await _switchTo(CameraFacing.front);
    return isReady;
  }

  Future<bool> switchToBack() async {
    if (_activeFacing == CameraFacing.back && isReady && hasController) {
      return true;
    }
    if (_isMounting || _isDisposed) return false;
    await _switchTo(CameraFacing.back);
    return isReady;
  }

  Future<void> _switchTo(CameraFacing facing) async {
    // ── PRIMARY: Use injected controllers — instant, zero hardware cost ───
    if (_controllerIsInjected) {
      if (facing == CameraFacing.back && _injectedBack != null) {
        _controller   = _injectedBack;
        _activeFacing = CameraFacing.back;
        _state        = CameraState.ready;
        _safeNotify();
        debugPrint('[CameraManager] Switched to injected BACK');
        return;
      }
      if (facing == CameraFacing.front && _injectedFront != null) {
        _controller   = _injectedFront;
        _activeFacing = CameraFacing.front;
        _state        = CameraState.ready;
        _safeNotify();
        debugPrint('[CameraManager] Switched to injected FRONT');
        return;
      }
    }

    // ── FALLBACK: Mount from hardware ─────────────────────────────────────
    final ok = await _ensureCamerasAvailable();
    if (!ok) return;
    await _mountController(facing);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> lockOrientation() async {
    if (!hasController || _isDisposed) return;
    try { await _controller!.lockCaptureOrientation(); } catch (_) {}
  }

  Future<void> setZoomLevel(double zoom) async {
    if (!hasController || _isDisposed) return;
    try {
      final min = await _controller!.getMinZoomLevel();
      final max = await _controller!.getMaxZoomLevel();
      await _controller!.setZoomLevel(zoom.clamp(min, max));
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPOSAL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _disposeOwnController() async {
    if (_controller == null || _controllerIsInjected) return;
    try {
      if (_controller!.value.isRecordingVideo) {
        await _controller!.stopVideoRecording();
      }
      await _controller!.dispose();
    } catch (e) {
      debugPrint('[CameraManager] Dispose warning: $e');
    } finally {
      _controller = null;
    }
  }

  Future<void> fullDispose() async {
    _isDisposed = true;
    await _disposeOwnController();
    // Clear injected refs WITHOUT disposing — SOS screen owns them
    _injectedBack  = null;
    _injectedFront = null;
    _setState(CameraState.uninitialized);
  }

  void _setState(CameraState s) {
    if (_isDisposed) return;
    _state        = s;
    _errorMessage = null;
    _safeNotify();
  }

  void _setError(String msg) {
    if (_isDisposed) return;
    _state        = CameraState.error;
    _errorMessage = msg;
    debugPrint('[CameraManager] ERROR: $msg');
    _safeNotify();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    fullDispose();
    super.dispose();
  }
}