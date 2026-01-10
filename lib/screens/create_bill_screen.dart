import 'package:flutter/material.dart';
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
  int quantity = 1;
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

    // Restore bill state if it exists
    final billState = BillState();
    if (billState.hasSavedBill()) {
      billItems = billState.billItems;
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

    // Check if item already exists in bill
    int existingIndex = billItems.indexWhere(
      (item) =>
          item['name'].toLowerCase() == selected['name'].toLowerCase() &&
          item['price'] == price,
    );

    if (existingIndex != -1) {
      // Item exists, update quantity and total
      total -= billItems[existingIndex]['total'];
      billItems[existingIndex]['qty'] += quantity;
      billItems[existingIndex]['total'] =
          billItems[existingIndex]['qty'] * price;
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

    quantity = 1;
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

      // First, ask for "Invoice For" (customer/client name)
      String invoiceFor = '';
      await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final invoiceController = TextEditingController();
          return AlertDialog(
            title: const Text('Invoice For'),
            content: TextField(
              controller: invoiceController,
              decoration: const InputDecoration(
                labelText: 'Customer/Client Name',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        // Quantity Input
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            prefixIcon: const Icon(Icons.shopping_cart),
                          ),
                          onChanged: (val) {
                            quantity = int.tryParse(val) ?? 1;
                          },
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
                                        subtitle: Text(
                                          'Qty: ${item['qty']} × ₹${item['price'].toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              color: appPrimaryColor),
                                        ),
                                        trailing: Text(
                                          '₹${item['total'].toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: appPrimaryColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onLongPress: () {
                                          setState(() {
                                            total -= item['total'];
                                            billItems.removeAt(index);
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                // Fixed Total Section at Bottom
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: appPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
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
                        '₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: appPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Additions Section
                GestureDetector(
                  onTap: () => _showAdditionsMenu(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: appPrimaryColor, width: 2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Additions',
                          style: TextStyle(
                            fontSize: 14,
                            color: appPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.add_circle_outline,
                            color: appPrimaryColor, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Generate & Share Button (Fixed at Bottom)
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
    final controller = TextEditingController(text: packingCost.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Packing Cost'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixIcon: Icon(Icons.local_shipping),
          ),
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
    final controller = TextEditingController(text: previousBalance.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Previous Balance'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixIcon: Icon(Icons.history),
          ),
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
}
