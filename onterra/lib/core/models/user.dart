import 'package:latlong2/latlong.dart';

import 'product.dart';
import 'truck.dart';

/// The three hats a single Onterra account can wear.
enum AppRole { customer, driver, offtaker }

extension AppRoleX on AppRole {
  String get label => switch (this) {
        AppRole.customer => 'Customer',
        AppRole.driver => 'Driver',
        AppRole.offtaker => 'Offtaker',
      };

  String get description => switch (this) {
        AppRole.customer => 'Buy and get product delivered',
        AppRole.driver => 'Haul product with your truck',
        AppRole.offtaker => 'Sell product you hold at a depot',
      };
}

enum VerificationStatus { notStarted, pending, approved, rejected, expired }

extension VerificationStatusX on VerificationStatus {
  String get label => switch (this) {
        VerificationStatus.notStarted => 'Not started',
        VerificationStatus.pending => 'Under review',
        VerificationStatus.approved => 'Verified',
        VerificationStatus.rejected => 'Rejected',
        VerificationStatus.expired => 'Re-check due',
      };
}

/// How often a driver must redo the liveness check and truck photo.
const driverRecheckInterval = Duration(days: 30);

class DriverProfile {
  const DriverProfile({
    required this.truck,
    required this.licenceNumber,
    this.licencePhoto,
    this.livenessPassedAt,
    this.status = VerificationStatus.notStarted,
    this.verifiedAt,
    this.rating = 0,
    this.tripsCompleted = 0,
    this.available = true,
    required this.location,
    this.baseCity = '',
  });

  final Truck truck;
  final String licenceNumber;
  final CapturedPhoto? licencePhoto;
  final DateTime? livenessPassedAt;
  final VerificationStatus status;
  final DateTime? verifiedAt;
  final double rating;
  final int tripsCompleted;
  final bool available;
  final LatLng location;
  final String baseCity;

  DateTime? get nextRecheckDue => verifiedAt?.add(driverRecheckInterval);

  bool get recheckOverdue {
    final due = nextRecheckDue;
    return due != null && DateTime.now().isAfter(due);
  }

  VerificationStatus get effectiveStatus =>
      status == VerificationStatus.approved && recheckOverdue ? VerificationStatus.expired : status;

  bool get isVerified => effectiveStatus == VerificationStatus.approved && truck.calibrationValid;

  bool get canTakeJobs => isVerified && available;

  bool canCarry(ProductType product, int quantity) =>
      truck.products.contains(product) && truck.capacity >= quantity;

  DriverProfile copyWith({
    Truck? truck,
    String? licenceNumber,
    CapturedPhoto? licencePhoto,
    DateTime? livenessPassedAt,
    VerificationStatus? status,
    DateTime? verifiedAt,
    double? rating,
    int? tripsCompleted,
    bool? available,
    LatLng? location,
    String? baseCity,
  }) {
    return DriverProfile(
      truck: truck ?? this.truck,
      licenceNumber: licenceNumber ?? this.licenceNumber,
      licencePhoto: licencePhoto ?? this.licencePhoto,
      livenessPassedAt: livenessPassedAt ?? this.livenessPassedAt,
      status: status ?? this.status,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rating: rating ?? this.rating,
      tripsCompleted: tripsCompleted ?? this.tripsCompleted,
      available: available ?? this.available,
      location: location ?? this.location,
      baseCity: baseCity ?? this.baseCity,
    );
  }
}

/// Evidence that an offtaker actually holds product at a depot.
///
/// In practice this is a depot allocation letter, a stock certificate or a
/// programme ticket. Every listing must reference one that has not expired.
class ProofOfProduct {
  const ProofOfProduct({
    required this.id,
    required this.depotId,
    required this.product,
    required this.quantity,
    required this.reference,
    required this.issuedAt,
    required this.expiresAt,
    this.document,
  });

  final String id;
  final String depotId;
  final ProductType product;
  final int quantity;
  final String reference;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final CapturedPhoto? document;

  bool get isValid => expiresAt.isAfter(DateTime.now());
}

class OfftakerProfile {
  const OfftakerProfile({
    required this.companyName,
    required this.rcNumber,
    required this.licenceNumber,
    this.licencePhoto,
    this.proofs = const [],
    this.status = VerificationStatus.notStarted,
    this.verifiedAt,
    this.rating = 0,
    this.ordersFulfilled = 0,
  });

  final String companyName;

  /// CAC registration number.
  final String rcNumber;

  /// NMDPRA (regulator) marketing licence number.
  final String licenceNumber;
  final CapturedPhoto? licencePhoto;
  final List<ProofOfProduct> proofs;
  final VerificationStatus status;
  final DateTime? verifiedAt;
  final double rating;
  final int ordersFulfilled;

  bool get isVerified => status == VerificationStatus.approved;

  List<ProofOfProduct> get validProofs => proofs.where((p) => p.isValid).toList();

  OfftakerProfile copyWith({
    String? companyName,
    String? rcNumber,
    String? licenceNumber,
    CapturedPhoto? licencePhoto,
    List<ProofOfProduct>? proofs,
    VerificationStatus? status,
    DateTime? verifiedAt,
    double? rating,
    int? ordersFulfilled,
  }) {
    return OfftakerProfile(
      companyName: companyName ?? this.companyName,
      rcNumber: rcNumber ?? this.rcNumber,
      licenceNumber: licenceNumber ?? this.licenceNumber,
      licencePhoto: licencePhoto ?? this.licencePhoto,
      proofs: proofs ?? this.proofs,
      status: status ?? this.status,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rating: rating ?? this.rating,
      ordersFulfilled: ordersFulfilled ?? this.ordersFulfilled,
    );
  }
}

class BankAccount {
  const BankAccount({required this.bankName, required this.accountNumber, required this.accountName});

  final String bankName;
  final String accountNumber;
  final String accountName;

  String get masked => '$bankName ····${accountNumber.substring(accountNumber.length - 4)}';
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.activeRole = AppRole.customer,
    this.driver,
    this.offtaker,
    this.bankAccount,
    this.isSeeded = false,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final AppRole activeRole;
  final DriverProfile? driver;
  final OfftakerProfile? offtaker;
  final BankAccount? bankAccount;

  /// Seeded counterparties are driven by the demo simulator, not a person.
  final bool isSeeded;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    AppRole? activeRole,
    DriverProfile? driver,
    OfftakerProfile? offtaker,
    BankAccount? bankAccount,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      activeRole: activeRole ?? this.activeRole,
      driver: driver ?? this.driver,
      offtaker: offtaker ?? this.offtaker,
      bankAccount: bankAccount ?? this.bankAccount,
      isSeeded: isSeeded,
    );
  }
}
