import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
const orange = Color(0xFFFF5A1F);
const dark = Color(0xFF24211F);
const background = Color(0xFFF7F7F7);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FoodieGoApp());
}

class FoodieGoApp extends StatelessWidget {
  const FoodieGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodieGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: orange),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: dark,
        ),
      ),
     home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: orange),
            ),
          );
        }

        if (snapshot.hasData) {
          return const HomePage();
        }

        return const AuthPage();
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isLogin = true;
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _email.text.trim();
      final password = _password.text;

      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await credential.user?.updateDisplayName(_name.text.trim());

        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'name': _name.text.trim(),
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = switch (e.code) {
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'This email is already registered.',
        'weak-password' => 'Password must contain at least 6 characters.',
        'invalid-email' => 'Please enter a valid email.',
        _ => e.message ?? 'Authentication failed.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email address first.'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to reset password.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 90,
                      width: 90,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: orange,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'FoodieGo',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin
                          ? 'Welcome back! Let’s find something delicious.'
                          : 'Create your account and start exploring.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _tabButton('Sign In', true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _tabButton('Sign Up', false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (!_isLogin) ...[
                      const Text(
                        'Full name',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Enter your name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (!_isLogin &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Email address',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (!email.contains('@') ||
                            !email.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        hintText: 'Minimum 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hidePassword = !_hidePassword;
                            });
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return 'Enter at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      )
                    else
                      const SizedBox(height: 20),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isLogin ? 'Sign In' : 'Create Account',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String title, bool loginTab) {
    final selected = _isLogin == loginTab;

    return OutlinedButton(
      onPressed: _loading
          ? null
          : () => setState(() => _isLogin = loginTab),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? orange : Colors.white,
        foregroundColor: selected ? Colors.white : dark,
        side: BorderSide(
          color: selected ? orange : Colors.black12,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(title),
    );
  }
}

