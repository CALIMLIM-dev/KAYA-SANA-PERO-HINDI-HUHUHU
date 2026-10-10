import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/navigation/main_navigation.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../data/services/api_client.dart';
import '../../../providers/app_mode_provider.dart';

/*
    The photo carousel under Active on home.

    Two kinds of slide take turns:
      - banners the admin runs (Home Banners in the panel): their own photo,
        a headline and where a tap goes;
      - boosted workers, for a hirer, and boosted jobs, for a worker: drawn
        over a stock photo of the trade, with the person's own photo only as
        a small avatar - a selfie cannot carry a banner, a trade photo can.
    With neither, it takes no room on home.

    The stock photos are CC0, from StockSnap; see assets/images/trades.
*/
class HomeCarousel extends StatefulWidget {
  const HomeCarousel({super.key, required this.side, this.seed});

  /// 'worker' or 'employer': which side's banners and ads to show.
  final String side;

  /// Slides to show instead of asking the server, for a test.
  @visibleForTesting
  final List<Map<String, dynamic>>? seed;

  /// Which side's carousel an account sees: jobs for someone looking for
  /// work, workers for a hirer.
  static String sideFor(AppModeProvider mode) =>
      mode.effectiveMode.showsEmployerSide &&
              !(mode.effectiveMode.showsWorkerSide && mode.hasWorkerProfile)
          ? 'employer'
          : 'worker';

  /// The last answer for each side, so home opens with it already there.
  static final Map<String, List<Map<String, dynamic>>> _cache = {};

