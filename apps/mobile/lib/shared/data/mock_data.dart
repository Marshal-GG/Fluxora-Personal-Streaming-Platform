/// Mock fixtures for surfaces that don't yet have a server endpoint.
///
/// Phase A backfill (`docs/10_planning/08_real_data_backfill_plan.md` §9.2)
/// removed `MockData.recentlyAdded`, `MockData.findById`, the
/// `_details` rich-detail map, and the `MockGradients` class — those were
/// the symbols replaced by real `GET /files/recent`, `GET /files/{id}`,
/// and `GET /auth/clients/me` data.  Gradient placeholders moved to
/// `apps/mobile/lib/shared/widgets/gradients.dart` (`AppGradientPlaceholders`).
///
/// What's still here is everything Phase B / E delete next:
/// - `MockData.continueWatching` — `/clients/me/continue-watching` (Phase B)
/// - `MockData.trending` — search screen pool (Phase B trims this when
///   `/files/search` lands)
/// - `MockData.recentSearches` / `MockData.trendingSearches` — search
///   chrome until Phase B
/// - `MockData.downloads` + `storage{Used,Total}Gb` — downloads screen,
///   removed when Phase E ships (or when the Downloads tab is hidden in
///   v1 per decision §5 row 4, whichever comes first).
library;

import 'package:flutter/material.dart';
import 'package:fluxora_mobile/shared/widgets/gradients.dart';

class MockMediaItem {
  const MockMediaItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.gradient,
    this.imageUrl,
    this.progress,
    this.qualityBadge,
    this.kind = 'movie',
  });

  final String id;
  final String title;

  /// Year, episode, or duration string. Rendered under the title.
  final String subtitle;

  /// Fallback gradient shown when [imageUrl] is null or while loading.
  final Gradient gradient;

  final String? imageUrl;

  /// Resume progress 0.0–1.0. Only set on continue-watching rail.
  final double? progress;

  /// "4K" / "HDR" / "1080p". Rendered as a violet chip top-right.
  final String? qualityBadge;

  /// `'movie'` / `'show'` / `'music'` / `'photo'` / `'doc'` / `'person'`.
  final String kind;
}

enum MockDownloadStatus { downloading, completed }

class MockDownload {
  const MockDownload({
    required this.id,
    required this.title,
    required this.gradient,
    required this.size,
    required this.status,
    this.episodes,
    this.qualityBadge,
    this.speed,
    this.progress,
    this.expires,
  });

  final String id;
  final String title;
  final Gradient gradient;

  /// Display string. For downloading: "0.8 / 4.5 GB". For completed: "8.4 GB".
  final String size;

  final MockDownloadStatus status;

  /// Optional — only set on TV-show downloads.
  final String? episodes;

  /// Optional — "1080p", "4K", "HDR". Rendered next to size in the meta row.
  final String? qualityBadge;

  /// Only for [MockDownloadStatus.downloading]. e.g. "12.4 MB/s".
  final String? speed;

  /// Only for [MockDownloadStatus.downloading]. 0.0–1.0.
  final double? progress;

  /// Only for [MockDownloadStatus.completed]. e.g. "in 28 days" or "—".
  final String? expires;
}

class MockData {
  MockData._();

  static List<MockMediaItem> continueWatching = const [
    MockMediaItem(
      id: 'cw-1',
      title: 'Echoes of Tomorrow',
      subtitle: 'S2 · E4',
      gradient: AppGradientPlaceholders.violetCyan,
      progress: 0.62,
      qualityBadge: '4K',
      kind: 'show',
    ),
    MockMediaItem(
      id: 'cw-2',
      title: 'Nebula Run',
      subtitle: '1h 48m left',
      gradient: AppGradientPlaceholders.pinkAmber,
      progress: 0.34,
      qualityBadge: 'HDR',
    ),
    MockMediaItem(
      id: 'cw-3',
      title: 'The Last Signal',
      subtitle: 'S1 · E7',
      gradient: AppGradientPlaceholders.emeraldBlue,
      progress: 0.81,
      kind: 'show',
    ),
    MockMediaItem(
      id: 'cw-4',
      title: 'Aurora Drift',
      subtitle: '24m left',
      gradient: AppGradientPlaceholders.indigoCyan,
      progress: 0.92,
      qualityBadge: '1080p',
    ),
  ];

