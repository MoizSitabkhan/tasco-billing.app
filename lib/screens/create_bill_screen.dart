import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database.dart';
import '../utils/pdf_generator.dart';
import '../utils/bill_state.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({super.key});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  List<Map<String, dynamic>> stockItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  List<Map<String, dynamic>> billItems = [];

  int? selectedItemId;
  double quantity = 1.0;
  double customPrice = 0;
  double total = 0;
  double packingCost = 0;
  double previousBalance = 0;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadItems();
    searchController.addListener(_filterItems);

    // Restore bill state if it exists - deep copy the items and ensure correct types
    final billState = BillState();
    if (billState.hasSavedBill()) {
      billItems = List.from(billState.billItems.map((item) {
        final Map<String, dynamic> typedItem = {};
        item.forEach((key, value) {
          typedItem[key.toString()] = value;
        });
        return typedItem;
      }));
      total = billState.total;
      packingCost = billState.packingCost;
      previousBalance = billState.previousBalance;
      billState.clearBill();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    quantityController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> loadItems() async {
    final db = await AppDatabase.db;
    stockItems = await db.query('items');
    filteredItems = stockItems;
    setState(() {});
  }

  void _filterItems() {
    setState(() {
      searchQuery = searchController.text.toLowerCase();
      if (searchQuery.isEmpty) {
        filteredItems = stockItems;
      } else {
        filteredItems = stockItems
            .where((item) =>
                (item['name'] as String).toLowerCase().contains(searchQuery))
            .toList();
      }
    });
  }

  void addToBill() {
    if (selectedItemId == null) return;

    final selected =
        stockItems.firstWhere((item) => item['id'] == selectedItemId);
    double price = customPrice > 0 ? customPrice : selected['price'];
    double itemTotal = price * quantity;

    // Check if item already exists in bill (match by name, case-insensitive)
    int existingIndex = billItems.indexWhere((item) =>
        (item['name'] as String).toLowerCase() ==
        (selected['name'] as String).toLowerCase());

    if (existingIndex != -1) {
      // Item exists, update quantity and total. If custom price provided, update price.
      total -= billItems[existingIndex]['total'];
      billItems[existingIndex]['qty'] =
          (billItems[existingIndex]['qty'] as double) + quantity;
      if (customPrice > 0) {
        billItems[existingIndex]['price'] = price;
      } else {
        price = (billItems[existingIndex]['price'] as num).toDouble();
      }
      billItems[existingIndex]['total'] =
          (billItems[existingIndex]['qty'] as double) * price;
      total += billItems[existingIndex]['total'];
    } else {
      // New item, add it
      billItems.add({
        'name': selected['name'],
        'qty': quantity,
        'price': price,
        'total': itemTotal,
      });
      total += itemTotal;
    }

    quantity = 1.0;
    customPrice = 0;
    selectedItemId = null;
    quantityController.clear();
    priceController.clear();
    searchController.clear();

    setState(() {});
  }

  Future<void> generateAndShare() async {
    try {
      if (billItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add items to the bill first')),
        );
        return;
      }

      // First, ask for "Billed To" (client name)
      String invoiceFor = '';
      await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final invoiceController = TextEditingController();
          return AlertDialog(
            title: const Text('Billed To'),
            content: TextField(
              controller: invoiceController,
              decoration: const InputDecoration(
                labelText: 'Client Name',
                prefixIcon: Icon(Icons.person),
              ),
              autofocus: true,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  invoiceFor = invoiceController.text;
                  Navigator.pop(context);
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (invoiceFor.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a customer name')),
        );
        return;
      }

      final file = await generatePdf(
          billItems, total, packingCost, previousBalance, invoiceFor);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there is a saved bill in the singleton and our local bill is empty,
    // restore it once after frame to ensure the screen shows the saved bill
    final billState = BillState();
    if (billItems.isEmpty && billState.hasSavedBill()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          billItems = List.from(billState.billItems.map((item) {
            final Map<String, dynamic> typedItem = {};
            item.forEach((key, value) {
              typedItem[key.toString()] = value;
            });
            return typedItem;
          }));
          total = billState.total;
          packingCost = billState.packingCost;
          previousBalance = billState.previousBalance;
        });
        // Clear singleton after restoring so it's a one-time restore
        billState.clearBill();
      });
    }

    return WillPopScope(
      onWillPop: () async {
        if (billItems.isEmpty) {
          return true;
        }

        // Show dialog asking if user wants to save bill
        bool? shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save Bill?'),
            content: const Text(
              'You have an incomplete bill. Do you want to save it?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Discard'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );

        if (shouldSave == true) {
          // Save bill state
          final billState = BillState();
          billState.saveBill(billItems, total, packingCost, previousBalance);
        }

        return true;
      },
      child: Scaffold(
          appBar: AppBar(
            title: const Text('Create Bill'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
                    child: Column(
                      children: [
                        // Item Selection with Search
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: appPrimaryColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                                child: TextField(
                                  controller: searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search items...',
                                    prefixIcon:
                                        const Icon(Icons.search, size: 20),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 0),
                                  ),
                                ),
                              ),
                              if (searchQuery.isNotEmpty)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Divider(
                                        height: 1, indent: 16, endIndent: 16),
                                    if (filteredItems.isNotEmpty)
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxHeight: 120),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: filteredItems.length,
                                          itemBuilder: (context, index) {
                                            final item = filteredItems[index];
                                            return ListTile(
                                              title: Text(item['name']),
                                              dense: true,
                                              onTap: () {
                                                setState(() {
                                                  selectedItemId =
                                                      item['id'] as int;
                                                  searchController.clear();
                                                  filteredItems = stockItems;
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          'No items found',
                                          style: const TextStyle(
                                              color: Colors.grey),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (selectedItemId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: appPrimaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    stockItems.firstWhere((item) =>
                                        item['id'] == selectedItemId)['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedItemId = null;
                                      });
                                    },
                                    child: const Icon(Icons.close,
                                        color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        // Quantity Input (supports decimals)
                        TextField(
                          controller: quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            prefixIcon: const Icon(Icons.shopping_cart),
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val) ?? 1.0;
                            // Limit to 1 decimal place
                            quantity = double.parse(parsed.toStringAsFixed(1));
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Custom Price Input
                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Custom Price (Optional)',
                            prefixIcon: const Icon(Icons.currency_rupee),
                            hintText: 'Leave empty to use item price',
                          ),
                          onChanged: (val) {
                            customPrice = double.tryParse(val) ?? 0;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Add Item Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: addToBill,
                            child: const Text('Add Item'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Bill Items List
                        SizedBox(
                          height: 180,
                          child: billItems.isEmpty
                              ? Center(
                                  child: Text(
                                    'No items added yet',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: billItems.length,
                                  itemBuilder: (context, index) {
                                    final item = billItems[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          item['name'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Builder(builder: (context) {
                                          final qty =
                                              (item['qty'] as num).toDouble();
                                          final qtyStr =
                                              qty == qty.roundToDouble()
                                                  ? qty.toStringAsFixed(0)
                                                  : qty.toStringAsFixed(1);
                                          return Text(
                                            'Qty: $qtyStr × ₹${(item['price'] as num).toDouble().toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                color: appPrimaryColor),
                                          );
                                        }),
                                        trailing: Text(
                                          '₹${(item['total'] as num).toDouble().toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: appPrimaryColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onTap: () =>
                                            _showEditBillItemDialog(index),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        // Total & Actions (full width)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: appPrimaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '₹${total.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: appPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 24),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: _showAdditionsMenu,
                                  child: Text(
                                    'Additions',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: appPrimaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                            ),
                            onPressed: generateAndShare,
                            child: const Text(
                              'Generate & Share Bill',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )),
    );
  }

  void _showAdditionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Packing Cost'),
              onTap: () {
                Navigator.pop(context);
                _showPackingCostDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Previous Balance'),
              onTap: () {
                Navigator.pop(context);
                _showPreviousBalanceDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPackingCostDialog() {
    final controller = TextEditingController(
        text: packingCost > 0 ? packingCost.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Packing Cost'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixIcon: Icon(Icons.local_shipping),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d+$'),
            ),
          ],
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              packingCost = 0;
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              packingCost = double.tryParse(controller.text) ?? 0;
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPreviousBalanceDialog() {
    final controller = TextEditingController(
        text: previousBalance > 0 ? previousBalance.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Previous Balance'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixIcon: Icon(Icons.history),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d+$'),
            ),
          ],
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              previousBalance = 0;
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              previousBalance = double.tryParse(controller.text) ?? 0;
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditBillItemDialog(int index) {
    final item = billItems[index];
    final qtyController =
        TextEditingController(text: (item['qty'] as num).toDouble().toString());
    final priceController = TextEditingController(
        text: (item['price'] as num).toDouble().toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d+\.?\d?'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Delete item
              setState(() {
                billItems.removeAt(index);
                total = billItems.fold(
                    0.0, (sum, it) => sum + (it['total'] as num).toDouble());
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(qtyController.text) ??
                  (item['qty'] as num).toDouble();
              final newPrice = double.tryParse(priceController.text) ??
                  (item['price'] as num).toDouble();
              setState(() {
                billItems[index]['qty'] = newQty;
                billItems[index]['price'] = newPrice;
                billItems[index]['total'] = newQty * newPrice;
                total = billItems.fold(
                    0.0, (sum, it) => sum + (it['total'] as num).toDouble());
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
