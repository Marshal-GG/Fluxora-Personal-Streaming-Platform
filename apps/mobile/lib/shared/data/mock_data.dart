/// Mock data fixtures for the Discover surfaces (Home / Search /
/// Notifications) until the server exposes equivalent endpoints.
///
/// Library data already has a real backend (`LibraryRepository.getLibraries()`);
/// this file only mocks what the prototype calls "discover" content —
/// continue-watching rails, trending, recently-added, search suggestions,
/// notifications. Shapes mirror `FluxData` / `FluxData2` from
/// `docs/11_design/prototype/app/shared/data/`.
library;

import 'package:flutter/material.dart';

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
    this.year,
    this.rating,
    this.duration,
    this.synopsis,
    this.cast = const [],
    this.crew = const [],
    this.similarIds = const [],
    this.seasons,
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

  // ── M4 detail-screen fields (optional — only the items the user opens
  // need to fill these out). ──

  final String? year;
  final String? rating;
  final String? duration;
  final String? synopsis;
  final List<MockCastMember> cast;
  final List<MockCastMember> crew;

  /// IDs of related items rendered in the "Similar titles" rail.
  final List<String> similarIds;

  /// Only populated for `kind == 'show'`. List of seasons + their episodes.
  final List<MockSeason>? seasons;
}

class MockCastMember {
  const MockCastMember({
    required this.name,
    required this.role,
    required this.gradient,
  });

  final String name;
  final String role;
  final Gradient gradient;
}

class MockSeason {
  const MockSeason({
    required this.number,
    required this.episodes,
  });

  final int number;
  final List<MockEpisode> episodes;
}

class MockEpisode {
  const MockEpisode({
    required this.id,
    required this.title,
    required this.date,
    required this.duration,
    required this.gradient,
    this.progress,
  });

  final String id;
  final String title;
  final String date;
  final String duration;
  final Gradient gradient;
  final double? progress;
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

/// Static gradients matching the prototype's mock-data colour names.
class MockGradients {
  static const violetCyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA855F7), Color(0xFF22D3EE)],
  );
  static const pinkAmber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEC4899), Color(0xFFF59E0B)],
  );
  static const emeraldBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
  );
  static const violetDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFEC4899)],
  );
  static const indigoCyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
  );
  static const amberRose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  );
}

class MockData {
  MockData._();

  static List<MockMediaItem> continueWatching = const [
    MockMediaItem(
      id: 'cw-1',
      title: 'Echoes of Tomorrow',
      subtitle: 'S2 · E4',
      gradient: MockGradients.violetCyan,
      progress: 0.62,
      qualityBadge: '4K',
      kind: 'show',
    ),
    MockMediaItem(
      id: 'cw-2',
      title: 'Nebula Run',
      subtitle: '1h 48m left',
      gradient: MockGradients.pinkAmber,
      progress: 0.34,
      qualityBadge: 'HDR',
    ),
    MockMediaItem(
      id: 'cw-3',
      title: 'The Last Signal',
      subtitle: 'S1 · E7',
      gradient: MockGradients.emeraldBlue,
      progress: 0.81,
      kind: 'show',
    ),
    MockMediaItem(
      id: 'cw-4',
      title: 'Aurora Drift',
      subtitle: '24m left',
      gradient: MockGradients.indigoCyan,
      progress: 0.92,
      qualityBadge: '1080p',
    ),
  ];

  static List<MockMediaItem> trending = const [
    MockMediaItem(
      id: 'tr-1',
      title: 'Velvet Horizon',
      subtitle: '2025',
      gradient: MockGradients.violetDeep,
      qualityBadge: '4K',
    ),
    MockMediaItem(
      id: 'tr-2',
      title: 'Quantum Drift',
      subtitle: '2024',
      gradient: MockGradients.emeraldBlue,
      qualityBadge: 'HDR',
    ),
    MockMediaItem(
      id: 'tr-3',
      title: 'Memory Vault',
      subtitle: '2025',
      gradient: MockGradients.pinkAmber,
    ),
    MockMediaItem(
      id: 'tr-4',
      title: 'Solar Tides',
      subtitle: '2024',
      gradient: MockGradients.amberRose,
      qualityBadge: '4K',
    ),
    MockMediaItem(
      id: 'tr-5',
      title: 'Glass Skies',
      subtitle: '2025',
      gradient: MockGradients.indigoCyan,
    ),
  ];

