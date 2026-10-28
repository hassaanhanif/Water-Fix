const https = require('https');
const env = require('../config/env');
const { haversineDistanceKm } = require('../utils/geo');

const DEFAULT_WEIGHTS = {
  priceWeight: 0.35,
  distanceWeight: 0.25,
  ratingWeight: 0.20,
  reliabilityWeight: 0.15,
  speedWeight: 0.05,
};

/**
 * Evaluates, filters, scores, and sorts supplier listings/companies using a transparent,
 * deterministic local recommendation algorithm.
 */
function scoreAndSortItems(eligibleItems, sortBy, weights = DEFAULT_WEIGHTS) {
  if (eligibleItems.length === 0) {
    return [];
  }

  // Min-max bounds for deterministic normalization
  const prices = eligibleItems.map((i) => i.totalPrice);
  const minPrice = Math.min(...prices);
  const maxPrice = Math.max(...prices);

  const distances = eligibleItems
    .map((i) => i.distanceKm)
    .filter((d) => typeof d === 'number' && !isNaN(d));
  const minDist = distances.length > 0 ? Math.min(...distances) : 0;
  const maxDist = distances.length > 0 ? Math.max(...distances) : 0;

  const speeds = eligibleItems.map((i) => i.avgArrivalMinutes);
  const minSpeed = Math.min(...speeds);
  const maxSpeed = Math.max(...speeds);

  for (const item of eligibleItems) {
    const priceScore =
      maxPrice === minPrice ? 1.0 : 1.0 - (item.totalPrice - minPrice) / (maxPrice - minPrice);

    const distanceScore =
      typeof item.distanceKm !== 'number'
        ? 0.5
        : maxDist === minDist
        ? 1.0
        : 1.0 - (item.distanceKm - minDist) / (maxDist - minDist);

    const ratingConfidence = Math.min(1.0, item.reviewCount / 5);
    const normalizedRating = item.ratingAverage ? item.ratingAverage / 5.0 : 0.6;
    const ratingScore = normalizedRating * ratingConfidence + 0.6 * (1 - ratingConfidence);

    const reliabilityBase = item.hasSufficientHistory ? item.onTimePercentage / 100.0 : 0.75;
    const reliabilityScore = Math.max(0, reliabilityBase - item.cancellationRate * 0.5);

    const speedScore =
      maxSpeed === minSpeed ? 1.0 : 1.0 - (item.avgArrivalMinutes - minSpeed) / (maxSpeed - minSpeed);

    const totalScore =
      weights.priceWeight * priceScore +
      weights.distanceWeight * distanceScore +
      weights.ratingWeight * ratingScore +
      weights.reliabilityWeight * reliabilityScore +
      weights.speedWeight * speedScore;

    item.recommendationScore = Math.round(totalScore * 1000) / 1000;
    item.badges = [];
    if (item.totalPrice === minPrice && eligibleItems.length > 1) {
      item.badges.push('Cheapest');
    }
    if (item.avgArrivalMinutes === minSpeed && eligibleItems.length > 1) {
      item.badges.push('Fastest');
    }

    // Explainable recommendation reason
    const reasons = ['serves your area', `is available for ${item.capacityLiters.toLocaleString()} L`];
    if (item.totalPrice === minPrice) {
      reasons.push('offers the lowest total price');
    } else if (item.distanceKm === minDist && item.hasAccurateDistance) {
      reasons.push('is the closest available tanker');
    } else if (item.hasSufficientHistory && item.onTimePercentage >= 90) {
      reasons.push(`has a strong ${item.onTimePercentage}% on-time delivery record`);
    } else {
      reasons.push('offers a competitive price');
    }
    item.recommendationExplanation = `Recommended because this supplier ${reasons.join(', ')}.`;
  }

  // Sort according to selected mode
  const sorted = [...eligibleItems];
  if (sortBy === 'cheapest') {
    sorted.sort((a, b) => {
      const priceDiff = a.totalPrice - b.totalPrice;
      if (priceDiff !== 0) return priceDiff;
      const aDist = typeof a.distanceKm === 'number' ? a.distanceKm : 9999;
      const bDist = typeof b.distanceKm === 'number' ? b.distanceKm : 9999;
      return aDist - bDist;
    });
  } else if (sortBy === 'fastest') {
    sorted.sort((a, b) => {
      const speedDiff = a.avgArrivalMinutes - b.avgArrivalMinutes;
      if (speedDiff !== 0) return speedDiff;
      const aDist = typeof a.distanceKm === 'number' ? a.distanceKm : 9999;
      const bDist = typeof b.distanceKm === 'number' ? b.distanceKm : 9999;
      return aDist - bDist;
    });
  } else if (sortBy === 'best_rated') {
    sorted.sort((a, b) => {
      const aReviews = a.reviewCount || 0;
      const bReviews = b.reviewCount || 0;
      const aRating = aReviews > 0 ? (a.ratingAverage || 0) : 0;
      const bRating = bReviews > 0 ? (b.ratingAverage || 0) : 0;
      if (bRating !== aRating) {
        return bRating - aRating;
      }
      if (bReviews !== aReviews) {
        return bReviews - aReviews;
      }
      return a.totalPrice - b.totalPrice;
    });
  } else {
    // 'best_match' (default Our Pick)
    sorted.sort(
      (a, b) => b.recommendationScore - a.recommendationScore || a.totalPrice - b.totalPrice
    );
  }

  if (sorted.length > 0) {
    sorted[0].isAiPick = true;
    if (!sorted[0].badges.includes('Our Pick')) {
      sorted[0].badges.unshift('Our Pick');
    }
  }

  return sorted;
}

