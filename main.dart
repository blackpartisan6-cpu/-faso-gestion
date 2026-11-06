
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StoreDB.instance.database;
  runApp(const FasoGestionApp());
}

final money = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

class StoreDB {
  StoreDB._();
  static final instance = StoreDB._();
  Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'faso_gestion.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, category TEXT, buy REAL NOT NULL, sell REAL NOT NULL, qty REAL NOT NULL, alert REAL NOT NULL DEFAULT 5)''');
      await db.execute('''CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER, product_name TEXT, qty REAL, unit_price REAL, total REAL, profit REAL, created_at TEXT)''');
      await db.execute('''CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, label TEXT, amount REAL, created_at TEXT)''');
      await db.execute('''CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, balance REAL DEFAULT 0)''');
      await db.execute('''CREATE TABLE suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, balance REAL DEFAULT 0)''');
    });
    return _db!;
  }
  Future<List<Map<String,Object?>>> rows(String table) async => (await database).query(table, orderBy: 'id DESC');
  Future<int> add(String table, Map<String,Object?> values) async => (await database).insert(table, values);
  Future<int> update(String table, Map<String,Object?> values, int id) async => (await database).update(table, values, where:'id=?', whereArgs:[id]);
  Future<int> delete(String table, int id) async => (await database).delete(table, where:'id=?', whereArgs:[id]);
}

class FasoGestionApp extends StatelessWidget {
  const FasoGestionApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'Faso Gestion',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16834A)), useMaterial3:true, scaffoldBackgroundColor: const Color(0xFFF5F7F5)),
    home: const HomePage());
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int tab=0;
  final titles=['Tableau de bord','Produits & stock','Ventes','Dépenses','Clients','Fournisseurs'];
  @override Widget build(BuildContext context) {
    final pages=[const Dashboard(),const ProductsPage(),const SalesPage(),const ExpensesPage(),const SimpleDirectory(table:'customers',title:'Clients'),const SimpleDirectory(table:'suppliers',title:'Fournisseurs')];
    return Scaffold(
      appBar: AppBar(title: Row(children:[Container(width:34,height:34,decoration:BoxDecoration(color:Colors.green.shade700,borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.store,color:Colors.white)),const SizedBox(width:10),const Text('Faso Gestion',style:TextStyle(fontWeight:FontWeight.bold))]), actions:[IconButton(onPressed:()=>showAboutDialog(context:context,applicationName:'Faso Gestion',applicationVersion:'MVP 1.0',children:[const Text('Gestion d’alimentation – FCFA (XOF). Les données sont enregistrées sur cet appareil.')]),icon:const Icon(Icons.info_outline))]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [
        NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'Accueil'),
        NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'Stock'),
        NavigationDestination(icon:Icon(Icons.point_of_sale),label:'Ventes'),
        NavigationDestination(icon:Icon(Icons.receipt_long),label:'Dépenses'),
        NavigationDestination(icon:Icon(Icons.people_outline),label:'Contacts'),
      ]),
      floatingActionButton: tab==1?FloatingActionButton.extended(onPressed:()=>showProductForm(context,()=>setState((){})),icon:const Icon(Icons.add),label:const Text('Produit')):tab==2?FloatingActionButton.extended(onPressed:()=>showSaleForm(context,()=>setState((){})),icon:const Icon(Icons.add_shopping_cart),label:const Text('Vendre')):tab==3?FloatingActionButton.extended(onPressed:()=>showExpenseForm(context,()=>setState((){})),icon:const Icon(Icons.add),label:const Text('Dépense')):null,
    );
  }
}