class FoodItem {
  final String id;
  final String name;
  final String category;
  final int price;
  final String emoji;
  final String imageUrl;
  final bool available;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.emoji,
    required this.imageUrl,
    required this.available,
  });

  factory FoodItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return FoodItem(
      id: doc.id,
      name: (data['name'] ?? 'Food').toString(),
      category: (data['category'] ?? 'Other').toString(),
      price: (data['price'] as num?)?.toInt() ?? 0,
      emoji: (data['emoji'] ?? '🍽️').toString(),
      imageUrl: (data['imageUrl'] ?? data['image'] ?? '').toString(),
      available: data['available'] as bool? ?? true,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();
  final Map<String, int> cart = {};

  String selectedCategory = 'All';
  int navIndex = 0;
  bool placingOrder = false;

  CollectionReference<Map<String, dynamic>> get foods =>
      FirebaseFirestore.instance.collection('foods');

  CollectionReference<Map<String, dynamic>> get orders =>
      FirebaseFirestore.instance.collection('orders');

  int quantity(String id) => cart[id] ?? 0;

  int get cartCount =>
      cart.values.fold(0, (sum, q) => sum + q);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void changeQuantity(String id, int change) {
    setState(() {
      final next = quantity(id) + change;

      if (next <= 0) {
        cart.remove(id);
      } else {
        cart[id] = next;
      }
    });
  }

  String photoFor(FoodItem food) {
    // Prefer the exact photo URL saved on this food's Firestore document.
    if (food.imageUrl.trim().startsWith('https://')) {
      return food.imageUrl.trim();
    }

    final name = food.name.toLowerCase().replaceAll('_', ' ').trim();
    // Item-specific photos prevent every item in a category using one image.
    const itemPhotos = <String, String>{
      'burger': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=700&q=85',
      'cheese burger': 'https://images.unsplash.com/photo-1553979459-d2229ba7433a?auto=format&fit=crop&w=700&q=85',
      'chicken burger': 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?auto=format&fit=crop&w=700&q=85',
      'pizza': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=700&q=85',
      'cheese pizza': 'https://images.unsplash.com/photo-1571407970349-bc81e7e96d47?auto=format&fit=crop&w=700&q=85',
      'pepperoni pizza': 'https://images.unsplash.com/photo-1628840042765-356cda07504e?auto=format&fit=crop&w=700&q=85',
      'chicken biryani': 'https://images.unsplash.com/photo-1563379091339-03246963d96c?auto=format&fit=crop&w=700&q=85',
      'biryani': 'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?auto=format&fit=crop&w=700&q=85',
      'fried rice': 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=700&q=85',
      'veg pulao': 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=700&q=85',
      'dosa': 'https://images.unsplash.com/photo-1668236543090-82eba5ee5976?auto=format&fit=crop&w=700&q=85',
      'masala dosa': 'https://images.unsplash.com/photo-1630383249896-424e482df921?auto=format&fit=crop&w=700&q=85',
      'idli': 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=700&q=85',
      'vada': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=700&q=85',
      'noodles': 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=700&q=85',
      'chow mein': 'https://images.unsplash.com/photo-1585032226651-759b368d7246?auto=format&fit=crop&w=700&q=85',
      'sandwich': 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=700&q=85',
      'french fries': 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=700&q=85',
      'ice cream': 'https://images.unsplash.com/photo-1560008581-09826d1de69e?auto=format&fit=crop&w=700&q=85',
      'cake': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=700&q=85',
      'coffee': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=700&q=85',
      'juice': 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?auto=format&fit=crop&w=700&q=85',
    };
    if (itemPhotos.containsKey(name)) return itemPhotos[name]!;

    // Match the most specific item words first, then use category fallback.
    if (name.contains('pepperoni')) return itemPhotos['pepperoni pizza']!;
    if (name.contains('cheese') && name.contains('pizza')) return itemPhotos['cheese pizza']!;
    if (name.contains('pizza')) return itemPhotos['pizza']!;
    if (name.contains('chicken') && name.contains('burger')) return itemPhotos['chicken burger']!;
    if (name.contains('burger')) return itemPhotos['burger']!;
    if (name.contains('biryani')) return itemPhotos['chicken biryani']!;
    if (name.contains('pulao')) return itemPhotos['veg pulao']!;
    if (name.contains('rice')) return itemPhotos['fried rice']!;
    if (name.contains('masala dosa')) return itemPhotos['masala dosa']!;
    if (name.contains('dosa')) return itemPhotos['dosa']!;
    if (name.contains('idli')) return itemPhotos['idli']!;
    if (name.contains('vada')) return itemPhotos['vada']!;
    if (name.contains('noodle')) return itemPhotos['noodles']!;
    if (name.contains('sandwich')) return itemPhotos['sandwich']!;
    if (name.contains('fries')) return itemPhotos['french fries']!;
    if (name.contains('ice cream')) return itemPhotos['ice cream']!;
    if (name.contains('cake')) return itemPhotos['cake']!;
    if (name.contains('coffee')) return 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=700&q=85';
    if (name.contains('juice') || name.contains('drink')) return itemPhotos['juice']!;
    return 'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=700&q=85';
  }

  Future<void> placeOrder(
    List<FoodItem> availableFoods,
  ) async {
    if (cart.isEmpty || placingOrder) return;

    final foodMap = {
      for (final food in availableFoods) food.id: food,
    };

    final items = <Map<String, dynamic>>[];
    int subtotal = 0;

    for (final entry in cart.entries) {
      final food = foodMap[entry.key];

      if (food == null || !food.available) continue;

      final lineTotal = food.price * entry.value;
      subtotal += lineTotal;

      items.add({
        'foodId': food.id,
        'name': food.name,
        'price': food.price,
        'quantity': entry.value,
        'lineTotal': lineTotal,
      });
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add available food items.'),
        ),
      );
      return;
    }

    final fee = subtotal >= 499 ? 0 : 25;

    setState(() => placingOrder = true);

    try {
      final order = await orders.add({
        'items': items,
        'subtotal': subtotal,
        'deliveryFee': fee,
        'total': subtotal + fee,
        'status': 'placed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        cart.clear();
        placingOrder = false;
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 50,
          ),
          title: const Text('Order placed!'),
          content: Text(
            'Your order was saved to Firebase.\n\n'
            'Order ID: ${order.id}\n'
            'Total: ₹${subtotal + fee}',
          ),
          actions: [
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() => placingOrder = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Firebase error: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => placingOrder = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: foods.orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Foods load avvaledu.\n'
                  'Firestore rules check cheyyandi.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: orange,
              ),
            ),
          );
        }

        final allFoods = snapshot.data!.docs
            .map(FoodItem.fromDoc)
            .where((food) => food.available)
            .toList();

        if (navIndex == 3) {
          return buildProfile();
        }

        final categories = <String>[
          'All',
          ...{
            for (final food in allFoods)
              food.category,
          },
        ];

        final search =
            searchController.text.toLowerCase().trim();

        final visibleFoods = allFoods.where((food) {
          final categoryMatch =
              selectedCategory == 'All' ||
              food.category == selectedCategory;

          final searchMatch =
              food.name.toLowerCase().contains(search) ||
              food.category.toLowerCase().contains(search);

          return categoryMatch && searchMatch;
        }).toList();

        final subtotal = allFoods.fold<int>(
          0,
          (sum, food) =>
              sum + food.price * quantity(food.id),
        );

        final fee =
            subtotal == 0 || subtotal >= 499 ? 0 : 25;

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: buildHeader()),
                SliverToBoxAdapter(child: buildSearch()),
                SliverToBoxAdapter(child: buildBanner()),
                SliverToBoxAdapter(
                  child: sectionTitle(
                    'Explore categories',
                    'Swipe to explore',
                  ),
                ),
                SliverToBoxAdapter(
                  child: buildCategories(categories),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      18, 24, 18, 12,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Popular near you',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: dark,
                            ),
                          ),
                        ),
                        Text(
                          '${visibleFoods.length} items',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (visibleFoods.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text('No food items found.'),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      16, 0, 16, 24,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            buildFoodCard(visibleFoods[index]),
                        childCount: visibleFoods.length,
                      ),
                    ),
                  ),
                if (cart.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          priceRow('Subtotal', subtotal),
                          priceRow('Delivery fee', fee),
                          const Divider(),
                          priceRow(
                            'Total',
                            subtotal + fee,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: navIndex,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFFFE3D8),
            onDestinationSelected: (index) {
              setState(() => navIndex = index);

              if (index == 2) showCart();

              if (index == 1) {
                FocusScope.of(context)
                    .requestFocus(FocusNode());
              }

            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                label: 'Cart',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
          floatingActionButton: cartCount == 0
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  onPressed: showCart,
                  icon: const Icon(
                    Icons.shopping_bag_outlined,
                  ),
                  label: Text('View cart • $cartCount'),
                ),
        );
      },
    );
  }

  Widget buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FoodieGo',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: dark,
                  ),
                ),
                SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: orange,
                      size: 14,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Delivering to your location',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: showCart,
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(
                Icons.shopping_bag_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: TextField(
        controller: searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search dishes, restaurants...',
          prefixIcon: const Icon(
            Icons.search,
            color: orange,
          ),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget buildBanner() {
    return Container(
      height: 178,
      margin: const EdgeInsets.fromLTRB(18, 20, 18, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: dark,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: 0,
            bottom: 0,
            width: 190,
            child: Image.network(
              'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=700&q=85',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Text(
                  '🍕',
                  style: TextStyle(fontSize: 90),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    dark,
                    dark.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0.2, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'TASTY DEALS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Good food.\nGood mood.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fresh picks, delivered fast',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: dark,
              ),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCategories(List<String> categories) {
    const icons = <String, IconData>{
      'All': Icons.grid_view_rounded,
      'Pizza': Icons.local_pizza_rounded,
      'Burger': Icons.lunch_dining_rounded,
      'Biryani': Icons.rice_bowl_rounded,
      'South Indian': Icons.breakfast_dining_rounded,
      'Curry': Icons.soup_kitchen_rounded,
      'Rice': Icons.rice_bowl,
      'Noodles': Icons.ramen_dining_rounded,
      'Starters': Icons.tapas_rounded,
      'Dessert': Icons.icecream_rounded,
      'Drinks': Icons.local_cafe_rounded,
      'Sandwich': Icons.lunch_dining_rounded,
    };

    return SizedBox(
      height: 105,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected =
              selectedCategory == category;

          return GestureDetector(
            onTap: () {
              setState(() => selectedCategory = category);
            },
            child: SizedBox(
              width: 74,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 180),
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: selected ? orange : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? orange
                            : const Color(0xFFEEEEEE),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: orange.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      icons[category] ??
                          Icons.restaurant,
                      color:
                          selected ? Colors.white : dark,
                      size: 29,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: selected ? orange : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildFoodCard(FoodItem food) {
    final qty = quantity(food.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 126,
            height: 135,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  photoFor(food),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(
                    color: const Color(0xFFFFF0E8),
                    alignment: Alignment.center,
                    child: Text(
                      food.emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: Color(0xFFFFB300),
                        ),
                        SizedBox(width: 2),
                        Text(
                          '4.5',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                13, 12, 12, 12,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    food.category.toUpperCase(),
                    style: const TextStyle(
                      color: orange,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    food.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: Colors.grey,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '20–30 min',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹${food.price}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (qty == 0)
                        SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: () =>
                                changeQuantity(food.id, 1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: orange,
                              side: const BorderSide(
                                color: orange,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'ADD',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              qtyButton(
                                Icons.remove,
                                () => changeQuantity(
                                  food.id,
                                  -1,
                                ),
                              ),
                              Text(
                                '$qty',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              qtyButton(
                                Icons.add,
                                () => changeQuantity(
                                  food.id,
                                  1,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget qtyButton(
    IconData icon,
    VoidCallback onPressed,
  ) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints:
          const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 17,
        color: Colors.white,
      ),
    );
  }

  Widget priceRow(
    String label,
    int amount, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold
                    ? FontWeight.w900
                    : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '₹$amount',
            style: TextStyle(
              fontWeight: bold
                  ? FontWeight.w900
                  : FontWeight.w600,
              fontSize: bold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  void showCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final entries = cart.entries.toList();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your cart',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$cartCount item(s) selected',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text('Your cart is empty.'),
                      ),
                    )
                  else
                    ...entries.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor:
                              Color(0xFFFFF0E8),
                          child: Icon(
                            Icons.restaurant,
                            color: orange,
                          ),
                        ),
                        title: Text(
                          entry.key.replaceAll('_', ' '),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Quantity: ${entry.value}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                changeQuantity(
                                  entry.key,
                                  -1,
                                );
                                setSheetState(() {});
                              },
                              icon: const Icon(
                                Icons.remove_circle_outline,
                              ),
                            ),
                            Text('${quantity(entry.key)}'),
                            IconButton(
                              onPressed: () {
                                changeQuantity(
                                  entry.key,
                                  1,
                                );
                                setSheetState(() {});
                              },
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: orange,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                      onPressed: placingOrder
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);

                              final result = await foods.get();

                              if (!mounted) return;

                              final availableFoods = result.docs
                                  .map(FoodItem.fromDoc)
                                  .where((f) => f.available)
                                  .toList();

                              await placeOrder(
                                availableFoods,
                              );
                            },
                      child: Text(
                        placingOrder
                            ? 'Placing order...'
                            : 'Place order',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  Widget buildProfile() {
    final user = FirebaseAuth.instance.currentUser;
    final userDoc = user == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(user.uid);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        automaticallyImplyLeading: false,
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to view your profile.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userDoc!.snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? <String, dynamic>{};
                final displayName = (data['name'] ?? user.displayName ?? 'FoodieGo User').toString();
                final email = (data['email'] ?? user.email ?? 'Email not available').toString();
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8A50)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white,
                            child: Text(
                              displayName.trim().isEmpty ? 'F' : displayName.trim()[0].toUpperCase(),
                              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: orange),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(displayName, textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 5),
                          Text(email, textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Colors.white)),
                          const SizedBox(height: 12),
                          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.verified_user_outlined, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('FoodieGo member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Account details', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    _profileInfoTile(Icons.person_outline, 'Full name', displayName),
                    _profileInfoTile(Icons.email_outlined, 'Email address', email),
                    _profileInfoTile(Icons.security_outlined, 'Account status', 'Signed in securely'),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: orange,
                        side: const BorderSide(color: orange),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE3D8),
        onDestinationSelected: (index) {
          setState(() => navIndex = index);
          if (index == 2) showCart();
          if (index == 1) FocusScope.of(context).requestFocus(FocusNode());
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _profileInfoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: const Color(0xFFFFF0E8), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: orange)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ])),
      ]),
    );
  }

}