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
import '../../../core/utils/json_parse.dart';

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

  /// Bumped whenever a fresh answer lands, so a carousel already on screen
  /// takes it up without being rebuilt.
  static final ValueNotifier<int> _changed = ValueNotifier(0);

  /*
      Asked during the opening animation, so the carousel is on screen the
      moment home is, rather than appearing a beat later and pushing the
      rest of home down. Errors are left for the carousel's own load.
  */
  static Future<void> prefetch(String side) async {
    try {
      _cache[side] = await _fetch(side);
      _changed.value++;
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

class _HomeCarouselState extends State<HomeCarousel> with WidgetsBindingObserver {
  final PageController _pages = PageController();
  List<_Slide> _slides = const [];
  int _index = 0;
  Timer? _timer;

  /*
      Asked again while home is up, not only when it was first built.

      Home stays mounted under the other tabs for the whole session, so a
      banner the admin added after the app opened never appeared until the
      app was closed and opened again. It is asked again on coming back to
      the app, every few minutes while home is showing, and on a pull to
      refresh (HomeCarousel.prefetch).
  */
  Timer? _refreshTimer;
  DateTime _loadedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _refreshEvery = Duration(minutes: 3);

  /*
      A banner made as a picture is shown whole.

      It was cropped into a strip 2.3 times as wide as it is tall - about
      165 points on most phones - so a poster with words near its edges
      lost them, and what was left was too small to read. Its own shape is
      read once the picture loads, and the carousel takes that height.
  */
  final Map<String, double> _ratios = {};

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
    _measure();
    _load();
    WidgetsBinding.instance.addObserver(this);
    HomeCarousel._changed.addListener(_adoptCache);
    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_loadedAt) > const Duration(seconds: 30)) {
      _load();
    }
  }

  /// A fresh answer that landed somewhere else - a pull to refresh on home.
  void _adoptCache() {
    if (!mounted || widget.seed != null) return;
    final rows = HomeCarousel._cache[widget.side];
    if (rows == null) return;
    _show(rows);
  }

  void _show(List<Map<String, dynamic>> rows) {
    setState(() {
      _slides = _toSlides(rows);
      _index = 0;
    });
    _measure();
    if (_pages.hasClients) _pages.jumpToPage(0);
    _restartTimer();
  }

  /// Reads the shape of each picture-only banner once it has loaded.
  void _measure() {
    for (final slide in _slides) {
      final url = slide.photoOnlyUrl;
      if (url == null || _ratios.containsKey(url)) continue;
      final stream = CachedNetworkImageProvider(url).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          stream.removeListener(listener);
          final w = info.image.width, h = info.image.height;
          if (!mounted || w == 0 || h == 0) return;
          setState(() => _ratios[url] = w / h);
        },
        onError: (_, _) => stream.removeListener(listener),
      );
      stream.addListener(listener);
    }
  }

  /// Width over height for the slide on screen.
  double? _ratioOf(int i) {
    if (i < 0 || i >= _slides.length) return null;
    final url = _slides[i].photoOnlyUrl;
    if (url == null) return null;
    // Kept between a long strip and a portrait poster, so neither a
    // sliver nor a whole screen.
    return _ratios[url]?.clamp(0.8, 3.2);
  }

  @override
  void didUpdateWidget(HomeCarousel old) {
    super.didUpdateWidget(old);
    if (old.side != widget.side && widget.seed == null) {
      _slides = _toSlides(HomeCarousel._cache[widget.side] ?? const []);
      _index = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
      _measure();
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
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    HomeCarousel._changed.removeListener(_adoptCache);
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
    if (widget.seed != null) return;
    try {
      final rows = await HomeCarousel._fetch(side);
      _loadedAt = DateTime.now();
      final same = _sameRows(HomeCarousel._cache[side], rows) && _slides.isNotEmpty;
      HomeCarousel._cache[side] = rows;
      if (!mounted || side != widget.side) return;
      // Asked again every few minutes: an unchanged answer leaves the
      // slide that is showing alone rather than jumping back to the first.
      if (same) return;
      _show(rows);
    } catch (_) {
      // Offline: whatever was cached stays.
    }
  }

  static bool _sameRows(List<Map<String, dynamic>>? a, List<Map<String, dynamic>> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['kind'] != b[i]['kind'] ||
          a[i]['id'] != b[i]['id'] ||
          a[i]['image_url'] != b[i]['image_url']) {
        return false;
      }
    }
    return true;
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
          // fixed shape clipped the second line. A picture-only banner takes
          // its own shape instead, so all of it shows.
          AnimatedContainer(
            duration: Motion.standard,
            curve: Motion.enter,
            height: _ratioOf(_index) != null
                ? (MediaQuery.sizeOf(context).width - 32) / _ratioOf(_index)!
                : math.max(
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

  /// The picture's address when this is a banner made as a picture - no
  /// headline, no text - and null for anything with words laid over it.
  String? get photoOnlyUrl {
    if (kind != _Kind.banner) return null;
    if ('${data['title'] ?? ''}'.trim().isNotEmpty) return null;
    if ('${data['body'] ?? ''}'.trim().isNotEmpty) return null;
    final url = '${data['image_url'] ?? ''}';
    return url.isEmpty ? null : url;
  }
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
    final photoOnly = slide.photoOnlyUrl != null;
    if (photoOnly) {
      // Contained, not cropped: the box already has the picture's shape,
      // and a picture outside the kept range is fitted whole rather than cut.
      return GestureDetector(
        onTap: () => _open(context),
        child: ColoredBox(
          color: AppColors.neutral100,
          child: SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: slide.photoOnlyUrl!,
              fit: BoxFit.contain,
              placeholder: (_, _) => const ColoredBox(color: AppColors.neutral200),
              errorWidget: (_, _, _) => Image.asset(tradePhoto(null), fit: BoxFit.cover),
            ),
          ),
        ),
      );
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
    final rating = asDoubleOrNull(d['rating_avg']);
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
    final min = asDoubleOrNull(d['budget_min']);
    final max = asDoubleOrNull(d['budget_max']);
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
