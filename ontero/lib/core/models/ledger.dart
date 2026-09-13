/// Movement of money through the Ontero escrow account.
enum LedgerKind { escrowIn, release, fee, refund }

enum LedgerParty { customer, driver, offtaker, platform }

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.kind,
    required this.party,
    required this.partyId,
    required this.amount,
    required this.note,
    required this.at,
  });

  final String id;
  final String orderId;
  final String orderReference;
  final LedgerKind kind;
  final LedgerParty party;

  /// User id of the party whose account this touches (empty for platform).
  final String partyId;
  final double amount;
  final String note;
  final DateTime at;

  /// Positive when money goes to the party, negative when it leaves them.
  double get signedForParty => switch (kind) {
        LedgerKind.escrowIn => -amount,
        LedgerKind.release => amount,
        LedgerKind.fee => amount,
        LedgerKind.refund => amount,
      };
}
