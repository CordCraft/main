import 'package:latlong2/latlong.dart';

import '../models/depot.dart';
import '../models/listing.dart';
import '../models/product.dart';
import '../models/truck.dart';
import '../models/user.dart';

/// Sample depots, drivers, offtakers and listings so the app is usable end to
/// end before a backend exists. Locations are real depot areas; prices are
/// indicative only.
class SeedData {
  SeedData._();

  static final DateTime _now = DateTime.now();

  static const liquids = {ProductType.pms, ProductType.ago, ProductType.dpk};

  static final List<Depot> depots = [
    Depot(
      id: 'dep-dangote',
      name: 'Dangote Refinery Gantry',
      operator: 'Dangote Petroleum Refinery',
      city: 'Ibeju-Lekki',
      state: 'Lagos',
      location: const LatLng(6.4597, 3.9932),
      products: {...liquids, ProductType.atk},
      address: 'Lekki Free Trade Zone, Ibeju-Lekki',
    ),
    Depot(
      id: 'dep-nnpc-apapa',
      name: 'NNPC Apapa Depot',
      operator: 'NNPC Retail',
      city: 'Apapa',
      state: 'Lagos',
      location: const LatLng(6.4386, 3.3620),
      products: liquids,
      address: 'Creek Road, Apapa',
    ),
    Depot(
      id: 'dep-mrs-tincan',
      name: 'MRS Tin Can Depot',
      operator: 'MRS Oil',
      city: 'Apapa',
      state: 'Lagos',
      location: const LatLng(6.4319, 3.3391),
      products: liquids,
      address: 'Tin Can Island, Apapa',
    ),
    Depot(
      id: 'dep-navgas',
      name: 'Navgas LPG Terminal',
      operator: 'Navgas',
      city: 'Apapa',
      state: 'Lagos',
      location: const LatLng(6.4402, 3.3554),
      products: {ProductType.lpg},
      address: 'Dockyard Road, Apapa',
    ),
    Depot(
      id: 'dep-nipco',
      name: 'NIPCO Apapa Terminal',
      operator: 'NIPCO',
      city: 'Apapa',
      state: 'Lagos',
      location: const LatLng(6.4441, 3.3676),
      products: {...liquids, ProductType.lpg},
      address: 'Ijora Causeway, Apapa',
    ),
    Depot(
      id: 'dep-mosimi',
      name: 'NNPC Mosimi Depot',
      operator: 'NNPC Retail',
      city: 'Sagamu',
      state: 'Ogun',
      location: const LatLng(6.8506, 3.6197),
      products: liquids,
    ),
    Depot(
      id: 'dep-ibadan',
      name: 'NNPC Ibadan Depot',
      operator: 'NNPC Retail',
      city: 'Apata, Ibadan',
      state: 'Oyo',
      location: const LatLng(7.3667, 3.8500),
      products: liquids,
    ),
    Depot(
      id: 'dep-ore',
      name: 'NNPC Ore Depot',
      operator: 'NNPC Retail',
      city: 'Ore',
      state: 'Ondo',
      location: const LatLng(6.7500, 4.8833),
      products: liquids,
    ),
    Depot(
      id: 'dep-warri',
      name: 'Warri Refinery Loading Bay',
      operator: 'WRPC',
      city: 'Warri',
      state: 'Delta',
      location: const LatLng(5.5544, 5.7221),
      products: {...liquids, ProductType.lpg},
    ),
    Depot(
      id: 'dep-oghara',
      name: 'Rainoil Oghara Depot',
      operator: 'Rainoil',
      city: 'Oghara',
      state: 'Delta',
      location: const LatLng(5.9167, 5.6833),
      products: liquids,
    ),
    Depot(
      id: 'dep-ph',
      name: 'Port Harcourt Refinery Depot',
      operator: 'PHRC',
      city: 'Eleme',
      state: 'Rivers',
      location: const LatLng(4.7833, 7.0333),
      products: {...liquids, ProductType.lpg},
    ),
    Depot(
      id: 'dep-calabar',
      name: 'NNPC Calabar Depot',
      operator: 'NNPC Retail',
      city: 'Calabar',
      state: 'Cross River',
      location: const LatLng(4.9667, 8.3167),
      products: liquids,
    ),
    Depot(
      id: 'dep-enugu',
      name: 'NNPC Enugu Depot',
      operator: 'NNPC Retail',
      city: 'Emene, Enugu',
      state: 'Enugu',
      location: const LatLng(6.4667, 7.5500),
      products: liquids,
    ),
    Depot(
      id: 'dep-suleja',
      name: 'NNPC Suleja Depot',
      operator: 'NNPC Retail',
      city: 'Suleja',
      state: 'Niger',
      location: const LatLng(9.1833, 7.1833),
      products: liquids,
    ),
    Depot(
      id: 'dep-kaduna',
      name: 'Kaduna Refinery Depot',
      operator: 'KRPC',
      city: 'Kaduna',
      state: 'Kaduna',
      location: const LatLng(10.5222, 7.4383),
      products: {...liquids, ProductType.lpg},
    ),
    Depot(
      id: 'dep-kano',
      name: 'NNPC Kano Depot',
      operator: 'NNPC Retail',
      city: 'Hotoro, Kano',
      state: 'Kano',
      location: const LatLng(12.0022, 8.5920),
      products: liquids,
    ),
    Depot(
      id: 'dep-jos',
      name: 'NNPC Jos Depot',
      operator: 'NNPC Retail',
      city: 'Jos',
      state: 'Plateau',
      location: const LatLng(9.8965, 8.8583),
      products: liquids,
    ),
    Depot(
      id: 'dep-abuja-atk',
      name: 'NAIA Aviation Fuel Farm',
      operator: 'NNPC / Cleanserve',
      city: 'Abuja Airport',
      state: 'FCT',
      location: const LatLng(9.0068, 7.2632),
      products: {ProductType.atk},
    ),
  ];

