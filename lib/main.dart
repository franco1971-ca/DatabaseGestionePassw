import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PasswordApp(),
    );
  }
}

class PasswordApp extends StatefulWidget {
  const PasswordApp({super.key});

  @override
  State<PasswordApp> createState() => _PasswordAppState();
}

class _PasswordAppState extends State<PasswordApp>
    with SingleTickerProviderStateMixin {
  List<Map<String, String>> accounts = [];
  List<Map<String, String>> filteredAccounts = [];

  final serviceController = TextEditingController();
  final userController = TextEditingController();
  final passController = TextEditingController();
  final searchController = TextEditingController();

  late AnimationController _buttonController;

  @override
  void initState() {
    super.initState();
    loadAccounts();

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 0.1,
    );
  }

  @override
  void dispose() {
    _buttonController.dispose();
    super.dispose();
  }

  // Pulsante animato glow + rimbalzo
  Widget glowButton({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTapDown: (_) => _buttonController.forward(),
      onTapUp: (_) {
        _buttonController.reverse();
        onTap();
      },
      onTapCancel: () => _buttonController.reverse(),
      child: AnimatedBuilder(
        animation: _buttonController,
        builder: (context, widgetChild) {
          return Transform.scale(
            scale: 1 - _buttonController.value,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 100),
              builder: (context, value, childWidget) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2 + 0.3 * value),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: childWidget,
                );
              },
              child: widgetChild,
            ),
          );
        },
        child: child,
      ),
    );
  }

  Future<void> saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("accounts", jsonEncode(accounts));
    applyFilter();
  }

  Future<void> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString("accounts");
    if (data != null) {
      setState(() {
        accounts = List<Map<String, String>>.from(
          jsonDecode(data).map((x) => Map<String, String>.from(x)),
        );
      });
      applyFilter();
    }
  }

  void applyFilter() {
    String query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredAccounts = List.from(accounts);
      } else {
        filteredAccounts = accounts
            .where((acc) => acc["service"]!.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  String generatePassword({int length = 14}) {
    const chars =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%&*";
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }

  void addAccount() {
    if (serviceController.text.isEmpty ||
        userController.text.isEmpty ||
        passController.text.isEmpty) return;

    setState(() {
      accounts.add({
        "service": serviceController.text,
        "username": userController.text,
        "password": passController.text,
      });
    });

    saveAccounts();

    serviceController.clear();
    userController.clear();
    passController.clear();
  }

  void editAccount(int index) {
    final acc = accounts[index];
    final editService = TextEditingController(text: acc["service"]);
    final editUser = TextEditingController(text: acc["username"]);
    final editPass = TextEditingController(text: acc["password"]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifica Account"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editService,
              decoration: const InputDecoration(labelText: "Servizio"),
            ),
            TextField(
              controller: editUser,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            TextField(
              controller: editPass,
              decoration: const InputDecoration(labelText: "Password"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                accounts[index] = {
                  "service": editService.text,
                  "username": editUser.text,
                  "password": editPass.text,
                };
              });
              saveAccounts();
              Navigator.pop(context);
            },
            child: const Text("Salva"),
          ),
        ],
      ),
    );
  }

  void deleteAccountWithConfirmation(int index) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Conferma cancellazione"),
        content: const Text("Sei sicuro di voler cancellare questo account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Si"),
          ),
        ],
      ),
    );

    if (confirm) {
      setState(() {
        accounts.removeAt(index);
      });
      saveAccounts();
    }
  }

  void copyPassword(String password) {
    Clipboard.setData(ClipboardData(text: password));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Password copiata")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Titolo + chiudi app
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: const Text(
                          "Password Manager 🔐",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2),
                        ),
                      ),
                    ),
                    glowButton(
                      onTap: () => SystemNavigator.pop(),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.power_settings_new,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Riga ricerca + pulsante lente animato
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: "Cerca servizio",
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.95),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onChanged: (_) => applyFilter(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    glowButton(
                      onTap: applyFilter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade700,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.search, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Input account
                TextField(
                  controller: serviceController,
                  decoration: InputDecoration(
                    labelText: "Servizio",
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: userController,
                  decoration: InputDecoration(
                    labelText: "Username",
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passController,
                  decoration: InputDecoration(
                    labelText: "Password",
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: const Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 15),

                // Pulsanti Genera Password + Aggiungi Account
                Row(
                  children: [
                    Expanded(
                      child: glowButton(
                        onTap: () {
                          passController.text = generatePassword();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.deepOrangeAccent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.vpn_key, color: Colors.white),
                              SizedBox(width: 8),
                              Text("Genera Password",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: glowButton(
                        onTap: addAccount,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.shade700,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add, color: Colors.white),
                              SizedBox(width: 8),
                              Text("Aggiungi Account",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Lista account
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredAccounts.length,
                    itemBuilder: (context, index) {
                      final acc = filteredAccounts[index];
                      final originalIndex = accounts.indexOf(acc);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            tileColor: Colors.white.withOpacity(0.95),
                            title: Text(
                              acc["service"]!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("User: ${acc["username"]}"),
                                Text(
                                  acc["password"]!,
                                  style: const TextStyle(
                                      fontFamily: 'Courier',
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.teal),
                                  onPressed: () => editAccount(originalIndex),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy,
                                      color: Colors.blueAccent),
                                  onPressed: () =>
                                      copyPassword(acc["password"]!),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.redAccent),
                                  onPressed: () =>
                                      deleteAccountWithConfirmation(
                                          originalIndex),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
