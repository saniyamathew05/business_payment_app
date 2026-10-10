import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final businessNameController = TextEditingController();

  final locationController = TextEditingController();

  final phoneController = TextEditingController();

  final openingBalanceController = TextEditingController();

  bool isSaving = false;

  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void dispose() {
    businessNameController.dispose();
    locationController.dispose();
    phoneController.dispose();
    openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> saveCustomer() async {
    final businessName = businessNameController.text.trim();

    final location = locationController.text.trim();

    final phone = phoneController.text.trim();

    final openingBalance =
        double.tryParse(openingBalanceController.text.trim()) ?? 0;

    if (businessName.isEmpty || location.isEmpty || phone.isEmpty) {
      _showMessage('Please fill in all required fields.');
      return;
    }

    if (openingBalance < 0) {
      _showMessage('Opening balance cannot be negative.');
      return;
    }

    if (phone.length != 10) {
      _showMessage('Please enter a valid 10-digit phone number.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('You are not logged in to Supabase.');
      }

      final profile = await supabase
          .from('profiles')
          .select('id, name, role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        throw Exception('No profile was found for the logged-in user.');
      }

      if (profile['role'] != 'owner') {
        throw Exception('Your account is not an owner account.');
      }

      await supabase.from('customers').insert({
        'business_name': businessName,
        'location': location,
        'phone': phone,
        'opening_balance': openingBalance,
        'is_active': true,
      });

      if (!mounted) return;

      _showMessage('Customer saved successfully.');

      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      debugPrint('SUPABASE ERROR: ${error.message}');

      if (!mounted) return;

      _showMessage(
        'Supabase error:\n'
        '${error.message}\n'
        'Code: ${error.code}',
      );
    } catch (error) {
      debugPrint('GENERAL ERROR: $error');

      if (!mounted) return;

      _showMessage('Error:\n$error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      appBar: AppBar(
        title: const Text(
          'Add Customer',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.78),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Customer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Create a customer account and set their current balance.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Customer Information',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 6),

                Text(
                  'Enter the basic details of the business.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 18),

                _FormField(
                  controller: businessNameController,
                  label: 'Business Name',
                  hint: 'e.g. ABC Traders',
                  icon: Icons.storefront_outlined,
                  textCapitalization: TextCapitalization.words,
                ),

                const SizedBox(height: 14),

                _FormField(
                  controller: locationController,
                  label: 'Location',
                  hint: 'e.g. Kuttikanam',
                  icon: Icons.location_on_outlined,
                  textCapitalization: TextCapitalization.words,
                ),

                const SizedBox(height: 14),

                _FormField(
                  controller: phoneController,
                  label: 'Phone Number',
                  hint: 'e.g. 9876543210',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                ),

                const SizedBox(height: 26),

                const Text(
                  'Account Information',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 6),

                Text(
                  'Set the amount currently owed by the customer.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 18),

                _FormField(
                  controller: openingBalanceController,
                  label: 'Opening Balance',
                  hint: 'e.g. 5000',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefixText: '₹ ',
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Opening balance is the amount the customer already owes before any new payments or purchases are recorded.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : saveCustomer,
                    icon: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      isSaving ? 'Saving Customer...' : 'Create Customer',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: Text(
                    'Customer information is securely saved to your business database.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
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

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final String? prefixText;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        counterText: maxLength != null ? null : '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}