  static List<MockMediaItem> recentlyAdded = const [
    MockMediaItem(
      id: 'ra-1',
      title: 'Polar Drift',
      subtitle: '2025 · added today',
      gradient: MockGradients.indigoCyan,
      qualityBadge: '4K',
    ),
    MockMediaItem(
      id: 'ra-2',
      title: 'Ember & Ash',
      subtitle: '2024 · added 2d ago',
      gradient: MockGradients.amberRose,
    ),
    MockMediaItem(
      id: 'ra-3',
      title: 'Concrete Sea',
      subtitle: '2025 · added 3d ago',
      gradient: MockGradients.violetCyan,
      qualityBadge: 'HDR',
    ),
    MockMediaItem(
      id: 'ra-4',
      title: 'Late Bloomer',
      subtitle: '2023 · added 5d ago',
      gradient: MockGradients.pinkAmber,
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

  /// Detail-rich variants for items the user can open. Keys match the
  /// `id` field on the basic fixtures above. Falls back to the basic item
  /// when no detail entry exists (see [findById]).
  static final Map<String, MockMediaItem> _details = {
    'cw-1': const MockMediaItem(
      id: 'cw-1',
      title: 'Echoes of Tomorrow',
      subtitle: 'S2 · E4 · Drama',
      gradient: MockGradients.violetCyan,
      progress: 0.62,
      qualityBadge: '4K',
      kind: 'show',
      year: '2025',
      rating: '8.7',
      duration: '52 min',
      synopsis:
          'A linguist deciphers a transmission from a future Earth, only '
          'to discover the message is addressed to her — and arrives at '
          'a moment that may already be too late to rewrite.',
      cast: [
        MockCastMember(
          name: 'Asha Verma',
          role: 'Maya',
          gradient: MockGradients.violetCyan,
        ),
        MockCastMember(
          name: 'Theo Park',
          role: 'Eli',
          gradient: MockGradients.pinkAmber,
        ),
        MockCastMember(
          name: 'Reni Asha',
          role: 'Dr. Sato',
          gradient: MockGradients.emeraldBlue,
        ),
        MockCastMember(
          name: 'Sam Whittier',
          role: 'Cmdr. Hale',
          gradient: MockGradients.amberRose,
        ),
      ],
      crew: [
        MockCastMember(
          name: 'Iris Vega',
          role: 'Showrunner',
          gradient: MockGradients.violetDeep,
        ),
        MockCastMember(
          name: 'Mei Chen',
          role: 'Director',
          gradient: MockGradients.indigoCyan,
        ),
      ],
      similarIds: ['tr-1', 'tr-3', 'ra-3'],
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            MockEpisode(
              id: 'cw-1-s1e1',
              title: 'Static',
              date: 'Sep 14, 2024',
              duration: '48 min',
              gradient: MockGradients.violetCyan,
            ),
            MockEpisode(
              id: 'cw-1-s1e2',
              title: 'Long Wave',
              date: 'Sep 21, 2024',
              duration: '46 min',
              gradient: MockGradients.violetDeep,
            ),
            MockEpisode(
              id: 'cw-1-s1e3',
              title: 'The Hour Stays',
              date: 'Sep 28, 2024',
              duration: '52 min',
              gradient: MockGradients.indigoCyan,
            ),
          ],
        ),
        MockSeason(
          number: 2,
          episodes: [
            MockEpisode(
              id: 'cw-1-s2e1',
              title: 'Aftershock',
              date: 'May 02, 2025',
              duration: '50 min',
              gradient: MockGradients.violetCyan,
              progress: 1.0,
            ),
            MockEpisode(
              id: 'cw-1-s2e2',
              title: 'Carrier',
              date: 'May 09, 2025',
              duration: '49 min',
              gradient: MockGradients.emeraldBlue,
              progress: 1.0,
            ),
            MockEpisode(
              id: 'cw-1-s2e3',
              title: 'Black Box',
              date: 'May 16, 2025',
              duration: '53 min',
              gradient: MockGradients.pinkAmber,
              progress: 1.0,
            ),
            MockEpisode(
              id: 'cw-1-s2e4',
              title: 'Echoes of Tomorrow',
              date: 'May 23, 2025',
              duration: '54 min',
              gradient: MockGradients.violetDeep,
              progress: 0.62,
            ),
          ],
        ),
      ],
    ),
    'tr-1': const MockMediaItem(
      id: 'tr-1',
      title: 'Velvet Horizon',
      subtitle: '2025 · Sci-fi',
      gradient: MockGradients.violetDeep,
      qualityBadge: '4K',
      kind: 'movie',
      year: '2025',
      rating: '8.2',
      duration: '2h 14m',
      synopsis:
          'When a long-range probe returns from the edge of the Kuiper '
          'belt carrying something that should not exist, a salvage crew '
          'must decide whether to bring it home — or burn it in transit.',
      cast: [
        MockCastMember(
          name: 'Naomi Sands',
          role: 'Captain Reyes',
          gradient: MockGradients.violetDeep,
        ),
        MockCastMember(
          name: 'Hugo Ito',
          role: 'Engineer Rao',
          gradient: MockGradients.indigoCyan,
        ),
        MockCastMember(
          name: 'Lior Gade',
          role: 'Dr. Marrow',
          gradient: MockGradients.amberRose,
        ),
      ],
      crew: [
        MockCastMember(
          name: 'Cass Holloway',
          role: 'Director',
          gradient: MockGradients.violetCyan,
        ),
      ],
      similarIds: ['tr-2', 'ra-1', 'tr-5'],
    ),
  };

  /// Look up an item by id. Falls back to the basic-fixture variant when
  /// no detail-rich entry exists.
  static MockMediaItem? findById(String id) {
    if (_details.containsKey(id)) return _details[id];
    final pool = [...continueWatching, ...trending, ...recentlyAdded];
    for (final m in pool) {
      if (m.id == id) return m;
    }
    return null;
  }

  // ── Downloads (mock) ──────────────────────────────────────────────────

  /// Combined storage indicator — used / total in GB.
  static const double storageUsedGb = 26.3;
  static const double storageTotalGb = 64.0;

  static List<MockDownload> downloads = const [
    MockDownload(
      id: 'dl-1',
      title: 'Velvet Horizon',
      gradient: MockGradients.violetDeep,
      size: '5.4 / 8.4 GB',
      status: MockDownloadStatus.downloading,
      qualityBadge: '4K',
      speed: '12.4 MB/s',
      progress: 0.64,
    ),
    MockDownload(
      id: 'dl-2',
      title: 'Echoes of Tomorrow',
      gradient: MockGradients.violetCyan,
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
      gradient: MockGradients.emeraldBlue,
      size: '8.4 GB',
      status: MockDownloadStatus.completed,
      qualityBadge: '1080p',
      expires: 'in 28 days',
    ),
    MockDownload(
      id: 'dl-4',
      title: 'The Last Signal',
      gradient: MockGradients.emeraldBlue,
      size: '2.1 GB',
      status: MockDownloadStatus.completed,
      episodes: '5 of 10 eps',
      qualityBadge: '1080p',
      expires: 'in 12 days',
    ),
    MockDownload(
      id: 'dl-5',
      title: 'Solar Tides',
      gradient: MockGradients.amberRose,
      size: '11.2 GB',
      status: MockDownloadStatus.completed,
      qualityBadge: '4K',
      expires: 'in 30 days',
    ),
    MockDownload(
      id: 'dl-6',
      title: 'Aurora Drift',
      gradient: MockGradients.indigoCyan,
      size: '4.6 GB',
      status: MockDownloadStatus.completed,
      episodes: 'all eps',
      qualityBadge: '1080p',
      expires: '—',
    ),
  ];
}
