import 'package:flutter/material.dart';
import '../db/database.dart';
import '../main.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();

  Future<List<Map<String, dynamic>>> fetchItems() async {
    final db = await AppDatabase.db;
    return db.query('items');
  }

  Future<void> addItem() async {
    if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;

    final db = await AppDatabase.db;

    // Check for duplicate item (case insensitive)
    final existingItems = await db.query(
      'items',
      where: 'LOWER(name) = ?',
      whereArgs: [nameCtrl.text.toLowerCase()],
    );

    if (existingItems.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item "${nameCtrl.text}" already exists!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await db.insert('items', {
      'name': nameCtrl.text,
      'price': double.parse(priceCtrl.text),
    });

    nameCtrl.clear();
    priceCtrl.clear();
    setState(() {});
  }

  Future<void> deleteItem(int id) async {
    final db = await AppDatabase.db;
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
    setState(() {});
  }

  Future<void> editItem(int id, String name, double price) async {
    final db = await AppDatabase.db;
    await db.update(
      'items',
      {'name': name, 'price': price},
      where: 'id = ?',
      whereArgs: [id],
    );
    setState(() {});
  }

  void showEditDialog(Map<String, dynamic> item) {
    final editNameCtrl = TextEditingController(text: item['name']);
    final editPriceCtrl = TextEditingController(text: item['price'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editNameCtrl,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editPriceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (editNameCtrl.text.isNotEmpty &&
                  editPriceCtrl.text.isNotEmpty) {
                editItem(
                  item['id'],
                  editNameCtrl.text,
                  double.parse(editPriceCtrl.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.pushNamed(context, '/bill');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Item name',
                prefixIcon: const Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              decoration: InputDecoration(
                labelText: 'Price',
                prefixIcon: const Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: addItem,
                child: const Text('Add Item'),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder(
                future: fetchItems(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final items = snapshot.data!;
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Rs. ${item['price'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: appPrimaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: SizedBox(
                            width: 100,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  color: Colors.black,
                                  onPressed: () => showEditDialog(item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Item'),
                                        content: const Text(
                                            'Are you sure you want to delete this item?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () {
                                              deleteItem(item['id']);
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
