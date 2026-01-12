class BillState {
  static final BillState _instance = BillState._internal();

  factory BillState() {
    return _instance;
  }

  BillState._internal();

  List<Map<String, dynamic>> billItems = [];
  double total = 0;
  double packingCost = 0;
  double previousBalance = 0;
  String clientName = '';

  void saveBill(List<Map<String, dynamic>> items, double billTotal,
      double packing, double previousBal,
      {String clientNameParam = ''}) {
    // Clear previous bill first to ensure only 1 bill is saved at a time
    clearBill();
    billItems = List.from(items);
    total = billTotal;
    packingCost = packing;
    previousBalance = previousBal;
    clientName = clientNameParam;
  }

  void clearBill() {
    billItems.clear();
    total = 0;
    packingCost = 0;
    previousBalance = 0;
    clientName = '';
  }

  bool hasSavedBill() {
    return billItems.isNotEmpty;
  }

  void restoreBill() {
    // Bill data is already in memory
  }
}
