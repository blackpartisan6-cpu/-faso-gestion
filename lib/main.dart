
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StoreDB.instance.database;
  runApp(const FasoGestionApp());
}

final money = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: 'FCFA',
  decimalDigits: 0,
);

class StoreDB {
  StoreDB._();

  static final instance = StoreDB._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final path = p.join(await getDatabasesPath(), 'faso_gestion.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT,
            buy REAL NOT NULL,
            sell REAL NOT NULL,
            qty REAL NOT NULL,
            alert REAL NOT NULL DEFAULT 5
          )
        ''');

        await db.execute('''
          CREATE TABLE sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER,
            product_name TEXT,
            qty REAL,
            unit_price REAL,
            total REAL,
            profit REAL,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT,
            amount REAL,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT,
            balance REAL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE suppliers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT,
            balance REAL DEFAULT 0
          )
        ''');
      },
    );

    return _db!;
  }

  Future<List<Map<String, Object?>>> rows(String table) async {
    return (await database).query(table, orderBy: 'id DESC');
  }

  Future<int> add(String table, Map<String, Object?> values) async {
    return (await database).insert(table, values);
  }

  Future<int> update(
    String table,
    Map<String, Object?> values,
    int id,
  ) async {
    return (await database).update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class FasoGestionApp extends StatelessWidget {
  const FasoGestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Faso Gestion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16834A),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  final pages = const [
    Dashboard(),
    ProductsPage(),
    SalesPage(),
    ExpensesPage(),
    SimpleDirectory(table: 'customers', title: 'Clients'),
    SimpleDirectory(table: 'suppliers', title: 'Fournisseurs'),
  ];

  final labels = [
    'Accueil',
    'Stock',
    'Ventes',
    'Dépenses',
    'Clients',
    'Fournisseurs',
  ];

  final icons = [
    Icons.dashboard,
    Icons.inventory_2,
    Icons.point_of_sale,
    Icons.receipt_long,
    Icons.people,
    Icons.local_shipping,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.store, color: Colors.green),
            SizedBox(width: 10),
            Text(
              'Faso Gestion',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Faso Gestion',
                applicationVersion: '1.0',
                children: const [
                  Text('Application de gestion de commerce.'),
                ],
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
        },
        destinations: List.generate(
          labels.length,
          (i) => NavigationDestination(
            icon: Icon(icons[i]),
            label: labels[i],
          ),
        ),
      ),
      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => showProductForm(
                context,
                () => setState(() {}),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Produit'),
            )
          : tab == 2
              ? FloatingActionButton.extended(
                  onPressed: () => showSaleForm(
                    context,
                    () => setState(() {}),
                  ),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Vendre'),
                )
              : tab == 3
                  ? FloatingActionButton.extended(
                      onPressed: () => showExpenseForm(
                        context,
                        () => setState(() {}),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Dépense'),
                    )
                  : null,
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Future<Map<String, double>> load() async {
    final db = await StoreDB.instance.database;

    final sales = await db.rawQuery(
      "SELECT COALESCE(SUM(total),0) t, "
      "COALESCE(SUM(profit),0) b FROM sales "
      "WHERE date(created_at)=date('now','localtime')",
    );

    final expenses = await db.rawQuery(
      "SELECT COALESCE(SUM(amount),0) a FROM expenses "
      "WHERE date(created_at)=date('now','localtime')",
    );

    final low = await db.rawQuery(
      'SELECT COUNT(*) n FROM products WHERE qty <= alert',
    );

    return {
      'sales': (sales.first['t'] as num).toDouble(),
      'profit': (sales.first['b'] as num).toDouble(),
      'expenses': (expenses.first['a'] as num).toDouble(),
      'low': (low.first['n'] as num).toDouble(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Bonjour 👋',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('Voici le résumé de votre commerce aujourd’hui.'),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  StatCard(
                    'Ventes du jour',
                    money.format(data['sales']),
                    Icons.point_of_sale,
                    Colors.green,
                  ),
                  StatCard(
                    'Bénéfice brut',
                    money.format(data['profit']),
                    Icons.trending_up,
                    Colors.blue,
                  ),
                  StatCard(
                    'Dépenses',
                    money.format(data['expenses']),
                    Icons.payments,
                    Colors.orange,
                  ),
                  StatCard(
                    'Stocks faibles',
                    data['low']!.toInt().toString(),
                    Icons.warning_amber,
                    Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Conseil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Ajoute d’abord tes produits et leurs quantités '
                'pour commencer à enregistrer les ventes.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard(
    this.title,
    this.value,
    this.icon,
    this.color, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: StoreDB.instance.rows('products'),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];

        final list = rows.where((row) {
          return '${row['name']}'
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher un produit',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => query = value);
                },
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      'Aucun produit',
                      'Appuie sur Produit pour ajouter ton premier article.',
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final row = list[index];
                        final low = (row['qty'] as num) <=
                            (row['alert'] as num);

                        return Card(
                          child: ListTile(
                            title: Text(
                              '${row['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${row['category'] ?? 'Sans catégorie'}'
                              ' • Achat ${money.format(row['buy'])}'
                              ' • Vente ${money.format(row['sell'])}',
                            ),
                            leading: CircleAvatar(
                              backgroundColor: low
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              child: Icon(
                                Icons.inventory_2,
                                color: low ? Colors.red : Colors.green,
                              ),
                            ),
                            trailing: Text(
                              '${row['qty']} en stock',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: low ? Colors.red : Colors.green,
                              ),
                            ),
                            onTap: () => showProductForm(
                              context,
                              () => setState(() {}),
                              product: row,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: StoreDB.instance.rows('sales'),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];

        if (rows.isEmpty) {
          return const EmptyState(
            'Aucune vente',
            'Les ventes enregistrées apparaîtront ici.',
          );
        }

        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.receipt),
                ),
                title: Text(
                  '${row['product_name']} × ${row['qty']}',
                ),
                subtitle: Text('${row['created_at']}'),
                trailing: Text(
                  money.format(row['total']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: StoreDB.instance.rows('expenses'),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];

        if (rows.isEmpty) {
          return const EmptyState(
            'Aucune dépense',
            'Enregistre le loyer, transport, électricité, etc.',
          );
        }

        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];

            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text('${row['label']}'),
                subtitle: Text('${row['created_at']}'),
                trailing: Text(money.format(row['amount'])),
              ),
            );
          },
        );
      },
    );
  }
}

class SimpleDirectory extends StatefulWidget {
  final String table;
  final String title;

  const SimpleDirectory({
    super.key,
    required this.table,
    required this.title,
  });

  @override
  State<SimpleDirectory> createState() => _SimpleDirectoryState();
}

class _SimpleDirectoryState extends State<SimpleDirectory> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: StoreDB.instance.rows(widget.table),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () {
                  showContactForm(
                    context,
                    widget.table,
                    () => setState(() {}),
                  );
                },
                icon: const Icon(Icons.add),
                label: Text(
                  'Ajouter ${widget.title.toLowerCase()}',
                ),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? EmptyState(
                      'Aucun ${widget.title.toLowerCase()}',
                      'Ajoute tes contacts ici.',
                    )
                  : ListView(
                      children: rows.map((row) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text('${row['name']}'),
                            subtitle: Text('${row['phone'] ?? ''}'),
                            trailing: Text(
                              money.format(row['balance'] ?? 0),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String description;

  const EmptyState(this.title, this.description, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 52,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

Widget field(
  TextEditingController controller,
  String label, {
  bool number = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

Future<void> showProductForm(
  BuildContext context,
  VoidCallback done, {
  Map<String, Object?>? product,
}) async {
  final name = TextEditingController(
    text: '${product?['name'] ?? ''}',
  );
  final category = TextEditingController(
    text: '${product?['category'] ?? ''}',
  );
