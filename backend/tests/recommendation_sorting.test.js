const {
  rankCompanies,
  scoreAndSortItems,
} = require('../src/services/recommendationService');

describe('WaterFix Recommendation & Sorting Service Tests', () => {
  const dummySuppliers = [
    {
      _id: 'supplier_ashhad',
      businessName: 'Ashhad Water Supply',
      ratingAverage: 5.0,
      reviewCount: 2,
      pricePer1000Liters: 1800,
      lat: 33.6938,
      lng: 73.0169,
      serviceRadiusKm: 20,
      availableWaterLiters: 15000,
      tankersOwned: 3,
      isAvailable: true,
      isLocked: false,
      completedDeliveriesCount: 10,
      onTimeDeliveriesCount: 10,
    },
    {
      _id: 'supplier_irtaza',
      businessName: 'Irtaza Rehman Water Company',
      ratingAverage: null, // Unrated / new
      reviewCount: 0,
      pricePer1000Liters: 1400, // Cheaper!
      lat: 33.6515,
      lng: 73.1566,
      serviceRadiusKm: 20,
      availableWaterLiters: 10000,
      tankersOwned: 4,
      isAvailable: true,
      isLocked: false,
      completedDeliveriesCount: 0,
      onTimeDeliveriesCount: 0,
    },
  ];

  test('1. "best_rated" strictly ranks verified reviewed supplier above unrated supplier', () => {
    const results = rankCompanies({
      suppliers: dummySuppliers,
      customerLat: 33.6938,
      customerLng: 73.0169,
      requestedCapacity: 1000,
      sortBy: 'best_rated',
    });

    expect(results.length).toBe(2);
    // Ashhad has 5.0 rating & 2 reviews; Irtaza has 0 reviews
    expect(results[0].supplierId).toBe('supplier_ashhad');
    expect(results[0].ratingAverage).toBe(5.0);
    expect(results[0].reviewCount).toBe(2);
    expect(results[1].supplierId).toBe('supplier_irtaza');
    expect(results[1].reviewCount).toBe(0);
  });

  test('2. "cheapest" strictly orders by total payable price', () => {
    const results = rankCompanies({
      suppliers: dummySuppliers,
      customerLat: 33.6938,
      customerLng: 73.0169,
      requestedCapacity: 1000,
      sortBy: 'cheapest',
    });

    expect(results.length).toBe(2);
    // Irtaza rate is 1400 (water: 1400 + delivery: 250 = 1650)
    // Ashhad rate is 1800 (water: 1800 + delivery: 250 = 2050)
    expect(results[0].supplierId).toBe('supplier_irtaza');
    expect(results[0].totalPrice).toBe(1650);
    expect(results[1].supplierId).toBe('supplier_ashhad');
    expect(results[1].totalPrice).toBe(2050);
  });

  test('3. "fastest" strictly orders by arrival time', () => {
    // Ashhad is at customerLat (33.6938, 73.0169), distance ~0 km => faster arrival
    const results = rankCompanies({
      suppliers: dummySuppliers,
      customerLat: 33.6938,
      customerLng: 73.0169,
      requestedCapacity: 1000,
      sortBy: 'fastest',
    });

    expect(results.length).toBe(2);
    expect(results[0].supplierId).toBe('supplier_ashhad');
    expect(results[0].avgArrivalMinutes).toBeLessThanOrEqual(results[1].avgArrivalMinutes);
  });

  test('4. "best_match" assigns "Our Pick" badge to #1 candidate', () => {
    const results = rankCompanies({
      suppliers: dummySuppliers,
      customerLat: 33.6938,
      customerLng: 73.0169,
      requestedCapacity: 1000,
      sortBy: 'best_match',
    });

    expect(results.length).toBe(2);
    expect(results[0].isAiPick).toBe(true);
    expect(results[0].badges).toContain('Our Pick');
    expect(results[0].badges).not.toContain('AI Pick');
  });

  test('5. Distant supplier outside serviceRadiusKm is excluded', () => {
    // Customer in Lahore (31.5204, 74.3587), ~270 km away from Islamabad
    const results = rankCompanies({
      suppliers: dummySuppliers,
      customerLat: 31.5204,
      customerLng: 74.3587,
      requestedCapacity: 1000,
      sortBy: 'best_match',
    });

    expect(results.length).toBe(0);
  });
});
