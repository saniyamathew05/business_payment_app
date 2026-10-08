import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentSettingsScreen

    extends StatefulWidget {

  const PaymentSettingsScreen({

    super.key,

  });



  @override

  State<PaymentSettingsScreen> createState() =>

      _PaymentSettingsScreenState();

}

class _PaymentSettingsScreenState

    extends State<PaymentSettingsScreen> {

  final SupabaseClient _supabase =

      Supabase.instance.client;



  bool _isLoading = true;

  bool _isSaving = false;



  String _currency = 'INR';

  String _currencySymbol = '₹';



  bool _requireSignature = true;

  bool _allowPaymentNotes = true;



  @override

  void initState() {

    super.initState();

    _loadSettings();

  }



  Future<void> _loadSettings() async {

    try {

      final response = await _supabase

          .from('payment_settings')

          .select()

          .eq('id', 1)

          .maybeSingle();



      if (response != null) {

        setState(() {

          _currency =

              response['currency'] ?? 'INR';



          _currencySymbol =

              response['currency_symbol'] ?? '₹';



          _requireSignature =

              response['require_signature'] ??

                  true;



          _allowPaymentNotes =

              response['allow_payment_notes'] ??

                  true;

        });

      }

    } catch (error) {

      if (mounted) {

        _showSnackBar(

          'Could not load payment settings.',

        );

      }

    } finally {

      if (mounted) {

        setState(() {

          _isLoading = false;

        });

      }

    }

  }



  Future<void> _saveSettings() async {

    setState(() {

      _isSaving = true;

    });



    try {

      await _supabase

          .from('payment_settings')

          .upsert({

        'id': 1,

        'currency': _currency,

        'currency_symbol':

            _currencySymbol,

        'require_signature':

            _requireSignature,

        'allow_payment_notes':

            _allowPaymentNotes,

        'updated_at':

            DateTime.now().toIso8601String(),

      });



      if (!mounted) return;



      _showSnackBar(

        'Payment settings saved.',

      );

    } catch (error) {

      if (mounted) {

        _showSnackBar(

          'Could not save payment settings.',

        );

      }

    } finally {

      if (mounted) {

        setState(() {

          _isSaving = false;

        });

      }

    }

  }



  void _showSnackBar(String message) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(message),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final colors =

        Theme.of(context).colorScheme;



    return Scaffold(

      appBar: AppBar(

        title: const Text(

          'Payment Settings',

        ),

      ),

      body: _isLoading

          ? Center(

              child: CircularProgressIndicator(

                color: colors.primary,

              ),

            )

          : ListView(

              padding: const EdgeInsets.all(20),

              children: [

                _PaymentSettingCard(

                  icon:

                      Icons.currency_rupee,

                  title: 'Currency',

                  subtitle:

                      'Currency used for payments and balances',

                  child: DropdownButtonFormField<

                      String>(

                    initialValue: _currency,

                    decoration:

                        const InputDecoration(

                      labelText: 'Currency',

                      prefixIcon:

                          Icon(Icons.money_outlined),

                    ),

                    items: const [

                      DropdownMenuItem(

                        value: 'INR',

                        child: Text(

                          'INR — Indian Rupee',

                        ),

                      ),

                      DropdownMenuItem(

                        value: 'USD',

                        child: Text(

                          'USD — US Dollar',

                        ),

                      ),

                      DropdownMenuItem(

                        value: 'EUR',

                        child: Text(

                          'EUR — Euro',

                        ),

                      ),

                      DropdownMenuItem(

                        value: 'GBP',

                        child: Text(

                          'GBP — British Pound',

                        ),

                      ),

                    ],

                    onChanged: (value) {

                      if (value == null) return;



                      setState(() {

                        _currency = value;



                        switch (value) {

                          case 'USD':

                            _currencySymbol = '\$';

                            break;

                          case 'EUR':

                            _currencySymbol = '€';

                            break;

                          case 'GBP':

                            _currencySymbol = '£';

                            break;

                          default:

                            _currencySymbol = '₹';

                        }

                      });

                    },

                  ),

                ),



                const SizedBox(height: 14),



                _PaymentSettingCard(

                  icon:

                      Icons.draw_outlined,

                  title:

                      'Customer signature',

                  subtitle:

                      'Require a customer signature when receiving a payment',

                  child: SwitchListTile(

                    contentPadding:

                        EdgeInsets.zero,

                    title: const Text(

                      'Require signature',

                      style: TextStyle(

                        fontWeight:

                            FontWeight.w700,

                      ),

                    ),

                    subtitle: Text(

                      _requireSignature

                          ? 'Salesmen must collect a signature'

                          : 'Signature is optional',

                    ),

                    value:

                        _requireSignature,

                    onChanged: (value) {

                      setState(() {

                        _requireSignature =

                            value;

                      });

                    },

                  ),

                ),



                const SizedBox(height: 14),



                _PaymentSettingCard(

                  icon:

                      Icons.notes_outlined,

                  title:

                      'Payment notes',

                  subtitle:

                      'Allow salesmen to add notes to payments',

                  child: SwitchListTile(

                    contentPadding:

                        EdgeInsets.zero,

                    title: const Text(

                      'Allow payment notes',

                      style: TextStyle(

                        fontWeight:

                            FontWeight.w700,

                      ),

                    ),

                    subtitle: Text(

                      _allowPaymentNotes

                          ? 'Notes can be added to payments'

                          : 'Payment notes are disabled',

                    ),

                    value:

                        _allowPaymentNotes,

                    onChanged: (value) {

                      setState(() {

                        _allowPaymentNotes =

                            value;

                      });

                    },

                  ),

                ),



                const SizedBox(height: 24),



                SizedBox(

                  height: 52,

                  child: FilledButton.icon(

                    onPressed:

                        _isSaving

                            ? null

                            : _saveSettings,

                    icon: _isSaving

                        ? const SizedBox(

                            width: 19,

                            height: 19,

                            child:

                                CircularProgressIndicator(

                              strokeWidth: 2,

                            ),

                          )

                        : const Icon(

                            Icons.save_outlined,

                          ),

                    label: Text(

                      _isSaving

                          ? 'Saving...'

                          : 'Save Changes',

                    ),

                  ),

                ),



                const SizedBox(height: 16),



                Container(

                  padding:

                      const EdgeInsets.all(15),

                  decoration: BoxDecoration(

                    color:

                        colors.surfaceContainerHighest,

                    borderRadius:

                        BorderRadius.circular(16),

                  ),

                  child: Row(

                    crossAxisAlignment:

                        CrossAxisAlignment.start,

                    children: [

                      Icon(

                        Icons.info_outline,

                        color: colors.primary,

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Text(

                          'These settings are shared across the business. Salesmen can use the settings but cannot change them.',

                          style: TextStyle(

                            color: colors

                                .onSurfaceVariant,

                            fontSize: 12,

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

    );

  }

}

class _PaymentSettingCard

    extends StatelessWidget {

  final IconData icon;

  final String title;

  final String subtitle;

  final Widget child;



  const _PaymentSettingCard({

    required this.icon,

    required this.title,

    required this.subtitle,

    required this.child,

  });



  @override

  Widget build(BuildContext context) {

    final colors =

        Theme.of(context).colorScheme;



    return Container(

      padding:

          const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: colors.surface,

        borderRadius:

            BorderRadius.circular(18),

        border: Border.all(

          color:

              colors.outlineVariant,

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            crossAxisAlignment:

                CrossAxisAlignment.start,

            children: [

              Container(

                width: 42,

                height: 42,

                decoration:

                    BoxDecoration(

                  color:

                      colors.primaryContainer,

                  borderRadius:

                      BorderRadius.circular(

                    12,

                  ),

                ),

                child: Icon(

                  icon,

                  color: colors.primary,

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style:

                          const TextStyle(

                        fontSize: 16,

                        fontWeight:

                            FontWeight.w800,

                      ),

                    ),

                    const SizedBox(

                      height: 4,

                    ),

                    Text(

                      subtitle,

                      style: TextStyle(

                        color: colors

                            .onSurfaceVariant,

                        fontSize: 12,

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(height: 18),

          child,

        ],

      ),

    );

  }

}