  static Depot depotById(String id) => depots.firstWhere((d) => d.id == id);

  /// Delivery locations customers commonly pick, offered as quick choices.
  static const quickDestinations = <String, LatLng>{
    'Ikeja, Lagos': LatLng(6.6018, 3.3515),
    'Lekki Phase 1, Lagos': LatLng(6.4474, 3.4736),
    'Ibadan, Oyo': LatLng(7.3775, 3.9470),
    'Abeokuta, Ogun': LatLng(7.1475, 3.3619),
    'Benin City, Edo': LatLng(6.3350, 5.6037),
    'Asaba, Delta': LatLng(6.1980, 6.7300),
    'Port Harcourt, Rivers': LatLng(4.8156, 7.0498),
    'Uyo, Akwa Ibom': LatLng(5.0377, 7.9128),
    'Onitsha, Anambra': LatLng(6.1667, 6.7833),
    'Enugu, Enugu': LatLng(6.4584, 7.5464),
    'Abuja Central, FCT': LatLng(9.0579, 7.4951),
    'Lokoja, Kogi': LatLng(7.8023, 6.7333),
    'Kaduna, Kaduna': LatLng(10.5105, 7.4165),
    'Kano, Kano': LatLng(12.0022, 8.5920),
    'Jos, Plateau': LatLng(9.8965, 8.8583),
    'Maiduguri, Borno': LatLng(11.8311, 13.1510),
    'Sokoto, Sokoto': LatLng(13.0059, 5.2476),
    'Yola, Adamawa': LatLng(9.2035, 12.4954),
  };

  static AppUser _driver({
    required String id,
    required String name,
    required String phone,
    required String plate,
    required TruckClass truckClass,
    required Set<ProductType> products,
    required String make,
    required int year,
    required LatLng location,
    required String city,
    required double rating,
    required int trips,
  }) {
    return AppUser(
      id: id,
      name: name,
      phone: phone,
      activeRole: AppRole.driver,
      isSeeded: true,
      bankAccount: BankAccount(bankName: 'GTBank', accountNumber: '01234${id.hashCode.abs() % 100000}'.padRight(10, '0'), accountName: name),
      driver: DriverProfile(
        truck: Truck(
          id: 'trk-$id',
          plate: plate,
          truckClass: truckClass,
          make: make,
          year: year,
          calibrationExpiry: _now.add(const Duration(days: 200)),
          products: products,
        ),
        licenceNumber: 'DL-${plate.replaceAll(' ', '')}',
        livenessPassedAt: _now.subtract(const Duration(days: 4)),
        status: VerificationStatus.approved,
        verifiedAt: _now.subtract(const Duration(days: 4)),
        rating: rating,
        tripsCompleted: trips,
        location: location,
        baseCity: city,
      ),
    );
  }