class Dashboard extends StatefulWidget { const Dashboard({super.key}); @override State<Dashboard> createState()=>_DashboardState(); }
class _DashboardState extends State<Dashboard>{
 Future<Map<String,double>> load() async {
  final db=await StoreDB.instance.database;
  final s=await db.rawQuery("SELECT COALESCE(SUM(total),0) t, COALESCE(SUM(profit),0) b FROM sales WHERE date(created_at)=date('now','localtime')");
  final e=await db.rawQuery("SELECT COALESCE(SUM(amount),0) a FROM expenses WHERE date(created_at)=date('now','localtime')");
  final low=await db.rawQuery("SELECT COUNT(*) n FROM products WHERE qty<=alert");
  return {'sales':(s.first['t'] as num).toDouble(),'profit':(s.first['b'] as num).toDouble(),'expenses':(e.first['a'] as num).toDouble(),'low':(low.first['n'] as num).toDouble()};
 }
 @override Widget build(BuildContext context)=>FutureBuilder<Map<String,double>>(future:load(),builder:(c,s){
  if(!s.hasData)return const Center(child:CircularProgressIndicator());
  final d=s.data!;
  return RefreshIndicator(onRefresh:()async=>setState((){}),child:ListView(padding:const EdgeInsets.all(16),children:[
   const Text('Bonjour 👋',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const Text('Voici le résumé de votre alimentation aujourd’hui.'),
   const SizedBox(height:18),GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.45,children:[
    StatCard('Ventes du jour',money.format(d['sales']),Icons.point_of_sale,Colors.green),
    StatCard('Bénéfice brut',money.format(d['profit']),Icons.trending_up,Colors.blue),
    StatCard('Dépenses',money.format(d['expenses']),Icons.payments,Colors.orange),
    StatCard('Stocks faibles',d['low']!.toInt().toString(),Icons.warning_amber,Colors.red),
   ]),
   const SizedBox(height:20),const Text('Accès rapide',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:10),
   Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.inventory_2)),title:const Text('Gérer les produits'),subtitle:const Text('Prix, quantités et alertes de stock'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.of(context).maybePop())),
   Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.point_of_sale)),title:const Text('Enregistrer une vente'),subtitle:const Text('Déduire automatiquement le stock'),trailing:const Icon(Icons.chevron_right))),
   const SizedBox(height:12),const Text('Conseil : ajoute d’abord tes produits et leurs quantités pour commencer à enregistrer les ventes.',style:TextStyle(color:Colors.black54))
  ]));
 });
}
class StatCard extends StatelessWidget{final String title,value;final IconData icon;final Color color;const StatCard(this.title,this.value,this.icon,this.color,{super.key});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Icon(icon,color:color),Text(title,style:const TextStyle(color:Colors.black54,fontSize:12)),FittedBox(child:Text(value,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)))])));}
class ProductsPage extends StatefulWidget{const ProductsPage({super.key});@override State<ProductsPage>createState()=>_ProductsPageState();}
class _ProductsPageState extends State<ProductsPage>{String q='';@override Widget build(BuildContext c)=>FutureBuilder<List<Map<String,Object?>>>(future:StoreDB.instance.rows('products'),builder:(c,s){final rows=s.data??[];final list=rows.where((r)=>'${r['name']}'.toLowerCase().contains(q.toLowerCase())).toList();return Column(children:[Padding(padding:const EdgeInsets.all(12),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Rechercher un produit',border:OutlineInputBorder()),onChanged:(v)=>setState(()=>q=v))),Expanded(child:list.isEmpty?const EmptyState('Aucun produit','Appuie sur Produit pour ajouter ton premier article.'):ListView.builder(itemCount:list.length,itemBuilder:(c,i){final r=list[i];final low=(r['qty'] as num)<=(r['alert'] as num);return Card(child:ListTile(title:Text('${r['name']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${r['category']??'Sans catégorie'} • Achat ${money.format(r['buy'])} • Vente ${money.format(r['sell'])}'),leading:CircleAvatar(backgroundColor:low?Colors.red.shade50:Colors.green.shade50,child:Icon(Icons.inventory_2,color:low?Colors.red:Colors.green)),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('${r['qty']}',style:TextStyle(fontWeight:FontWeight.bold,color:low?Colors.red:Colors.green)),const Text('en stock',style:TextStyle(fontSize:10))]),onTap:()=>showProductForm(c,()=>setState((){}),product:r));}))) ]);}}
class SalesPage extends StatefulWidget{const SalesPage({super.key});@override State<SalesPage>createState()=>_SalesPageState();}
class _SalesPageState extends State<SalesPage>{@override Widget build(BuildContext c)=>FutureBuilder<List<Map<String,Object?>>>(future:StoreDB.instance.rows('sales'),builder:(c,s){final rows=s.data??[];return rows.isEmpty?const EmptyState('Aucune vente','Les ventes enregistrées apparaîtront ici.'):ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.receipt)),title:Text('${r['product_name']} × ${r['qty']}'),subtitle:Text('${r['created_at']}'),trailing:Text(money.format(r['total']),style:const TextStyle(fontWeight:FontWeight.bold)));});});}}
class ExpensesPage extends StatefulWidget{const ExpensesPage({super.key});@override State<ExpensesPage>createState()=>_ExpensesPageState();}
class _ExpensesPageState extends State<ExpensesPage>{@override Widget build(BuildContext c)=>FutureBuilder<List<Map<String,Object?>>>(future:StoreDB.instance.rows('expenses'),builder:(c,s){final rows=s.data??[];return rows.isEmpty?const EmptyState('Aucune dépense','Enregistre le loyer, transport, électricité, etc.'):ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return Card(child:ListTile(leading:const Icon(Icons.receipt_long),title:Text('${r['label']}'),subtitle:Text('${r['created_at']}'),trailing:Text(money.format(r['amount']))));});});}}
class SimpleDirectory extends StatefulWidget{final String table,title;const SimpleDirectory({super.key,required this.table,required this.title});@override State<SimpleDirectory>createState()=>_SimpleDirectoryState();}
class _SimpleDirectoryState extends State<SimpleDirectory>{@override Widget build(BuildContext c)=>FutureBuilder<List<Map<String,Object?>>>(future:StoreDB.instance.rows(widget.table),builder:(c,s){final rows=s.data??[];return Column(children:[Padding(padding:const EdgeInsets.all(12),child:FilledButton.icon(onPressed:()=>showContactForm(c,widget.table,()=>setState((){})),icon:const Icon(Icons.add),label:Text('Ajouter ${widget.title.toLowerCase()}'))),Expanded(child:rows.isEmpty?EmptyState('Aucun ${widget.title.toLowerCase()}','Ajoute tes contacts ici.'):ListView(children:rows.map((r)=>Card(child:ListTile(leading:const Icon(Icons.person),title:Text('${r['name']}'),subtitle:Text('${r['phone']??''}'),trailing:Text(money.format(r['balance']??0)))).toList())))]);}}
class EmptyState extends StatelessWidget{final String title,desc;const EmptyState(this.title,this.desc,{super.key});@override Widget build(BuildContext c)=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.storefront_outlined,size:52,color:Colors.black38),const SizedBox(height:12),Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Text(desc,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54))])));}

