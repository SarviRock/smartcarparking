import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_car_parking/services/user_service.dart'; // Ensure this is the correct package
import 'package:url_launcher/url_launcher.dart'; // Added for URL launching
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class PaymentPage extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> userReference;

  const PaymentPage({super.key, required this.userReference});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Payment'),
            centerTitle: true,
            bottom: const TabBar(
              tabs: [
                Tab(text: 'QR Code'),
                Tab(text: 'Balance'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // QR Code Tab
              FutureBuilder<String>(
                future: _calculatePayment(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                        child: Text(snapshot.error?.toString() ?? 'Error'));
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      QrImageView(
                        data: _generateQrData(),
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        snapshot.data!,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
              // Balance Tab
              Center(
                child: StreamBuilder(
                  stream: UserService.getUser(
                      FirebaseAuth.instance.currentUser!.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Text('Error: ${snapshot.error ?? "No data"}');
                    }

                    final userBalance = snapshot.data?.amount ?? 0.0;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Your Balance: \$${userBalance.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Select Reload Amount'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () async {
                                          const url =
                                              "https://buy.stripe.com/test_00gaFrdARbFQcRW6os";
                                          if (await launchUrl(Uri.parse(url))) {
                                            await _reloadBalance(2.0);
                                          }
                                        },
                                        child: const Text('Reload RM2'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          const url =
                                              "https://buy.stripe.com/test_fZe7tf40h5hs9FKbIK";
                                          if (await launchUrl(Uri.parse(url))) {
                                            await _reloadBalance(3.0);
                                          }
                                        },
                                        child: const Text('Reload RM3'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          const url =
                                              "https://buy.stripe.com/test_6oE5l70O55hsdW06or";
                                          if (await launchUrl(Uri.parse(url))) {
                                            await _reloadBalance(5.0);
                                          }
                                        },
                                        child: const Text('Reload RM5'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: const Text('Reload Balance'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _calculatePayment() async {
    final snapshot = await userReference.get();
    if (!snapshot.exists) {
      return 'Error fetching user data';
    }

    final user = ParkUser.fromMap(snapshot.reference, snapshot.data());
    if (user.using == null) {
      return 'No active parking session';
    }

    final durationInMinutes = DateTime.now().difference(user.using!).inMinutes;
    final cost = double.parse(
        ((durationInMinutes < 5 ? 5 : durationInMinutes) * 0.1)
            .toStringAsFixed(2)); // Ensure consistent precision

    if (user.amount < cost) {
      return 'Insufficient balance. Amount to pay: \$${cost.toStringAsFixed(2)}';
    }

    return 'Amount to pay: \$${cost.toStringAsFixed(2)}';
  }

  String _generateQrData() {
    final entryTime = DateTime.now(); // Replace with actual entry time
    final exitTime =
        DateTime.now().add(Duration(hours: 2)); // Replace with actual exit time
    final userId = FirebaseAuth.instance.currentUser!.uid;

    // Calculate the price (e.g., $0.10 per minute, minimum $0.50)
    final durationInMinutes = exitTime.difference(entryTime).inMinutes;
    final price = (durationInMinutes * 0.1)
        .clamp(0.5, double.infinity)
        .toStringAsFixed(2);

    return 'UserID: $userId\nEntry: $entryTime\nExit: $exitTime\nPrice: \$$price';
  }

  Future<void> _reloadBalance(double amount) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Implement logic to reload the user's balance in Firestore
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final user = ParkUser.fromMap(snapshot.reference, snapshot.data()!);

      // Add the reload amount to the user's balance
      final newBalance = user.amount + amount;

      // Update the balance in Firestore
      transaction.update(userRef, {'amount': newBalance});
    });
  }
}