/**
 * Company-level recommendation ranking: ranks supplier companies directly using
 * real profile coordinates, delivery radius, available water stock, and rate per 1,000 L.
 */
function rankCompanies({
  suppliers,
  customerLat,
  customerLng,
  requestedCapacity,
  sortBy = 'best_match',
  weights = DEFAULT_WEIGHTS,
}) {
  const eligibleItems = [];
  const seenSuppliers = new Set();
  const qty = requestedCapacity ? Number(requestedCapacity) : 500;

  for (const supplier of suppliers || []) {
    if (!supplier) continue;
    if (supplier.isAvailable === false) continue;
    if (supplier.isLocked) continue;

    const sId = supplier._id ? supplier._id.toString() : '';
    if (seenSuppliers.has(sId)) continue;

    const availableStock =
      typeof supplier.availableWaterLiters === 'number'
        ? supplier.availableWaterLiters
        : 10000;
    if (availableStock < qty) {
      continue;
    }

    let distanceKm = null;
    if (
      typeof customerLat === 'number' &&
      typeof customerLng === 'number' &&
      typeof supplier.lat === 'number' &&
      typeof supplier.lng === 'number'
    ) {
      distanceKm = haversineDistanceKm(customerLat, customerLng, supplier.lat, supplier.lng);
      if (distanceKm !== null && distanceKm > (supplier.serviceRadiusKm || 20)) {
        continue;
      }
    }

    seenSuppliers.add(sId);

    const hasSufficientHistory = (supplier.completedDeliveriesCount || 0) >= 3;
    const onTimePercentage = hasSufficientHistory
      ? Math.round(((supplier.onTimeDeliveriesCount || 0) / supplier.completedDeliveriesCount) * 100)
      : null;

    const totalReq = supplier.totalRequestsCount || 0;
    const cancellationRate =
      totalReq >= 3 ? (supplier.cancelledDeliveriesCount || 0) / totalReq : 0;

    const baseMin = 30;
    const baseMax = 45;
    const extraMinutes = distanceKm !== null ? Math.round(distanceKm * 1.5) : 0;
    const arrivalMin = baseMin + extraMinutes;
    const arrivalMax = Math.max(arrivalMin + 10, baseMax + extraMinutes);
    const avgArrivalMinutes = supplier.avgArrivalMinutes || Math.round((arrivalMin + arrivalMax) / 2);

    const ratePer1000 = supplier.pricePer1000Liters || 1800;
    const deliveryFee = 250;
    const calculatedWaterPrice = Math.round((ratePer1000 * qty) / 1000);
    const totalPrice = calculatedWaterPrice + deliveryFee;

    eligibleItems.push({
      listingId: sId,
      supplierId: sId,
      supplierUserId: supplier.userId ? supplier.userId.toString() : '',
      businessName: supplier.businessName,
      ownerName: supplier.ownerName,
      city: supplier.city || 'Islamabad',
      serviceAreaText: supplier.serviceAreaText || 'Islamabad',
      isVerified: Boolean(supplier.isVerified),
      capacityLiters: qty,
      waterQuantityLiters: qty,
      availableWaterLiters: availableStock,
      pricePer1000Liters: ratePer1000,
      tankersOwned: supplier.tankersOwned || 1,
      companyLogo: supplier.companyLogo || null,
      serviceRadiusKm: supplier.serviceRadiusKm || 20,
      lat: supplier.lat != null ? supplier.lat : 33.6938,
      lng: supplier.lng != null ? supplier.lng : 73.0169,
      label: `${qty.toLocaleString()} L delivery`,
      waterPrice: calculatedWaterPrice,
      deliveryFee,
      totalPrice,
      distanceKm: distanceKm !== null ? Math.round(distanceKm * 10) / 10 : null,
      hasAccurateDistance: distanceKm !== null,
      ratingAverage: supplier.reviewCount > 0 ? Number(supplier.ratingAverage.toFixed(1)) : null,
      reviewCount: supplier.reviewCount || 0,
      completedDeliveriesCount: supplier.completedDeliveriesCount || 0,
      hasSufficientHistory,
      onTimePercentage,
      reliabilityText: hasSufficientHistory
        ? `${onTimePercentage}% on time`
        : 'Not enough delivery history',
      cancellationRate,
      estimatedArrivalMinutesMin: arrivalMin,
      estimatedArrivalMinutesMax: arrivalMax,
      avgArrivalMinutes,
      arrivalText: `${arrivalMin}–${arrivalMax} min`,
      phone: supplier.phone || '',
      deliveryInfo: supplier.deliveryInfo || '',
      isAiPick: false,
      isAiGenerated: false,
    });
  }

  return scoreAndSortItems(eligibleItems, sortBy, weights);
}