  static final List<AppUser> drivers = [
    _driver(
      id: 'drv-musa',
      name: 'Musa Abdullahi',
      phone: '+2348031000001',
      plate: 'KJA 412 XY',
      truckClass: TruckClass.tanker33,
      products: liquids,
      make: 'MAN Diesel',
      year: 2018,
      location: const LatLng(6.4500, 3.3700),
      city: 'Apapa, Lagos',
      rating: 4.8,
      trips: 212,
    ),
    _driver(
      id: 'drv-chidi',
      name: 'Chidi Okonkwo',
      phone: '+2348031000002',
      plate: 'AAA 771 KT',
      truckClass: TruckClass.tanker45,
      products: liquids,
      make: 'Mack Granite',
      year: 2020,
      location: const LatLng(6.4650, 3.9800),
      city: 'Ibeju-Lekki, Lagos',
      rating: 4.6,
      trips: 148,
    ),
    _driver(
      id: 'drv-tunde',
      name: 'Tunde Bakare',
      phone: '+2348031000003',
      plate: 'LSD 903 CV',
      truckClass: TruckClass.tanker60,
      products: {ProductType.ago, ProductType.pms},
      make: 'Howo Sinotruk',
      year: 2021,
      location: const LatLng(6.8400, 3.6300),
      city: 'Sagamu, Ogun',
      rating: 4.4,
      trips: 96,
    ),
    _driver(
      id: 'drv-ngozi',
      name: 'Ngozi Eze',
      phone: '+2348031000004',
      plate: 'RSH 205 AB',
      truckClass: TruckClass.tanker33,
      products: liquids,
      make: 'Iveco Trakker',
      year: 2017,
      location: const LatLng(4.8000, 7.0400),
      city: 'Eleme, Rivers',
      rating: 4.9,
      trips: 301,
    ),
    _driver(
      id: 'drv-ibrahim',
      name: 'Ibrahim Sani',
      phone: '+2348031000005',
      plate: 'KDA 118 MK',
      truckClass: TruckClass.tanker45,
      products: liquids,
      make: 'Scania R-series',
      year: 2019,
      location: const LatLng(10.5200, 7.4400),
      city: 'Kaduna',
      rating: 4.7,
      trips: 177,
    ),
    _driver(
      id: 'drv-emeka',
      name: 'Emeka Nwosu',
      phone: '+2348031000006',
      plate: 'APP 330 GS',
      truckClass: TruckClass.lpgBobtail,
      products: {ProductType.lpg},
      make: 'Isuzu FVR',
      year: 2022,
      location: const LatLng(6.4400, 3.3600),
      city: 'Apapa, Lagos',
      rating: 4.5,
      trips: 88,
    ),
    _driver(
      id: 'drv-yusuf',
      name: 'Yusuf Garba',
      phone: '+2348031000007',
      plate: 'FST 640 LG',
      truckClass: TruckClass.lpgBridger,
      products: {ProductType.lpg},
      make: 'MAN TGS',
      year: 2020,
      location: const LatLng(5.5600, 5.7300),
      city: 'Warri, Delta',
      rating: 4.3,
      trips: 64,
    ),
    _driver(
      id: 'drv-bola',
      name: 'Bola Adeyemi',
      phone: '+2348031000008',
      plate: 'ABJ 511 AV',
      truckClass: TruckClass.atkRefueller,
      products: {ProductType.atk},
      make: 'Mercedes Actros',
      year: 2021,
      location: const LatLng(9.0100, 7.2600),
      city: 'Abuja',
      rating: 4.8,
      trips: 132,
    ),
  ];

  static AppUser _offtaker({
    required String id,
    required String name,
    required String company,
    required String phone,
    required List<ProofOfProduct> proofs,
    required double rating,
    required int fulfilled,
  }) {
    return AppUser(
      id: id,
      name: name,
      phone: phone,
      activeRole: AppRole.offtaker,
      isSeeded: true,
      bankAccount: BankAccount(bankName: 'Zenith Bank', accountNumber: '2${id.hashCode.abs() % 1000000000}'.padRight(10, '0'), accountName: company),
      offtaker: OfftakerProfile(
        companyName: company,
        rcNumber: 'RC${id.hashCode.abs() % 900000 + 100000}',
        licenceNumber: 'NMDPRA/${id.hashCode.abs() % 9000 + 1000}/24',
        proofs: proofs,
        status: VerificationStatus.approved,
        verifiedAt: _now.subtract(const Duration(days: 40)),
        rating: rating,
        ordersFulfilled: fulfilled,
      ),
    );
  }

