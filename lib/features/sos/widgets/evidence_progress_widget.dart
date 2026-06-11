// lib/features/sos/widgets/evidence_progress_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// SAFEHER — EVIDENCE PROGRESS WIDGET v8.0
// ─────────────────────────────────────────────────────────────────────────────
// ✅ Binds to EvidenceOrchestrator.statusNotifier
// ✅ Binds to EvidenceUploadQueue.totalProgressNotifier
// ✅ Shows per-pipeline status: Audio / Photos / Video / GPS / Sensors
// ✅ Animated progress bar for upload queue
// ✅ Shows pending upload count from EvidenceUploadQueue
// ✅ Compact design for SOS screen bottom section
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/services/audio_evidence_service.dart';
import '../../../core/services/evidence/evidence_models.dart';
import '../../../core/services/evidence/evidence_orchestrator.dart';
import '../../../core/services/evidence/evidence_upload_queue.dart';
import '../../../core/services/photo_evidence_service.dart';
import '../../../core/services/video_evidence_service.dart';
import '../../../core/theme/app_colors.dart';

class EvidenceProgressWidget extends StatelessWidget {
  const EvidenceProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EvidenceSessionStatus>(
      valueListenable: EvidenceOrchestrator.instance.statusNotifier,
      builder: (_, status, __) {
        if (status == EvidenceSessionStatus.idle) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.sosRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _statusLabel(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  _UploadCountBadge(),
                ],
              ),
              const SizedBox(height: 10),

              // Pipeline status chips
              Row(
                children: [
                  _PipelineChip(
                    label: 'Audio',
                    listenable: AudioEvidenceService.instance.statusNotifier,
                    activeStatus: AudioEvidenceStatus.recording,
                    doneStatus: AudioEvidenceStatus.completed,
                    color: AppColors.secondary,
                    emoji: '🎙️',
                  ),
                  const SizedBox(width: 4),
                  _PipelineChip(
                    label: 'Photos',
                    listenable: PhotoEvidenceService.instance.statusNotifier,
                    activeStatus: PhotoEvidenceStatus.capturing,
                    doneStatus: PhotoEvidenceStatus.completed,
                    color: AppColors.warningAmber,
                    emoji: '📷',
                  ),
                  const SizedBox(width: 4),
                  _PipelineChip(
                    label: 'Video',
                    listenable: VideoEvidenceService.instance.statusNotifier,
                    activeStatus: VideoEvidenceStatus.recording,
                    doneStatus: VideoEvidenceStatus.completed,
                    color: const Color(0xFF7C4DFF),
                    emoji: '🎥',
                  ),
                  const SizedBox(width: 4),
                  // GPS always active during collection
                  _StaticChip(
                    label: 'GPS',
                    color: AppColors.safeGreen,
                    emoji: '📍',
                    isActive: status == EvidenceSessionStatus.collecting,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Upload progress bar
              _UploadProgressBar(),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(EvidenceSessionStatus s) {
    switch (s) {
      case EvidenceSessionStatus.starting:
        return 'Initializing evidence collection...';
      case EvidenceSessionStatus.collecting:
        return 'Evidence collection ACTIVE';
      case EvidenceSessionStatus.uploading:
        return 'Securing evidence to cloud...';
      case EvidenceSessionStatus.complete:
        return 'Evidence secured ✓';
      case EvidenceSessionStatus.failed:
        return 'Collection error — retrying...';
      default:
        return 'Evidence system ready';
    }
  }
}

// ─── Upload Count Badge ────────────────────────────────────────────────────────

class _UploadCountBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: EvidenceUploadQueue.instance.pendingCountNotifier,
      builder: (_, count, __) {
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.warningAmber.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.warningAmber.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            '$count uploading',
            style: const TextStyle(
              color: AppColors.warningAmber,
              fontFamily: 'Poppins',
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

// ─── Upload Progress Bar ──────────────────────────────────────────────────────

class _UploadProgressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: EvidenceUploadQueue.instance.totalProgressNotifier,
      builder: (_, progress, __) {
        if (progress <= 0) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uploading to secure storage',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontFamily: 'Poppins',
                    fontSize: 9,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppColors.safeGreen,
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.safeGreen,
                ),
                minHeight: 4,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Pipeline Chip ─────────────────────────────────────────────────────────────

class _PipelineChip<T> extends StatelessWidget {
  final String          label;
  final ValueNotifier<T> listenable;
  final T               activeStatus;
  final T               doneStatus;
  final Color           color;
  final String          emoji;

  const _PipelineChip({
    required this.label,
    required this.listenable,
    required this.activeStatus,
    required this.doneStatus,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ValueListenableBuilder<T>(
        valueListenable: listenable,
        builder: (_, status, __) {
          final isActive = status == activeStatus;
          final isDone   = status == doneStatus;
          final chipColor = isDone
              ? AppColors.safeGreen
              : isActive
              ? color
              : Colors.white.withValues(alpha: 0.20);

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: chipColor.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                isActive
                    ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    color: color,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  isDone ? '✓' : emoji,
                  style: TextStyle(fontSize: isDone ? 10 : 12),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: chipColor,
                    fontFamily: 'Poppins',
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Static Chip (GPS — no status enum) ──────────────────────────────────────

class _StaticChip extends StatelessWidget {
  final String label;
  final Color  color;
  final String emoji;
  final bool   isActive;

  const _StaticChip({
    required this.label,
    required this.color,
    required this.emoji,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = isActive ? color : Colors.white.withValues(alpha: 0.20);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: chipColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isActive
                ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                color: color,
                strokeWidth: 2,
              ),
            )
                : Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: chipColor,
                fontFamily: 'Poppins',
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}