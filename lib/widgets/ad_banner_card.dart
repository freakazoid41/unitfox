import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ads_config.dart';
import '../theme.dart';

class AdBannerCard extends StatefulWidget {
  const AdBannerCard({super.key});

  @override
  State<AdBannerCard> createState() => _AdBannerCardState();
}

class _AdBannerCardState extends State<AdBannerCard> with WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _adLoaded = false;
  bool _adFailed = false;
  Timer? _retryTimer;
  Timer? _refreshTimer;
  int _retryCount = 0;

  static const _maxRetries = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_adLoaded && mounted) {
      debugPrint('AdMob banner: app resumed, retrying');
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    // Exponential backoff: 5, 10, 20, 30, 30s
    final delay = Duration(seconds: [5, 10, 20, 30, 30][_retryCount.clamp(0, 4)]);
    _retryTimer = Timer(delay, () {
      if (!mounted) return;
      _retryCount++;
      setState(() => _adFailed = false);
      _loadAd();
    });
    debugPrint('AdMob banner retry #$_retryCount in ${delay.inSeconds}s');
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    // AdMob recommends 30–60s refresh; we refresh the BannerAd instance
    _refreshTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted) return;
      debugPrint('AdMob banner refresh');
      _bannerAd?.dispose();
      _bannerAd = null;
      _adLoaded = false;
      _loadAd();
    });
  }

  void _loadAd() {
    if (!AdsConfig.enabled) return;

    // Dispose any stale instance before creating a new load.
    _bannerAd?.dispose();
    _bannerAd = null;

    final adUnitId = AdsConfig.bannerAdUnitId;
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdMob banner loaded: $adUnitId');
          if (!mounted) return;
          _retryTimer?.cancel();
          setState(() {
            _adLoaded = true;
            _adFailed = false;
          });
          _retryCount = 0;
          _scheduleRefresh();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob banner failed: ${error.message} (code=${error.code})');
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _adFailed = true;
          });
          _scheduleRetry();
        },
      ),
    );

    unawaited(_bannerAd!.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _refreshTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdsConfig.enabled) return const SizedBox.shrink();

    if (_adLoaded && _bannerAd != null) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppBrand.gradient[0].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'AD',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppBrand.gradient[0],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sponsored',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          if (!_adFailed)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Icon(Icons.open_in_new, size: 14, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