Future<void> showProductForm(BuildContext context,VoidCallback done,{Map<String,Object?>? product})async{
 final name=TextEditingController(text:'${product?['name']??''}'),cat=TextEditingController(text:'${product?['category']??''}'),buy=TextEditingController(text:'${product?['buy']??''}'),sell=TextEditingController(text:'${product?['sell']??''}'),qty=TextEditingController(text:'${product?['qty']??''}'),alert=TextEditingController(text:'${product?['alert']??5}');
 await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(product==null?'Nouveau produit':'Modifier le produit'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(name,'Nom du produit'),field(cat,'Catégorie'),field(buy,'Prix d’achat (FCFA)',num:true),field(sell,'Prix de vente (FCFA)',num:true),field(qty,'Quantité en stock',num:true),field(alert,'Alerte sous quantité',num:true)])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),FilledButton(onPressed:()async{if(name.text.trim().isEmpty||double.tryParse(buy.text)==null||double.tryParse(sell.text)==null||double.tryParse(qty.text)==null)return;final data={'name':name.text.trim(),'category':cat.text.trim(),'buy':double.parse(buy.text),'sell':double.parse(sell.text),'qty':double.parse(qty.text),'alert':double.tryParse(alert.text)??5.0};if(product==null){await StoreDB.instance.add('products',data);}else{await StoreDB.instance.update('products',data,product['id'] as int);}if(ctx.mounted)Navigator.pop(ctx);done();},child:const Text('Enregistrer'))]));
}
Widget field(TextEditingController c,String label,{bool num=false})=>Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(controller:c,keyboardType:num?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true)));
Future<void> showSaleForm(BuildContext context,VoidCallback done)async{
 final products=await StoreDB.instance.rows('products');if(!context.mounted)return;
 if(products.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Ajoute d’abord un produit.')));return;}
 int? selected=products.first['id'] as int;final qty=TextEditingController(text:'1');String payment='Espèces';
 await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:const Text('Enregistrer une vente'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'Produit'),items:products.map((p)=>DropdownMenuItem(value:p['id'] as int,child:Text('${p['name']} (${p['qty']} en stock)',overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>set(()=>selected=v)),field(qty,'Quantité',num:true),DropdownButtonFormField<String>(value:payment,decoration:const InputDecoration(labelText:'Paiement'),items:const ['Espèces','Orange Money','Moov Money','Coris Money','À crédit'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>set(()=>payment=v??'Espèces'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),FilledButton(onPressed:()async{final product=products.firstWhere((p)=>p['id']==selected);final n=double.tryParse(qty.text)??0;final stock=(product['qty'] as num).toDouble();if(n<=0||n>stock){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Quantité invalide ou stock insuffisant.')));return;}final price=(product['sell'] as num).toDouble(),cost=(product['buy'] as num).toDouble(),total=n*price;await StoreDB.instance.add('sales',{'product_id':selected,'product_name':product['name'],'qty':n,'unit_price':price,'total':total,'profit':n*(price-cost),'created_at':DateTime.now().toIso8601String()});await StoreDB.instance.update('products',{'qty':stock-n},selected!);if(ctx.mounted)Navigator.pop(ctx);done();},child:const Text('Valider la vente'))])));
}
Future<void> showExpenseForm(BuildContext context,VoidCallback done)async{final label=TextEditingController(),amount=TextEditingController();await showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('Nouvelle dépense'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(label,'Motif'),field(amount,'Montant (FCFA)',num:true)]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),FilledButton(onPressed:()async{final n=double.tryParse(amount.text);if(label.text.trim().isEmpty||n==null||n<=0)return;await StoreDB.instance.add('expenses',{'label':label.text.trim(),'amount':n,'created_at':DateTime.now().toIso8601String()});if(ctx.mounted)Navigator.pop(ctx);done();},child:const Text('Enregistrer'))]));}
Future<void> showContactForm(BuildContext context,String table,VoidCallback done)async{final name=TextEditingController(),phone=TextEditingController();await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(table=='customers'?'Nouveau client':'Nouveau fournisseur'),content:Column(mainAxisSize:MainAxisSize.min,children:[field(name,'Nom'),field(phone,'Téléphone')]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),FilledButton(onPressed:()async{if(name.text.trim().isEmpty)return;await StoreDB.instance.add(table,{'name':name.text.trim(),'phone':phone.text.trim(),'balance':0.0});if(ctx.mounted)Navigator.pop(ctx);done();},child:const Text('Enregistrer'))]));}
