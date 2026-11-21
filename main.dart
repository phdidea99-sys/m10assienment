import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ==========================================
// SCREEN 1: HOME SCREEN
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  double _totalExpense = 0.0;

  // Fetch data when the screen initializes
  @override
  void initState() {
    super.initState();
    _refreshExpenses();
  }

  // Fetch expenses from database and calculate total
  void _refreshExpenses() async {
    final data = await DatabaseHelper.instance.queryAllExpenses();

    double total = 0.0;
    for (var expense in data) {
      total += (expense['amount'] as num).toDouble();
    }

    setState(() {
      _expenses = data;
      _totalExpense = total;
      _isLoading = false;
    });
  }

  // Delete an expense
  void _deleteExpense(int id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    _refreshExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Total Expenses Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                const Text(
                  'Total Expenses',
                  style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_totalExpense.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // List of Expenses
          Expanded(
            child: _expenses.isEmpty
                ? const Center(child: Text('No expenses added yet.'))
                : ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final expense = _expenses[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(expense['title']),
                    subtitle: Text(
                        '\$${expense['amount'].toStringAsFixed(2)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete,
                          color: Colors.red),
                      onPressed: () =>
                          _deleteExpense(expense['id']),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Floating Action Button to add expense
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to Add screen and wait for result
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
          // If result is true (meaning data was saved), refresh the list
          if (result == true) {
            _refreshExpenses();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==========================================
// SCREEN 2: ADD EXPENSE SCREEN
// ==========================================
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  void _saveExpense() async {
    // 1. Validate Form
    if (_formKey.currentState!.validate()) {
      // 2. Create data map
      final newExpense = {
        'title': _titleController.text,
        'amount': double.parse(_amountController.text),
      };

      // 3. Save to SQLite
      await DatabaseHelper.instance.insertExpense(newExpense);

      // 4. Return to Home Screen
      if (mounted) {
        Navigator.pop(context, true); // Pass 'true' to trigger refresh
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Expense Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an expense title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return 'Please enter a valid number';
                  }
                  if (amount <= 0) {
                    return 'Amount must be greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  child: const Text('Save Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// DATABASE HELPER CLASS
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE expenses ( 
  id $idType, 
  title $textType,
  amount $realType
  )
''');
  }

  // Create
  Future<int> insertExpense(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('expenses', row);
  }

  // Read all
  Future<List<Map<String, dynamic>>> queryAllExpenses() async {
    final db = await instance.database;
    return await db.query('expenses', orderBy: 'id DESC');
  }

  // Delete
  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}