  static List<MockMediaItem> trending = const [
    MockMediaItem(
      id: 'tr-1',
      title: 'Velvet Horizon',
      subtitle: '2025',
      gradient: AppGradientPlaceholders.violetDeep,
      qualityBadge: '4K',
    ),
    MockMediaItem(
      id: 'tr-2',
      title: 'Quantum Drift',
      subtitle: '2024',
      gradient: AppGradientPlaceholders.emeraldBlue,
      qualityBadge: 'HDR',
    ),
    MockMediaItem(
      id: 'tr-3',
      title: 'Memory Vault',
      subtitle: '2025',
      gradient: AppGradientPlaceholders.pinkAmber,
    ),
    MockMediaItem(
      id: 'tr-4',
      title: 'Solar Tides',
      subtitle: '2024',
      gradient: AppGradientPlaceholders.amberRose,
      qualityBadge: '4K',
    ),
    MockMediaItem(
      id: 'tr-5',
      title: 'Glass Skies',
      subtitle: '2025',
      gradient: AppGradientPlaceholders.indigoCyan,
    ),
  ];

  static List<String> recentSearches = const [
    'velvet horizon',
    'memory vault',
    'aurora drift',
    'concrete sea',
  ];

  static List<String> trendingSearches = const [
    'sci-fi',
    '4K HDR',
    '2025 releases',
    'documentaries',
    'kids',
  ];

  // ── Downloads (mock) ──────────────────────────────────────────────────

  /// Combined storage indicator — used / total in GB.
  static const double storageUsedGb = 26.3;
  static const double storageTotalGb = 64.0;

  static List<MockDownload> downloads = const [
    MockDownload(
      id: 'dl-1',
      title: 'Velvet Horizon',
      gradient: AppGradientPlaceholders.violetDeep,
      size: '5.4 / 8.4 GB',
      status: MockDownloadStatus.downloading,
      qualityBadge: '4K',
      speed: '12.4 MB/s',
      progress: 0.64,
    ),
    MockDownload(
      id: 'dl-2',
      title: 'Echoes of Tomorrow',
      gradient: AppGradientPlaceholders.violetCyan,
      size: '0.8 / 4.5 GB',
      status: MockDownloadStatus.downloading,
      episodes: 'S1 E2',
      qualityBadge: 'HDR',
      speed: '8.1 MB/s',
      progress: 0.18,
    ),
    MockDownload(
      id: 'dl-3',
      title: 'Quantum Drift',
      gradient: AppGradientPlaceholders.emeraldBlue,
      size: '8.4 GB',
      status: MockDownloadStatus.completed,
      qualityBadge: '1080p',
      expires: 'in 28 days',
    ),
    MockDownload(
      id: 'dl-4',
      title: 'The Last Signal',
      gradient: AppGradientPlaceholders.emeraldBlue,
      size: '2.1 GB',
      status: MockDownloadStatus.completed,
      episodes: '5 of 10 eps',
      qualityBadge: '1080p',
      expires: 'in 12 days',
    ),
    MockDownload(
      id: 'dl-5',
      title: 'Solar Tides',
      gradient: AppGradientPlaceholders.amberRose,
      size: '11.2 GB',
      status: MockDownloadStatus.completed,
      qualityBadge: '4K',
      expires: 'in 30 days',
    ),
    MockDownload(
      id: 'dl-6',
      title: 'Aurora Drift',
      gradient: AppGradientPlaceholders.indigoCyan,
      size: '4.6 GB',
      status: MockDownloadStatus.completed,
      episodes: 'all eps',
      qualityBadge: '1080p',
      expires: '—',
    ),
  ];
}
