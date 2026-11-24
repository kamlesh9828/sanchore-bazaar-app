import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

/// Responsive AdMob banner with bounded automatic retries.
/// Retries use increasing delays to avoid repeatedly requesting ads too fast.
class AdMobBanner extends StatefulWidget {
  final ValueChanged<bool>? onAdLoaded;
  const AdMobBanner({super.key, this.onAdLoaded});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner>
    with WidgetsBindingObserver {
  BannerAd? _banner;
  Timer? _retryTimer;
  bool _loaded = false;
  bool _loading = false;
  String? _debugError;
  int _retryAttempt = 0;

  static const List<Duration> _retryDelays = <Duration>[
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
    Duration(seconds: 180),
    Duration(minutes: 5),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBanner();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_loaded &&
        !_loading &&
        _retryTimer == null) {
      _loadBanner();
    }
  }

  void _scheduleRetry() {
    if (!mounted || _retryTimer != null) return;
    final int index = _retryAttempt < _retryDelays.length
        ? _retryAttempt
        : _retryDelays.length - 1;
    final Duration delay = _retryDelays[index];
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (mounted && !_loaded && !_loading) _loadBanner();
    });
  }

  Future<void> _loadBanner({bool manualRetry = false}) async {
    if (kIsWeb || _banner != null || _loading || !mounted) return;
    if (_retryTimer != null && !manualRetry) return;
    if (manualRetry) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }

    final String adUnitId = AdMobService.bannerAdUnitId;
    if (adUnitId.isEmpty) {
      if (kDebugMode) {
        setState(() => _debugError =
            'इस प्लेटफ़ॉर्म के लिए AdMob Ad Unit ID सेट नहीं है।');
      }
      return;
    }

    _loading = true;
    if (mounted) setState(() => _debugError = null);

    try {
      final int width = MediaQuery.sizeOf(context).width.truncate();
      final AdSize? size =
          await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      if (!mounted || size == null) {
        _loading = false;
        if (mounted) {
          if (kDebugMode) {
            setState(() => _debugError =
                'इस स्क्रीन के लिए विज्ञापन आकार उपलब्ध नहीं है।');
          }
          _scheduleRetry();
        }
        return;
      }

      late final BannerAd ad;
      ad = BannerAd(
        adUnitId: adUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad loadedAd) {
            if (!mounted) {
              loadedAd.dispose();
              return;
            }
            _retryTimer?.cancel();
            _retryTimer = null;
            _retryAttempt = 0;
            setState(() {
              _banner = ad;
              _loaded = true;
              _loading = false;
              _debugError = null;
            });
            widget.onAdLoaded?.call(true);
          },
          onAdFailedToLoad: (Ad failedAd, LoadAdError error) {
            failedAd.dispose();
            if (!mounted) return;
            setState(() {
              if (identical(_banner, ad)) _banner = null;
              _loaded = false;
              _loading = false;
              _debugError =
                  'विज्ञापन लोड नहीं हुआ (${error.code}): ${error.message}';
            });
            _scheduleRetry();
          },
        ),
      );
      _banner = ad;
      await ad.load();
    } catch (error) {
      _banner?.dispose();
      _banner = null;
      _loading = false;
      if (mounted) {
        setState(() {
          _loaded = false;
          _debugError = 'AdMob त्रुटि: $error';
        });
        _scheduleRetry();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _retryTimer = null;
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    if (_loaded && _banner != null) {
      return Container(
        alignment: Alignment.center,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: _banner!.size.width.toDouble(),
          height: _banner!.size.height.toDouble(),
          child: AdWidget(ad: _banner!),
        ),
      );
    }
    if (kDebugMode && _debugError != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
            child: Text(_debugError!, style: const TextStyle(fontSize: 11)),
          ),
          IconButton(
            tooltip: 'विज्ञापन फिर से लोड करें',
            onPressed: _loading
                ? null
                : () {
                    _banner?.dispose();
                    _banner = null;
                    _loaded = false;
                    _loadBanner(manualRetry: true);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }
}