/**
 * Evaluates, filters, scores, and sorts supplier listings/companies using a transparent,
 * deterministic local recommendation algorithm.
 */
function rankSupplierListings({
  listingsWithSuppliers,
  customerLat,
  customerLng,
  requestedCapacity,
  sortBy = 'best_match',
  weights = DEFAULT_WEIGHTS,
}) {
  const eligibleItems = [];
  const seenSuppliers = new Set();

  for (const item of listingsWithSuppliers || []) {
    const { listing, supplier } = item;
    if (!supplier || !listing) continue;
    if (!supplier.isAvailable || !listing.isAvailable || !listing.isActive) continue;
    if (supplier.isLocked) continue;

    // Consolidate: one company entry per supplier in customer discovery
    const sId = supplier._id.toString();
    if (seenSuppliers.has(sId)) continue;

    // Check available inventory against requested capacity
    const availableStock =
      typeof supplier.availableWaterLiters === 'number'
        ? supplier.availableWaterLiters
        : 10000;
    if (requestedCapacity && availableStock < Number(requestedCapacity)) {
      continue;
    }

    let distanceKm = null;
    if (
      typeof customerLat === 'number' &&
      typeof customerLng === 'number' &&
      typeof supplier.lat === 'number' &&
      typeof supplier.lng === 'number'
    ) {
      distanceKm = haversineDistanceKm(customerLat, customerLng, supplier.lat, supplier.lng);
      if (distanceKm !== null && distanceKm > (supplier.serviceRadiusKm || 20)) {
        // Outside supplier's configured service radius
        continue;
      }
    }

    seenSuppliers.add(sId);

    const hasSufficientHistory = (supplier.completedDeliveriesCount || 0) >= 3;
    const onTimePercentage = hasSufficientHistory
      ? Math.round(((supplier.onTimeDeliveriesCount || 0) / supplier.completedDeliveriesCount) * 100)
      : null;

    const totalReq = supplier.totalRequestsCount || 0;
    const cancellationRate =
      totalReq >= 3 ? (supplier.cancelledDeliveriesCount || 0) / totalReq : 0;

    // Estimate arrival window based on listing estimate + distance adjustment
    const baseMin = listing.estimatedArrivalMinutesMin || 30;
    const baseMax = listing.estimatedArrivalMinutesMax || 45;
    const extraMinutes = distanceKm !== null ? Math.round(distanceKm * 1.5) : 0;
    const arrivalMin = baseMin + extraMinutes;
    const arrivalMax = Math.max(arrivalMin + 10, baseMax + extraMinutes);
    const avgArrivalMinutes = supplier.avgArrivalMinutes || Math.round((arrivalMin + arrivalMax) / 2);

    // Dynamic pricing calculation
    const qty = requestedCapacity ? Number(requestedCapacity) : listing.capacityLiters || 1000;
    const ratePer1000 = supplier.pricePer1000Liters || 1800;
    const deliveryFee = listing.deliveryFee !== undefined ? listing.deliveryFee : 250;
    let calculatedWaterPrice;
    let totalPrice;

    if (listing && (!requestedCapacity || Number(requestedCapacity) === Number(listing.capacityLiters))) {
      calculatedWaterPrice = listing.waterPrice;
      totalPrice = listing.totalPrice;
    } else {
      calculatedWaterPrice = Math.round((ratePer1000 * qty) / 1000);
      totalPrice = calculatedWaterPrice + deliveryFee;
    }

    eligibleItems.push({
      listingId: listing._id.toString(),
      supplierId: supplier._id.toString(),
      supplierUserId: supplier.userId ? supplier.userId.toString() : '',
      businessName: supplier.businessName,
      ownerName: supplier.ownerName,
      city: supplier.city || 'Islamabad',
      serviceAreaText: supplier.serviceAreaText || 'Islamabad',
      isVerified: Boolean(supplier.isVerified),
      capacityLiters: qty,
      waterQuantityLiters: qty,
      availableWaterLiters: availableStock,
      pricePer1000Liters: ratePer1000,
      tankersOwned: supplier.tankersOwned || 1,
      companyLogo: supplier.companyLogo || null,
      serviceRadiusKm: supplier.serviceRadiusKm || 15,
      lat: supplier.lat != null ? supplier.lat : 33.6938,
      lng: supplier.lng != null ? supplier.lng : 73.0169,
      label: listing.label || 'Standard Tanker',
      waterPrice: calculatedWaterPrice,
      deliveryFee,
      totalPrice,
      distanceKm: distanceKm !== null ? Math.round(distanceKm * 10) / 10 : null,
      hasAccurateDistance: distanceKm !== null,
      ratingAverage: supplier.reviewCount > 0 ? Number(supplier.ratingAverage.toFixed(1)) : null,
      reviewCount: supplier.reviewCount || 0,
      completedDeliveriesCount: supplier.completedDeliveriesCount || 0,
      hasSufficientHistory,
      onTimePercentage,
      reliabilityText: hasSufficientHistory
        ? `${onTimePercentage}% on time`
        : 'Not enough delivery history',
      cancellationRate,
      estimatedArrivalMinutesMin: arrivalMin,
      estimatedArrivalMinutesMax: arrivalMax,
      avgArrivalMinutes,
      arrivalText: `${arrivalMin}–${arrivalMax} min`,
      phone: supplier.phone,
      deliveryInfo: supplier.deliveryInfo,
      isAiPick: false,
      isAiGenerated: false,
    });
  }

  return scoreAndSortItems(eligibleItems, sortBy, weights);
}