  /*
      Asked during the opening animation, so the carousel is on screen the
      moment home is, rather than appearing a beat later and pushing the
      rest of home down. Errors are left for the carousel's own load.
  */
  static Future<void> prefetch(String side) async {
    try {
      _cache[side] = await _fetch(side);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> _fetch(String side) async {
    final res = await ApiClient().get('/home/featured', queryParameters: {'side': side});
    final data = res.data['data'] as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(String key) => ((data[key] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    final banners = rows('banners').map((m) => {...m, 'kind': 'banner'}).toList();
    final ads = rows('ads');

    // Banners and ads take turns, so neither crowds the other out.
    final merged = <Map<String, dynamic>>[];
    for (var i = 0; i < banners.length || i < ads.length; i++) {
      if (i < banners.length) merged.add(banners[i]);
      if (i < ads.length) merged.add(ads[i]);
    }
    return merged;
  }

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  final PageController _pages = PageController();
  List<_Slide> _slides = const [];
  int _index = 0;
  Timer? _timer;

  static List<_Slide> _toSlides(List<Map<String, dynamic>> rows) =>
      rows.map((m) => m['kind'] == 'banner' ? _Slide.banner(m) : _Slide.ad(m)).toList();

  @override
  void initState() {
    super.initState();
    final seed = widget.seed;
    if (seed != null) {
      _slides = _toSlides(seed);
      return;
    }
    _slides = _toSlides(HomeCarousel._cache[widget.side] ?? const []);
    _load();
  }

  @override
  void didUpdateWidget(HomeCarousel old) {
    super.didUpdateWidget(old);
    if (old.side != widget.side && widget.seed == null) {
      _slides = _toSlides(HomeCarousel._cache[widget.side] ?? const []);
      _index = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /*
      Only what the admin runs and what has been boosted.

      There used to be built-in sample banners for when nothing had been
      added yet. With nothing to show, the carousel takes no room at all.
  */
  Future<void> _load() async {
    final side = widget.side;
    try {
      final rows = await HomeCarousel._fetch(side);
      HomeCarousel._cache[side] = rows;
      if (!mounted || side != widget.side) return;
      setState(() {
        _slides = _toSlides(rows);
        _index = 0;
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
      _restartTimer();
    } catch (_) {
      // Offline: whatever was cached stays.
    }
  }

  /// Moves on every six seconds; not at all with Remove animations on.
  void _restartTimer() {
    _timer?.cancel();
    if (Motion.reduced(context) || _slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pages.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _pages.animateToPage(next, duration: const Duration(milliseconds: 420), curve: Motion.enter);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          // Wide, but never shorter than its words: at a large text size a
          // fixed shape clipped the second line.
          SizedBox(
            height: math.max(
              (MediaQuery.sizeOf(context).width - 32) / 2.3,
              MediaQuery.textScalerOf(context).scale(136),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: NotificationListener<ScrollStartNotification>(
                // A swipe by hand restarts the clock rather than fighting it.
                onNotification: (n) {
                  if (n.dragDetails != null) _restartTimer();
                  return false;
                },
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
                ),
              ),
            ),
          ),
          if (_slides.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: Motion.standard,
                    curve: Motion.enter,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.primary : AppColors.neutral300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _Kind { banner, worker, job }

class _Slide {
  _Slide._(this.kind, this.data);

  factory _Slide.banner(Map<String, dynamic> m) => _Slide._(_Kind.banner, m);
  factory _Slide.ad(Map<String, dynamic> m) =>
      _Slide._(m['kind'] == 'worker' ? _Kind.worker : _Kind.job, m);

  final _Kind kind;
  final Map<String, dynamic> data;
}

/// The CC0 photo for a trade, or the general one.
String tradePhoto(String? category) {
  final c = (category ?? '').toLowerCase();
  const map = {
    'electric': 'electrical',
    'carpent': 'carpentry',
    'paint': 'painting',
    'clean': 'cleaning',
    'landscap': 'landscaping',
    'garden': 'landscaping',
    'roof': 'roofing',
    'construct': 'construction',
    'mason': 'construction',
    'plumb': 'tools',
    'hvac': 'tools',
    'aircon': 'tools',
    'automotive': 'tools',
    'appliance': 'tools',
  };
  for (final e in map.entries) {
    if (c.contains(e.key)) return 'assets/images/trades/${e.value}.jpg';
  }
  return 'assets/images/trades/workshop.jpg';
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  void _open(BuildContext context) {
    final d = slide.data;
    switch (slide.kind) {
      case _Kind.worker:
        AppRouter.push(context, AppRouter.workerProfile, arguments: {'workerId': d['user_id']});
      case _Kind.job:
        AppRouter.push(context, AppRouter.jobDetails, arguments: {'jobId': d['id']});
      case _Kind.banner:
        switch (d['action']) {
          case 'post_job':
            AppRouter.push(context, AppRouter.postJob);
          case 'search_workers':
            AppRouter.push(context, AppRouter.searchJobs, arguments: {'searchType': 'Workers'});
          case 'search_jobs':
            AppRouter.push(context, AppRouter.searchJobs, arguments: {'searchType': 'Jobs'});
          case 'verify':
            AppRouter.push(context, '/verification');
          case 'top_up':
            AppRouter.push(context, AppRouter.wallet);
          case 'community':
            MainNavigation.openTab(context, MainNavigation.communityTab);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = slide.data;
    final Widget photo = switch (slide.kind) {
      _Kind.banner => CachedNetworkImage(
          imageUrl: '${d['image_url']}',
          fit: BoxFit.cover,
          placeholder: (_, _) => const ColoredBox(color: AppColors.neutral200),
          errorWidget: (_, _, _) => Image.asset(tradePhoto(null), fit: BoxFit.cover),
        ),
      _Kind.worker || _Kind.job => Image.asset(tradePhoto(d['category'] as String?), fit: BoxFit.cover),
    };

    /*
        A designed banner: its words are in the picture, so it is shown as
        it was made - no headline over it and no darkening.
    */
    final photoOnly = slide.kind == _Kind.banner &&
        '${d['title'] ?? ''}'.trim().isEmpty &&
        '${d['body'] ?? ''}'.trim().isEmpty;
    if (photoOnly) {
      return GestureDetector(onTap: () => _open(context), child: SizedBox.expand(child: photo));
    }

    return GestureDetector(
      onTap: () => _open(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo,
          // Dark on the side the words sit, clear where the photo shows.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xE6101828), Color(0x99101828), Color(0x10101828)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: switch (slide.kind) {
              _Kind.worker => _workerAd(d),
              _Kind.job => _jobAd(d),
              _ => _headline(d['title'], d['body']),
            },
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
      );

  Widget _headline(Object? title, Object? body) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FractionallySizedBox(
            widthFactor: 0.72,
            child: Text('${title ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          if ((body ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            FractionallySizedBox(
              widthFactor: 0.72,
              child: Text('$body',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, height: 1.3, color: Color(0xE6FFFFFF))),
            ),
          ],
        ],
      );

  Widget _workerAd(Map<String, dynamic> d) {
    final rating = (d['rating_avg'] as num?)?.toDouble();
    final facts = [
      if ((d['category'] ?? '').toString().isNotEmpty) d['category'],
      if ((d['location'] ?? '').toString().isNotEmpty) d['location'],
    ].join('  ·  ');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tag('Boosted'),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: ProfileAvatar(imageUrl: d['avatar'] as String?, name: '${d['name'] ?? ''}', radius: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${d['name'] ?? 'Worker'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  if (facts.isNotEmpty)
                    Text(facts,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rating != null) ...[
              const Icon(Icons.star_rounded, size: 15, color: AppColors.accent),
              const SizedBox(width: 3),
              Text('${rating.toStringAsFixed(1)} (${d['rating_count']})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(width: 10),
            ],
            if ((d['rate_label'] ?? '').toString().isNotEmpty)
              Text('${d['rate_label']}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Widget _jobAd(Map<String, dynamic> d) {
    final min = (d['budget_min'] as num?)?.toDouble();
    final max = (d['budget_max'] as num?)?.toDouble();
    final unit = {'daily': '/day', 'hourly': '/hr', 'project': ' per contract'}[d['budget_period']] ?? '';
    final pay = min == null && max == null
        ? null
        : '${_peso(min ?? max!)}${max != null && min != null && max != min ? ' - ${_peso(max)}' : ''}$unit';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tag('Hiring'),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.75,
          child: Text('${d['title'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(height: 6),
        Text(
          [?pay, if ((d['location'] ?? '').toString().isNotEmpty) d['location']].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    );
  }
}

/// "₱1,500" - whole pesos, grouped.
String _peso(double v) {
  final digits = v.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₱$grouped';
}
