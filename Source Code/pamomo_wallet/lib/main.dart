import 'package:flutter/material.dart';
import 'package:pamomo_wallet/presentation/pages/home_page.dart';
import 'package:pamomo_wallet/presentation/pages/login_page.dart';
import 'package:pamomo_wallet/presentation/pages/send_money_page.dart';
import 'package:pamomo_wallet/presentation/pages/sign_up_page.dart';
import 'injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pamomo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LoginPage(),
      routes: {
        '/sign_up_page': (context) => SignUpPage(),
        '/login_page': (context) => LoginPage(),
        '/moneyTransfer': (context) => SendMoneyPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}
