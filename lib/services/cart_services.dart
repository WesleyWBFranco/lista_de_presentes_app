import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lista_de_presentes/data/models/cart_item.dart';
import 'package:lista_de_presentes/data/models/present.dart';

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  void addToCart(Present present, String presentId, int quantity) {
    final existing = _items.indexWhere(
      (item) => item.present.name == present.name,
    );

    if (existing != -1) {
      final existingItem = _items[existing];
      final newQuantity = existingItem.selectedQuantity + quantity;

      if (newQuantity > present.quantity) {
        existingItem.selectedQuantity = present.quantity;
      } else {
        existingItem.selectedQuantity = newQuantity;
      }
    } else {
      final safeQuantity =
          quantity > present.quantity ? present.quantity : quantity;
      _items.add(CartItem(present: present, presentId: presentId, selectedQuantity: safeQuantity)); // Adicione presentId
    }

    notifyListeners();
  }

  void increaseQuantity(CartItem item) {
    if (item.selectedQuantity < item.present.quantity) {
      item.selectedQuantity++;
      notifyListeners();
    }
  }

  void decreaseQuantity(CartItem item) {
    if (item.selectedQuantity > 1) {
      item.selectedQuantity--;
      notifyListeners();
    } else {
      _items.remove(item);
      notifyListeners();
    }
  }

  Future<void> confirmPurchaseAndUpdateFirebase() async {
    for (final item in _items) {
      final docRef = FirebaseFirestore.instance
          .collection('presents')
          .doc(item.presentId); // Use item.presentId

      final doc = await docRef.get();
      if (doc.exists) {
        int currentQuantity = doc['quantity'] ?? 0;
        int newQuantity = currentQuantity - item.selectedQuantity;

        await docRef.update({'quantity': newQuantity});

        if (newQuantity <= 0) {
          await docRef.update({'isCompleted': true});
        }
      }
    }
    _items.clear();
    notifyListeners();
  }

  Future<void> savePurchaseHistory() async {
    final purchasesRef = FirebaseFirestore.instance.collection('compras');

    final purchaseItems =
        _items
            .map(
              (item) => {
                'name': item.present.name,
                'quantity': item.selectedQuantity,
                'price': item.present.price,
                'total': item.present.price * item.selectedQuantity,
                'imagePath': item.present.imagePath,
              },
            )
            .toList();

    final totalAmount = _items.fold<double>(
      0,
      (sum, item) => sum + (item.present.price * item.selectedQuantity),
    );

    await purchasesRef.add({
      'items': purchaseItems,
      'total': totalAmount,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}