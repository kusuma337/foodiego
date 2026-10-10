
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SeedFoodsApp());
}

class SeedFoodsApp extends StatelessWidget {
  const SeedFoodsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('FoodieGo - Add Foods')),
        body: const SeedFoodsPage(),
      ),
    );
  }
}

class SeedFoodsPage extends StatefulWidget {
  const SeedFoodsPage({super.key});

  @override
  State<SeedFoodsPage> createState() => _SeedFoodsPageState();
}

class _SeedFoodsPageState extends State<SeedFoodsPage> {
  bool loading = false;
  String message = 'Tap the button to add 30 food items.';

  final List<Map<String, dynamic>> foods = [
    {'id':'veg_pizza','name':'Veg Pizza','category':'Pizza','price':199,'emoji':'🍕'},
    {'id':'cheese_pizza','name':'Cheese Pizza','category':'Pizza','price':249,'emoji':'🍕'},
    {'id':'paneer_pizza','name':'Paneer Pizza','category':'Pizza','price':279,'emoji':'🍕'},
    {'id':'burger','name':'Veg Burger','category':'Burger','price':129,'emoji':'🍔'},
    {'id':'cheese_burger','name':'Cheese Burger','category':'Burger','price':159,'emoji':'🍔'},
    {'id':'chicken_burger','name':'Chicken Burger','category':'Burger','price':189,'emoji':'🍔'},
    {'id':'veg_biryani','name':'Veg Biryani','category':'Biryani','price':179,'emoji':'🍚'},
    {'id':'chicken_biryani','name':'Chicken Biryani','category':'Biryani','price':249,'emoji':'🍗'},
    {'id':'mutton_biryani','name':'Mutton Biryani','category':'Biryani','price':329,'emoji':'🍖'},
    {'id':'egg_biryani','name':'Egg Biryani','category':'Biryani','price':199,'emoji':'🍚'},
    {'id':'masala_dosa','name':'Masala Dosa','category':'South Indian','price':99,'emoji':'🥞'},
    {'id':'plain_dosa','name':'Plain Dosa','category':'South Indian','price':79,'emoji':'🥞'},
    {'id':'idli','name':'Idli (3 pcs)','category':'South Indian','price':59,'emoji':'🍘'},
    {'id':'vada','name':'Medu Vada','category':'South Indian','price':69,'emoji':'🍩'},
    {'id':'puri','name':'Puri','category':'South Indian','price':79,'emoji':'🫓'},
    {'id':'paneer_curry','name':'Paneer Butter Masala','category':'Curry','price':219,'emoji':'🍛'},
    {'id':'dal','name':'Dal Tadka','category':'Curry','price':149,'emoji':'🍛'},
    {'id':'chicken_curry','name':'Chicken Curry','category':'Curry','price':229,'emoji':'🍗'},
    {'id':'fried_rice','name':'Veg Fried Rice','category':'Rice','price':149,'emoji':'🍚'},
    {'id':'chicken_rice','name':'Chicken Fried Rice','category':'Rice','price':199,'emoji':'🍚'},
    {'id':'noodles','name':'Veg Noodles','category':'Noodles','price':139,'emoji':'🍜'},
    {'id':'egg_noodles','name':'Egg Noodles','category':'Noodles','price':169,'emoji':'🍜'},
    {'id':'spring_rolls','name':'Spring Rolls','category':'Starters','price':129,'emoji':'🥟'},
    {'id':'french_fries','name':'French Fries','category':'Starters','price':99,'emoji':'🍟'},
    {'id':'chicken_wings','name':'Chicken Wings','category':'Starters','price':219,'emoji':'🍗'},
    {'id':'sandwich','name':'Veg Sandwich','category':'Sandwich','price':109,'emoji':'🥪'},
    {'id':'chocolate_cake','name':'Chocolate Cake','category':'Dessert','price':129,'emoji':'🍰'},
    {'id':'ice_cream','name':'Vanilla Ice Cream','category':'Dessert','price':79,'emoji':'🍨'},
    {'id':'cold_coffee','name':'Cold Coffee','category':'Drinks','price':99,'emoji':'🥤'},
    {'id':'lemon_juice','name':'Fresh Lemon Juice','category':'Drinks','price':59,'emoji':'🍋'},
  ];

  Future<void> addFoods() async {
    setState(() {
      loading = true;
      message = 'Adding foods... Please wait.';
    });

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (final food in foods) {
        final id = food['id'] as String;
        final data = Map<String, dynamic>.from(food);
        data.remove('id');
        data['available'] = true;

        batch.set(
          db.collection('foods').doc(id),
          data,
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      setState(() {
        message = 'Success! ${foods.length} food items added.';
      });
    } catch (e) {
      setState(() {
        message = 'Failed: $e';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : addFoods,
              child: Text(loading ? 'Adding...' : 'Add 30 Foods'),
            ),
          ],
        ),
      ),
    );
  }
}