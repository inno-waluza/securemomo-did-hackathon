import 'dart:math';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/constants.dart';

class User {
  final String id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'No Name',
      email: json['email']?.toString() ?? '',
    );
  }
}

class SendMoneyPage extends StatefulWidget {
  const SendMoneyPage({Key? key}) : super(key: key);

  @override
  _SendMoneyPageState createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends State<SendMoneyPage> {
  String? currentUserEmail;
  String _inputAmount = '';
  User? selectedUser;
  late Future<List<User>> _usersFuture;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserEmail();
    _usersFuture = fetchUsers();
  }

  Future<void> _fetchCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email != null) {
      setState(() {
        currentUserEmail = email;
      });
    } else {
      debugPrint("No user email found.");
      _showSnackBar("Please log in first.");
    }
  }

  Future<List<User>> fetchUsers() async {
    try {
      final response = await Dio().get(ApiConstants.fetchUsersUrl);
      final List<dynamic> data = response.data;
      final allUsers = data.map((json) => User.fromJson(json)).toList();
      if (currentUserEmail != null) {
        return allUsers.where((user) => user.email != currentUserEmail).toList();
      }
      return allUsers;
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  void _onKeypadPress(String value) {
    setState(() {
      if (value == 'DEL') {
        if (_inputAmount.isNotEmpty) {
          _inputAmount = _inputAmount.substring(0, _inputAmount.length - 1);
        }
      } else if (value == '.' && !_inputAmount.contains('.')) {
        _inputAmount += value;
      } else if (RegExp(r'^\d*\.?\d{0,2}$').hasMatch(_inputAmount + value)) {
        _inputAmount += value;
      }
    });
  }

  void _selectRecipient() async {
    final users = await _usersFuture;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select Recipient',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: TextStyle(color: Colors.blue[800]),
                        ),
                      ),
                      title: Text(
                        user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                      subtitle: Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      onTap: () {
                        setState(() {
                          selectedUser = user;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onContinue() async {
    if (selectedUser == null) {
      _showSnackBar('Please select a recipient.');
      return;
    }
    if (selectedUser!.email == currentUserEmail) {
      _showSnackBar("You can't send money to yourself.");
      return;
    }
    final double? amount = double.tryParse(_inputAmount);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount.');
      return;
    }
    if (currentUserEmail == null) {
      _showSnackBar('User email not available.');
      return;
    }
    setState(() => _isSending = true);
    try {
      final response = await Dio().post(
        ApiConstants.transferUrl,
        data: {
          'amount': amount,
          'sender_email': currentUserEmail,
          'receiver_email': selectedUser!.email,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      debugPrint('Transfer successful: ${response.data}');
      _showSnackBar('Transfer successful!');
      Navigator.pushReplacementNamed(context, '/home');
    } on DioException catch (e) {
      if (e.response != null) {
        debugPrint('Transfer failed [${e.response?.statusCode}]: ${e.response?.data}');
        _showSnackBar('Transfer failed: ${_formatError(e.response?.data)}');
      } else {
        debugPrint('Transfer failed: $e');
        _showSnackBar('Network error: Please try again.');
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
      _showSnackBar('Something went wrong.');
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _formatError(dynamic errorData) {
    if (errorData is Map) {
      return errorData.entries
          .map((entry) => '${entry.key}: ${(entry.value as List).join(', ')}')
          .join('\n');
    }
    return errorData.toString();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background with clip path
          ClipPath(
            clipper: WaveClipper(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.25,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App bar with transparent background
                  AppBar(
                    title: const Text(
                      'Send Money',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),

                  const SizedBox(height: 20),

                  // Recipient selection card
                  GestureDetector(
                    onTap: _selectRecipient,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedUser?.name ?? 'Select Recipient',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (selectedUser != null)
                                  Text(
                                    selectedUser!.email,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Amount display
                  Center(
                    child: Text(
                      _inputAmount.isEmpty ? '\MWK 0.00' : '\MWKS$_inputAmount',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Keypad
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      padding: const EdgeInsets.all(10),
                      children: [
                        '1', '2', '3',
                        '4', '5', '6',
                        '7', '8', '9',
                        '.', '0', 'DEL',
                      ].map((label) {
                        return Material(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(15),
                          elevation: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () => _onKeypadPress(label),
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: label == 'DEL'
                                      ? Colors.red
                                      : Colors.blue[800],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Send Money Button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSending ? null : _onContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: _isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'SEND MONEY',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom clipper for the wave effect
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.8);

    final firstControlPoint = Offset(size.width * 0.25, size.height);
    final firstEndPoint = Offset(size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(
      firstControlPoint.dx, firstControlPoint.dy,
      firstEndPoint.dx, firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.75, size.height * 0.6);
    final secondEndPoint = Offset(size.width, size.height * 0.9);
    path.quadraticBezierTo(
      secondControlPoint.dx, secondControlPoint.dy,
      secondEndPoint.dx, secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}