import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pamomo_wallet/presentation/pages/deposit_money_page.dart';
import 'package:pamomo_wallet/presentation/pages/send_money_page.dart';
import 'package:pamomo_wallet/presentation/pages/transaction_history_page.dart';
import 'package:pamomo_wallet/presentation/pages/verification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/constants.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>> _userDataFuture;
  late Future<List<dynamic>> _newsFuture;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _userDataFuture = fetchUserData().then((data) async {
      String email = data['email']?.toString() ?? '';
      if (email.isNotEmpty) {
        _isVerified = await checkUserVerification(email);
      }
      return data;
    });
    _newsFuture = fetchMarketauxNews();
  }

  // Fetch Marketaux news
  Future<List<dynamic>> fetchMarketauxNews() async {
    const String apiKey = "EFrhys38dyn72XgjEtqKt7VMviLgSbkUajGtUjXk";
    const String newsUrl = "https://api.marketaux.com/v1/news/all";

    try {
      final response = await Dio().get(
        newsUrl,
        queryParameters: {
          "api_token": apiKey,
          "symbols": "BTC,ETH,USDT",
          "filter_entities": "true",
          "language": "en",
          "limit": "3",
        },
      );
      if (response.statusCode == 200) {
        return response.data["data"] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint("Marketaux API Error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String email = prefs.getString('user_email') ?? '';
    Map<String, dynamic> data = {};

    if (email.isNotEmpty) {
      data['email'] = email;
      data['name'] = await fetchUserName(email);
      data['balance'] = await fetchUserBalance(email);
      data['send_again_users'] = await fetchSendAgainUsers(email);
    } else {
      data['email'] = "";
      data['name'] = "";
      data['send_again_users'] = [];
    }
    return data;
  }

  Future<String> fetchUserName(String email) async {
    const String usernameUrl = "http://10.0.2.2:8000/api/v1/accounts/get-username/";
    try {
      final response = await Dio().post(
        usernameUrl,
        data: {"email": email},
        options: Options(headers: {"Content-Type": "application/json"}),
      );
      if (response.statusCode == 200) {
        return response.data["username"]?.toString() ?? "";
      }
      return "";
    } catch (e) {
      debugPrint("Username fetch error: $e");
      return "";
    }
  }

  Future<double> fetchUserBalance(String email) async {
    const String balanceUrl = "http://10.0.2.2:8000/api/v1/accounts/get-balance/";
    try {
      final response = await Dio().post(
        balanceUrl,
        data: {"email": email},
        options: Options(headers: {"Content-Type": "application/json"}),
      );
      if (response.statusCode == 200) {
        final balance = response.data["balance"];
        return double.tryParse(balance.toString()) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      debugPrint("Balance fetch error: $e");
      return 0.0;
    }
  }

  Future<List<dynamic>> fetchSendAgainUsers(String email) async {
    final String url = '${ApiConstants.trsfHistoryUrl}?email=$email';
    try {
      final response = await Dio().get(url);
      if (response.statusCode == 200) {
        final List<dynamic> transactions = response.data as List<dynamic>;
        final Map<String, Map<String, dynamic>> uniqueRecipients = {};

        for (final transaction in transactions) {
          final String receiverName = transaction['receiver_name']?.toString() ??
              transaction['receiver']?.split('@').first ?? "User";
          final String avatarUrl = transaction['receiver_avatar']?.toString() ?? '';

          if (receiverName.isNotEmpty && !uniqueRecipients.containsKey(receiverName)) {
            uniqueRecipients[receiverName] = {
              'name': receiverName,
              'avatar': avatarUrl,
              'icon': _getAvatarIcon(receiverName),
              'color': _getAvatarColor(receiverName),
            };
          }
        }
        return uniqueRecipients.values.toList();
      }
      return [];
    } catch (e) {
      debugPrint("Send Again Users error: $e");
      return [];
    }
  }

  IconData _getAvatarIcon(String name) {
    const icons = [
      Icons.person,
      Icons.account_circle,
      Icons.face,
      Icons.people_alt,
    ];
    final hash = name.hashCode.abs();
    return icons[hash % icons.length];
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  Future<bool> checkUserVerification(String email) async {
    const String verificationUrl = "http://10.0.2.2:8000/callback/check-verification/";
    try {
      final response = await Dio().post(verificationUrl, data: {"email": email});
      if (response.statusCode == 200) {
        return response.data["is_verified"] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint("Verification check error: $e");
      return false;
    }
  }

  Future<void> _checkAndNavigate(Widget destination, {String? email}) async {
    bool verified = _isVerified;
    if (!_isVerified && email != null && email.isNotEmpty) {
      verified = await checkUserVerification(email);
    }
    if (verified) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => VerificationPage()));
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _userDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        } else {
          final data = snapshot.data!;
          final balance = data['balance'] is double ? data['balance'] as double : 0.0;
          final name = data['name']?.toString() ?? "";
          final userAvatar = data['avatar']?.toString() ?? '';
          final sendAgainUsers = (data['send_again_users'] is List)
              ? List<dynamic>.from(data['send_again_users'])
              : [];

          return Scaffold(
            backgroundColor: const Color(0xFFD0D0E3),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: userAvatar.isNotEmpty
                        ? NetworkImage(userAvatar)
                        : null,
                    child: userAvatar.isEmpty
                        ? Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text('Hi $name',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                  if (_isVerified) ...[
                    const SizedBox(width: 8),
                    Image.asset('assets/verify.png', width: 16, height: 16),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.black),
                  onPressed: () async {
                    final email = data['email']?.toString() ?? '';
                    await _checkAndNavigate(HomePage(), email: email);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.black),
                  onPressed: _logout,
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance display now uses "MWK" instead of "$"
                  Text('MWK ${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 20),

                  // Send Again Section
                  const Text('Send Again',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: sendAgainUsers.map((user) {
                        final name = user['name'] ?? 'User';
                        final avatarUrl = user['avatar']?.toString() ?? '';
                        final icon = user['icon'] as IconData? ?? Icons.person;
                        final color = user['color'] as Color? ?? Colors.blue;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: color,
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? Icon(icon, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(height: 5),
                              Text(name,
                                  style: const TextStyle(color: Colors.black)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recent Transactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Pay',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          )),
                      GestureDetector(
                        onTap: () async {
                          final email = data['email']?.toString() ?? '';
                          await _checkAndNavigate(
                            TransactionHistoryPage(email: email),
                            email: email,
                          );
                        },
                        child: const Text(
                          'All transactions',
                          style: TextStyle(fontSize: 14, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [], // Your transaction list here
                    ),
                  ),

                  // Market News Section
                  const SizedBox(height: 20),
                  const Text('Market News',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 10),
                  FutureBuilder<List<dynamic>>(
                    future: _newsFuture,
                    builder: (context, newsSnapshot) {
                      if (newsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (newsSnapshot.hasError) {
                        return const Text(
                          'Failed to load news',
                          style: TextStyle(color: Colors.red),
                        );
                      } else if (newsSnapshot.hasData && newsSnapshot.data!.isNotEmpty) {
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: newsSnapshot.data!.length,
                          itemBuilder: (context, index) {
                            final article = newsSnapshot.data![index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: const Icon(Icons.article, color: Colors.blue),
                                title: Text(
                                  article["title"] ?? "No title",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  article["description"] ?? "No description",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  article["source"] ?? "Unknown",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () {
                                  if (article["url"] != null) {
                                    launchUrl(Uri.parse(article["url"]));
                                  }
                                },
                              ),
                            );
                          },
                        );
                      } else {
                        return const Text(
                          'No news available',
                          style: TextStyle(color: Colors.grey),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      colors: [Colors.blue, Colors.purple],
                      text: "Send Money",
                      onPressed: () async {
                        final email = data['email']?.toString() ?? '';
                        await _checkAndNavigate(SendMoneyPage(), email: email);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GradientButton(
                      colors: [Colors.green, Colors.teal],
                      text: "Deposit Money",
                      onPressed: () async {
                        final email = data['email']?.toString() ?? '';
                        await _checkAndNavigate(const DepositMoneyPage(), email: email);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}

class GradientButton extends StatelessWidget {
  final List<Color> colors;
  final String text;
  final VoidCallback onPressed;

  const GradientButton({
    required this.colors,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: LinearGradient(colors: colors),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