/**
 * Calls live Groq chat completion API with eligible real supplier candidates
 * using the configured backend Groq API key and model.
 */
async function callGroqAiRecommendations({ eligibleItems, requestedCapacity, sortBy }) {
  if (!env.isGroqConfigured() || !Array.isArray(eligibleItems) || eligibleItems.length === 0) {
    return null;
  }

  try {
    const candidateSummary = eligibleItems.slice(0, 8).map((item) => ({
      id: item.supplierId,
      name: item.businessName,
      availableWaterLiters: item.availableWaterLiters,
      pricePer1000L: item.pricePer1000Liters,
      totalPrice: item.totalPrice,
      distanceKm: item.distanceKm,
      rating: item.ratingAverage,
      speedMin: item.avgArrivalMinutes,
    }));

    const prompt = `You are WaterFix Advisor for water tanker deliveries in Islamabad.
Customer requested: quantity = ${requestedCapacity || 1000} L, sort preference = ${sortBy || 'best_match'}.
Candidate suppliers (real database records only):
${JSON.stringify(candidateSummary, null, 2)}

Select and rank the top recommended suppliers based on best value, proximity, and inventory reliability.
You MUST ONLY return supplier IDs that exist in the candidate list. Do NOT invent fake suppliers or change prices.
Return strictly valid JSON with this exact schema:
{
  "recommendations": [
    {
      "supplierId": "string id from candidate list",
      "rank": 1,
      "badge": "Our Pick",
      "reason": "Brief, compelling, transparent reason why this supplier is best for the customer in Islamabad."
    }
  ]
}`;

    const postData = JSON.stringify({
      model: env.groqModel || 'openai/gpt-oss-20b',
      messages: [
        {
          role: 'system',
          content: 'You are WaterFix Advisor. You only reply with a valid JSON object containing a "recommendations" array.',
        },
        { role: 'user', content: prompt },
      ],
      response_format: { type: 'json_object' },
      max_tokens: 500,
      temperature: 0.2,
    });

    const responseText = await new Promise((resolve, reject) => {
      const req = https.request(
        'https://api.groq.com/openai/v1/chat/completions',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${env.groqApiKey}`,
            'Content-Length': Buffer.byteLength(postData),
          },
          timeout: 6000,
        },
        (res) => {
          let body = '';
          res.on('data', (chunk) => (body += chunk));
          res.on('end', () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              resolve(body);
            } else {
              reject(new Error(`Groq API returned HTTP ${res.statusCode}: ${body}`));
            }
          });
        }
      );

      req.on('timeout', () => {
        req.destroy();
        reject(new Error('Groq API request timed out'));
      });
      req.on('error', reject);
      req.write(postData);
      req.end();
    });

    const parsed = JSON.parse(responseText);
    const content = parsed.choices?.[0]?.message?.content;
    if (!content) return null;

    const aiResult = JSON.parse(content);
    if (!Array.isArray(aiResult.recommendations) || aiResult.recommendations.length === 0) {
      return null;
    }

    // Validate returned supplier IDs against original eligible list
    const validMap = new Map(eligibleItems.map((item) => [item.supplierId, { ...item }]));
    const rankedByAi = [];

    for (const rec of aiResult.recommendations) {
      if (rec && rec.supplierId && validMap.has(String(rec.supplierId))) {
        const item = validMap.get(String(rec.supplierId));
        item.isAiPick = true;
        item.isAiGenerated = true;
        const badge = rec.badge || 'Our Pick';
        if (!item.badges.includes(badge)) {
          item.badges.unshift(badge);
        }
        if (rec.reason) {
          item.recommendationExplanation = rec.reason;
        }
        rankedByAi.push(item);
        validMap.delete(String(rec.supplierId));
      }
    }

    // Append remaining valid candidates
    for (const remaining of validMap.values()) {
      rankedByAi.push(remaining);
    }

    return rankedByAi;
  } catch (err) {
    console.warn('[WaterFix Groq AI] Fallback activated due to:', err.message);
    return null;
  }
}

/**
 * High-level recommendation provider that uses real Groq AI when configured,
 * with seamless deterministic fallback when offline or during test suites.
 */
async function getSmartRecommendations({
  suppliers,
  listingsWithSuppliers,
  customerLat,
  customerLng,
  requestedCapacity,
  sortBy = 'best_match',
  useGroq = true,
}) {
  const deterministicRanked = suppliers
    ? rankCompanies({
        suppliers,
        customerLat,
        customerLng,
        requestedCapacity,
        sortBy,
      })
    : rankSupplierListings({
        listingsWithSuppliers,
        customerLat,
        customerLng,
        requestedCapacity,
        sortBy,
      });

  // When sorting is explicitly requested by Cheapest, Fastest, or Best Rated,
  // do not let Groq AI re-order candidates — keep strict mathematical/metric order.
  if (!useGroq || deterministicRanked.length === 0 || sortBy !== 'best_match') {
    return {
      suppliers: deterministicRanked,
      isAiGenerated: false,
      aiModel: null,
    };
  }

  const groqRanked = await callGroqAiRecommendations({
    eligibleItems: deterministicRanked,
    requestedCapacity,
    sortBy,
  });

  if (groqRanked && groqRanked.length > 0) {
    return {
      suppliers: groqRanked,
      isAiGenerated: true,
      aiModel: env.groqModel || 'openai/gpt-oss-20b',
    };
  }

  return {
    suppliers: deterministicRanked,
    isAiGenerated: false,
    aiModel: null,
  };
}

module.exports = {
  rankCompanies,
  rankSupplierListings,
  callGroqAiRecommendations,
  getSmartRecommendations,
  DEFAULT_WEIGHTS,
};
