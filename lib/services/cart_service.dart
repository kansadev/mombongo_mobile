import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mombongo/models/article_data.dart';

part 'cart_service.g.dart';

@HiveType(typeId: 20)
class CartItem {
  @HiveField(0)
  final ArticleData article;
  
  @HiveField(1)
  int quantity;
  
  @HiveField(2)
  double discountPercentage;

  CartItem({
    required this.article,
    this.quantity = 1,
    this.discountPercentage = 0.0,
  });

  // Use the pre-calculated TTC price from API
  double get unitPrice => article.prixVentTTC;
  
  // Use the pre-calculated HT price from API
  double get unitPriceHT => article.prixVentHT;
  
  // Calculate total HT amount
  double get totalHT => unitPriceHT * quantity;
  
  // Calculate total TTC amount
  double get totalTTC => unitPrice * quantity;
  
  // Calculate discount amount (if any cart-level discount is applied)
  double get totalDiscount => totalTTC * (discountPercentage / 100);
  
  // Final price after any cart-level discount
  double get totalPrice => totalTTC - totalDiscount;

  CartItem copyWith({
    ArticleData? article,
    int? quantity,
    double? discountPercentage,
  }) {
    return CartItem(
      article: article ?? this.article,
      quantity: quantity ?? this.quantity,
      discountPercentage: discountPercentage ?? this.discountPercentage,
    );
  }
}

class CartService extends ChangeNotifier {
  static const String _cartBoxName = 'cart_box';
  final List<CartItem> _items = [];
  late Box<CartItem> _cartBox;

  CartService() {
    _init();
  }

  Future<void> _init() async {
    try {
      _cartBox = await Hive.openBox<CartItem>(_cartBoxName);
      await _loadFromCache();
    } catch (e) {
      if (kDebugMode) {
        print('Cart cache incompatible, resetting box: $e');
      }
      await Hive.deleteBoxFromDisk(_cartBoxName);
      _cartBox = await Hive.openBox<CartItem>(_cartBoxName);
      _items.clear();
      notifyListeners();
    }
  }

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
  double get totalDiscount => _items.fold(0.0, (sum, item) => sum + item.totalDiscount);
  double get total => subtotal - totalDiscount;

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  Future<void> _loadFromCache() async {
    try {
      _items.clear();
      _items.addAll(_cartBox.values.toList());
      notifyListeners();
    } catch (e) {
      print('Error loading cart from cache: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      await _cartBox.clear();
      for (var item in _items) {
        await _cartBox.add(item);
      }
    } catch (e) {
      print('Error saving cart to cache: $e');
    }
  }

  void addItem(ArticleData article, {int quantity = 1, double discount = 0.0}) {
    final existingIndex = _items.indexWhere((item) => item.article.idArticle == article.idArticle);
    
    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + quantity,
      );
    } else {
      _items.add(CartItem(
        article: article,
        quantity: quantity,
        discountPercentage: discount,
      ));
    }
    
    _saveToCache();
    notifyListeners();
  }

  void removeItem(int articleId) {
    _items.removeWhere((item) => item.article.idArticle == articleId);
    _saveToCache();
    notifyListeners();
  }

  void updateQuantity(int articleId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(articleId);
      return;
    }

    final index = _items.indexWhere((item) => item.article.idArticle == articleId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
      _saveToCache();
      notifyListeners();
    }
  }

  void updateDiscount(int articleId, double discountPercentage) {
    final index = _items.indexWhere((item) => item.article.idArticle == articleId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(discountPercentage: discountPercentage);
      _saveToCache();
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _saveToCache();
    notifyListeners();
  }

  // Method to clear cart after payment
  void clearAfterPayment() {
    _items.clear();
    _saveToCache();
    notifyListeners();
  }

  bool containsArticle(int articleId) {
    return _items.any((item) => item.article.idArticle == articleId);
  }

  CartItem? getItem(int articleId) {
    try {
      return _items.firstWhere((item) => item.article.idArticle == articleId);
    } catch (e) {
      return null;
    }
  }
}