  static ProofOfProduct _proof(String id, String depotId, ProductType p, int qty, int daysValid) => ProofOfProduct(
        id: id,
        depotId: depotId,
        product: p,
        quantity: qty,
        reference: 'ALLOC/${depotId.split('-').last.toUpperCase()}/${id.hashCode.abs() % 90000 + 10000}',
        issuedAt: _now.subtract(const Duration(days: 3)),
        expiresAt: _now.add(Duration(days: daysValid)),
      );

  static final List<AppUser> offtakers = [
    _offtaker(
      id: 'off-lagosfuels',
      name: 'Adaeze Okafor',
      company: 'Lagos Fuels & Energy Ltd',
      phone: '+2348021000001',
      proofs: [
        _proof('prf-1', 'dep-dangote', ProductType.pms, 900000, 21),
        _proof('prf-2', 'dep-dangote', ProductType.ago, 600000, 21),
        _proof('prf-3', 'dep-nnpc-apapa', ProductType.dpk, 200000, 14),
      ],
      rating: 4.7,
      fulfilled: 540,
    ),
    _offtaker(
      id: 'off-rainoil',
      name: 'Kunle Fashola',
      company: 'Rainoil Trading',
      phone: '+2348021000002',
      proofs: [
        _proof('prf-4', 'dep-oghara', ProductType.pms, 400000, 30),
        _proof('prf-5', 'dep-oghara', ProductType.ago, 400000, 30),
        _proof('prf-6', 'dep-mrs-tincan', ProductType.pms, 300000, 10),
      ],
      rating: 4.5,
      fulfilled: 312,
    ),
    _offtaker(
      id: 'off-northgas',
      name: 'Hauwa Bello',
      company: 'Northern Gas Marketers',
      phone: '+2348021000003',
      proofs: [
        _proof('prf-7', 'dep-kaduna', ProductType.pms, 250000, 18),
        _proof('prf-8', 'dep-kano', ProductType.ago, 180000, 18),
        _proof('prf-9', 'dep-kaduna', ProductType.lpg, 120000, 25),
      ],
      rating: 4.4,
      fulfilled: 205,
    ),
    _offtaker(
      id: 'off-deltalpg',
      name: 'Efe Omoregie',
      company: 'Delta LPG Supply Co',
      phone: '+2348021000004',
      proofs: [
        _proof('prf-10', 'dep-navgas', ProductType.lpg, 300000, 20),
        _proof('prf-11', 'dep-warri', ProductType.lpg, 150000, 20),
        _proof('prf-12', 'dep-ph', ProductType.lpg, 100000, 12),
      ],
      rating: 4.8,
      fulfilled: 418,
    ),
    _offtaker(
      id: 'off-eastcoast',
      name: 'Obinna Iwu',
      company: 'East Coast Petroleum',
      phone: '+2348021000005',
      proofs: [
        _proof('prf-13', 'dep-ph', ProductType.pms, 500000, 15),
        _proof('prf-14', 'dep-ph', ProductType.ago, 350000, 15),
        _proof('prf-15', 'dep-abuja-atk', ProductType.atk, 200000, 28),
      ],
      rating: 4.6,
      fulfilled: 276,
    ),
  ];

  /// Indicative September 2026 gantry prices in naira per unit.
  static double basePrice(ProductType p) => switch (p) {
        ProductType.pms => 845,
        ProductType.ago => 1040,
        ProductType.dpk => 1110,
        ProductType.lpg => 1290,
        ProductType.atk => 1180,
      };

  static List<ProductListing> listings() {
    final out = <ProductListing>[];
    var i = 0;
    for (final u in offtakers) {
      for (final proof in u.offtaker!.proofs) {
        i++;
        final jitter = (i % 5 - 2) * 6.0; // spread prices a little across sellers
        out.add(ProductListing(
          id: 'lst-$i',
          offtakerId: u.id,
          offtakerName: u.offtaker!.companyName,
          depotId: proof.depotId,
          product: proof.product,
          pricePerUnit: basePrice(proof.product) + jitter,
          availableQuantity: proof.quantity,
          minQuantity: proof.product == ProductType.lpg ? 5000 : 33000,
          proofId: proof.id,
          proofReference: proof.reference,
          proofExpiresAt: proof.expiresAt,
          createdAt: _now.subtract(Duration(hours: i * 7)),
        ));
      }
    }
    return out;
  }
}
