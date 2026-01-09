class Item {
  int? id;
  String name;
  double price;

  Item({this.id, required this.name, required this.price});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'price': price};
  }
}