import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterPage extends StatefulWidget {
  final Function(String, String) onRegister;
  const RegisterPage({super.key, required this.onRegister});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _agree = false;
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text.trim();
    if (u.isEmpty || p.isEmpty) {
      _show('Isi semua field');
      return;
    }
    if (!_agree) {
      _show('Setujui syarat untuk melanjutkan');
      return;
    }

    setState(() => _loading = true);

    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('users_map') ?? '{}';
    final Map<String, dynamic> users = jsonDecode(raw);
    if (users.containsKey(u)) {
      setState(() => _loading = false);
      _show('Username sudah terdaftar', Colors.orange);
      return;
    }
    users[u] = p;
    await sp.setString('users_map', jsonEncode(users));

    widget.onRegister(u, p);
    setState(() => _loading = false);
    if (!mounted) return;
    _show('Registrasi sukses', Colors.green);
    Navigator.of(context).pop();
  }

  void _show(String msg, [Color? color]) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF305BA9), // Warna solid utama
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add, size: 64, color: Colors.white),
                      const SizedBox(height: 12),
                      const Text(
                        'Buat Akun',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 18),

                      // Username
                      TextField(
                        controller: _userCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person, color: Colors.white),
                          hintText: 'Username',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Password
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock, color: Colors.white),
                          hintText: 'Password',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _agree,
                            onChanged: (v) => setState(() => _agree = v ?? false),
                            checkColor: Colors.black,
                            fillColor: MaterialStateProperty.all(Colors.white),
                          ),
                          Expanded(
                            child: Text(
                              'Saya setuju data demo disimpan secara lokal',
                              style: TextStyle(color: Colors.white.withOpacity(0.9)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tombol daftar
                      _loading
                          ? const SizedBox(
                              height: 48,
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white)))
                          : GestureDetector(
                              onTap: _register,
                              child: Container(
                                height: 48,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF84BA1E), // Warna solid tombol
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 6))
                                  ],
                                ),
                                child: const Center(
                                  child: Text('Daftar',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                              ),
                            ),
                      const SizedBox(height: 8),

                      // Tombol kembali
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Kembali',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
