import '../../core/location/location_service.dart';
import '../suppliers/models/supplier_models.dart';

/// Deterministic, explainable local recommendation algorithm (no paid AI APIs).
class LocalRecommendationEngine {
  static List<SupplierOfferModel> rankOffers({
    required List<SupplierOfferModel> offers,
    required int requestedCapacity,
    required double customerLat,
    required double customerLng,
    String sortBy = 'best_match',
    double priceWeight = 0.35,
    double distanceWeight = 0.25,
    double ratingWeight = 0.20,
    double reliabilityWeight = 0.15,
    double speedWeight = 0.05,
  }) {
    final eligible = offers.where((o) {
      if (o.capacityLiters != requestedCapacity) return false;
      final dist = LocationService.calculateDistanceKm(
        customerLat,
        customerLng,
        o.lat,
        o.lng,
      );
      return dist <= o.serviceRadiusKm;
    }).toList();

    if (eligible.isEmpty) return [];

    final prices = eligible.map((e) => e.totalPrice).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    final distances = eligible.map((e) => e.distanceKm).toList();
    final minDist = distances.reduce((a, b) => a < b ? a : b);
    final maxDist = distances.reduce((a, b) => a > b ? a : b);

    final speeds = eligible.map((e) => e.avgArrivalMinutes).toList();
    final minSpeed = speeds.reduce((a, b) => a < b ? a : b);
    final maxSpeed = speeds.reduce((a, b) => a > b ? a : b);

    final scored = eligible.map((item) {
      final priceScore = maxPrice == minPrice
          ? 1.0
          : 1.0 - ((item.totalPrice - minPrice) / (maxPrice - minPrice));
      final distScore = maxDist == minDist
          ? 1.0
          : 1.0 - ((item.distanceKm - minDist) / (maxDist - minDist));
      final ratingConf = (item.reviewCount / 5.0).clamp(0.0, 1.0);
      final normRating = (item.ratingAverage ?? 3.0) / 5.0;
      final ratingScore = normRating * ratingConf + 0.6 * (1.0 - ratingConf);
      final relScore = item.onTimePercentage != null
          ? (item.onTimePercentage! / 100.0)
          : 0.75;
      final speedScore = maxSpeed == minSpeed
          ? 1.0
          : 1.0 - ((item.avgArrivalMinutes - minSpeed) / (maxSpeed - minSpeed));

      final score =
          priceWeight * priceScore +
          distanceWeight * distScore +
          ratingWeight * ratingScore +
          reliabilityWeight * relScore +
          speedWeight * speedScore;

      final reasons = <String>[
        'serves your area',
        'is available for ${item.capacityLiters} L',
      ];
      if (item.totalPrice == minPrice) {
        reasons.add('offers the lowest price');
      } else if (item.distanceKm == minDist) {
        reasons.add('is the closest available tanker');
      } else {
        reasons.add('offers a competitive price');
      }

      return item.copyWith(
        recommendationScore: score,
        recommendationExplanation:
            'Recommended because this supplier ${reasons.join(', ')}.',
      );
    }).toList();

    if (sortBy == 'cheapest') {
      scored.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
    } else if (sortBy == 'fastest') {
      scored.sort((a, b) => a.avgArrivalMinutes.compareTo(b.avgArrivalMinutes));
    } else if (sortBy == 'best_rated') {
      scored.sort((a, b) {
        final aRating = a.reviewCount > 0 ? (a.ratingAverage ?? 0.0) : 0.0;
        final bRating = b.reviewCount > 0 ? (b.ratingAverage ?? 0.0) : 0.0;
        final cmp = bRating.compareTo(aRating);
        if (cmp != 0) return cmp;
        return b.reviewCount.compareTo(a.reviewCount);
      });
    } else {
      scored.sort(
        (a, b) => b.recommendationScore.compareTo(a.recommendationScore),
      );
    }

    if (scored.isNotEmpty) {
      scored[0] = scored[0].copyWith(isAiPick: true);
    }

    return scored;
  }
}
