import 'dart:typed_data';



import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';



import '../../models/customer.dart';

import '../../models/transaction.dart';

import '../payments/payment_screen.dart';

import '../../services/transaction_service.dart';
import '../../services/salesman_visit_service.dart';



class SalesmanCustomerDetailsScreen

    extends StatefulWidget {

  final Customer customer;



  const SalesmanCustomerDetailsScreen({

    super.key,

    required this.customer,

  });



  @override

  State<SalesmanCustomerDetailsScreen>

      createState() =>

          _SalesmanCustomerDetailsScreenState();

}



class _SalesmanCustomerDetailsScreenState

    extends State<SalesmanCustomerDetailsScreen> {

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text('Customer Details'),

      ),

      body: ValueListenableBuilder<int>(

        valueListenable:

            TransactionService.dataVersion,

        builder: (context, _, _) {

          final balance =

              TransactionService

                  .getCurrentBalance(

            customerId:

                widget.customer.id,

            openingBalance:

                widget.customer

                    .openingBalance,

          );



          final payments =

              TransactionService

                  .getCustomerTransactions(

            widget.customer.id,

          );



          final totalPaid = payments.fold(

            0.0,

            (sum, payment) =>

                sum + payment.amount,

          );



          return RefreshIndicator(

            onRefresh: () async {

              await TransactionService

                  .loadTransactions();



              if (mounted) {

                setState(() {});

              }

            },

            child: ListView(

              padding:

                  const EdgeInsets.all(20),

              children: [

                // ------------------------------------------------

                // CUSTOMER HEADER

                // ------------------------------------------------



                Row(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,

                  children: [

                    CircleAvatar(

                      radius: 30,

                      child: Text(

                        _getInitials(

                          widget.customer

                              .businessName,

                        ),

                        style:

                            const TextStyle(

                          fontSize: 20,

                          fontWeight:

                              FontWeight.bold,

                        ),

                      ),

                    ),



                    const SizedBox(

                      width: 14,

                    ),



                    Expanded(

                      child: Column(

                        crossAxisAlignment:

                            CrossAxisAlignment

                                .start,

                        children: [

                          Text(

                            widget.customer

                                .businessName,

                            style:

                                const TextStyle(

                              fontSize: 24,

                              fontWeight:

                                  FontWeight

                                      .bold,

                            ),

                          ),



                          const SizedBox(

                            height: 6,

                          ),



                          Row(

                            children: [

                              const Icon(

                                Icons

                                    .location_on_outlined,

                                size: 17,

                              ),

                              const SizedBox(

                                width: 5,

                              ),

                              Expanded(

                                child: Text(

                                  widget.customer

                                      .location,

                                ),

                              ),

                            ],

                          ),



                          const SizedBox(

                            height: 4,

                          ),



                          Row(

                            children: [

                              const Icon(

                                Icons

                                    .phone_outlined,

                                size: 17,

                              ),

                              const SizedBox(

                                width: 5,

                              ),

                              Text(

                                widget.customer

                                    .phone,

                              ),

                            ],

                          ),

                        ],

                      ),

                    ),

                  ],

                ),



                const SizedBox(

                  height: 24,

                ),



                // ------------------------------------------------

                // AMOUNT DUE CARD

                // ------------------------------------------------



                Container(

                  width:

                      double.infinity,

                  padding:

                      const EdgeInsets.all(

                    22,

                  ),

                  decoration:

                      BoxDecoration(

                    color: Theme.of(

                      context,

                    )

                        .colorScheme

                        .primaryContainer,

                    borderRadius:

                        BorderRadius.circular(

                      20,

                    ),

                  ),

                  child: Column(

                    crossAxisAlignment:

                        CrossAxisAlignment

                            .start,

                    children: [

                      Row(

                        children: [

                          Icon(

                            Icons

                                .account_balance_wallet_outlined,

                            color: Theme.of(

                              context,

                            )

                                .colorScheme

                                .onPrimaryContainer,

                          ),

                          const SizedBox(

                            width: 8,

                          ),

                          Text(

                            'Amount Due',

                            style:

                                TextStyle(

                              color: Theme.of(

                                context,

                              )

                                  .colorScheme

                                  .onPrimaryContainer,

                              fontSize: 15,

                            ),

                          ),

                        ],

                      ),



                      const SizedBox(

                        height: 8,

                      ),



                      Text(

                        '₹${balance.toStringAsFixed(2)}',

                        style:

                            TextStyle(

                          fontSize: 32,

                          fontWeight:

                              FontWeight

                                  .bold,

                          color: Theme.of(

                            context,

                          )

                              .colorScheme

                              .onPrimaryContainer,

                        ),

                      ),



                      const SizedBox(

                        height: 4,

                      ),



                      Text(

                        balance > 0

                            ? 'Outstanding amount'

                            : 'No outstanding balance',

                        style:

                            TextStyle(

                          color: Theme.of(

                            context,

                          )

                              .colorScheme

                              .onPrimaryContainer

                              .withValues(alpha: 

                                0.75,

                              ),

                        ),

                      ),

                    ],

                  ),

                ),



                const SizedBox(

                  height: 16,

                ),



                // ------------------------------------------------

                // QUICK PAYMENT BUTTON

                // ------------------------------------------------



                SizedBox(

                  width:

                      double.infinity,

                  height: 54,

                  child: FilledButton.icon(

                    onPressed:

                        balance <= 0

                            ? null

                            : () async {

                                Position? visitPosition;
                                try {
                                  visitPosition = await SalesmanVisitService.captureLocation();
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enable location before recording this payment: $error')));
                                  return;
                                }
                                if (!context.mounted) return;
                                final paymentSaved = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => PaymentScreen(customer: widget.customer)),
                                );
                                if (paymentSaved == true) {
                                  try {
                                    await SalesmanVisitService.recordStatus(customerId: widget.customer.id, status: 'paid', capturedPosition: visitPosition);
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                    return;
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Payment was saved, but visit status/location could not be recorded: $error'),
                                        ),
                                      );
                                    }
                                  }
                                }

                                await TransactionService

                                    .loadTransactions();



                                if (mounted) {

                                  setState(

                                    () {},

                                  );

                                }

                              },

                    icon: const Icon(

                      Icons

                          .payments_outlined,

                    ),

                    label: const Text(

                      'Receive Payment',

                      style:

                          TextStyle(

                        fontSize: 16,

                        fontWeight:

                            FontWeight.bold,

                      ),

                    ),

                  ),

                ),



                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Record no payment'),
                        content: Text('Confirm that ${widget.customer.businessName} did not pay today. Other salesmen will see this customer as handled for today.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm refusal')),
                        ],
                      ),
                    );
                    if (!context.mounted || confirm != true) return;
                    try {
                      await SalesmanVisitService.recordStatus(customerId: widget.customer.id, status: 'rejected');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit recorded with current location.')));
                        Navigator.pop(context, true);
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not record visit: $error')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Record no payment today'),
                ),

                const SizedBox(

                  height: 22,

                ),



                // ------------------------------------------------

                // STATISTICS

                // ------------------------------------------------



                Row(

                  children: [

                    Expanded(

                      child:

                          _InfoCard(

                        icon: Icons

                            .payments_outlined,

                        title:

                            'Total Paid',

                        value:

                            '₹${totalPaid.toStringAsFixed(2)}',

                      ),

                    ),



                    const SizedBox(

                      width: 12,

                    ),



                    Expanded(

                      child:

                          _InfoCard(

                        icon: Icons

                            .receipt_long_outlined,

                        title:

                            'Payments',

                        value:

                            payments.length

                                .toString(),

                      ),

                    ),

                  ],

                ),



                const SizedBox(

                  height: 28,

                ),



                // ------------------------------------------------

                // PAYMENT HISTORY

                // ------------------------------------------------



                Row(

                  mainAxisAlignment:

                      MainAxisAlignment

                          .spaceBetween,

                  children: [

                    const Text(

                      'Payment History',

                      style:

                          TextStyle(

                        fontSize: 21,

                        fontWeight:

                            FontWeight

                                .bold,

                      ),

                    ),



                    if (payments.isNotEmpty)

                      Text(

                        '${payments.length}',

                        style:

                            TextStyle(

                          color: Theme.of(

                            context,

                          )

                              .colorScheme

                              .primary,

                          fontWeight:

                              FontWeight

                                  .bold,

                        ),

                      ),

                  ],

                ),



                const SizedBox(

                  height: 12,

                ),



                if (payments.isEmpty)

                  Container(

                    padding:

                        const EdgeInsets

                            .all(

                      28,

                    ),

                    decoration:

                        BoxDecoration(

                      border: Border.all(

                        color: Theme.of(

                          context,

                        )

                            .colorScheme

                            .outlineVariant,

                      ),

                      borderRadius:

                          BorderRadius

                              .circular(

                        16,

                      ),

                    ),

                    child: Column(

                      children: [

                        Icon(

                          Icons

                              .receipt_long_outlined,

                          size: 42,

                          color: Theme.of(

                            context,

                          )

                              .colorScheme

                              .onSurfaceVariant,

                        ),

                        const SizedBox(

                          height: 12,

                        ),

                        const Text(

                          'No payments yet',

                          style:

                              TextStyle(

                            fontWeight:

                                FontWeight

                                    .w600,

                          ),

                        ),

                        const SizedBox(

                          height: 4,

                        ),

                        Text(

                          'Payment history will appear here.',

                          textAlign:

                              TextAlign

                                  .center,

                          style:

                              TextStyle(

                            color: Theme.of(

                              context,

                            )

                                .colorScheme

                                .onSurfaceVariant,

                          ),

                        ),

                      ],

                    ),

                  )

                else

                  ...payments.map(

                    (payment) =>

                        _PaymentCard(

                      transaction:

                          payment,

                    ),

                  ),



                const SizedBox(

                  height: 20,

                ),

              ],

            ),

          );

        },

      ),

    );

  }



  String _getInitials(String name) {

    final parts =

        name.trim().split(

              RegExp(r'\s+'),

            );



    if (parts.isEmpty ||

        parts.first.isEmpty) {

      return 'C';

    }



    if (parts.length == 1) {

      return parts.first[0]

          .toUpperCase();

    }



    return '${parts.first[0]}${parts.last[0]}'

        .toUpperCase();

  }

}



// ============================================================

// INFO CARD

// ============================================================



class _InfoCard extends StatelessWidget {

  final IconData icon;

  final String title;

  final String value;



  const _InfoCard({

    required this.icon,

    required this.title,

    required this.value,

  });



  @override

  Widget build(

    BuildContext context,

  ) {

    return Container(

      padding:

          const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: Theme.of(context)

            .colorScheme

            .surfaceContainerHighest,

        borderRadius:

            BorderRadius.circular(16),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Icon(

            icon,

            size: 22,

          ),

          const SizedBox(

            height: 12,

          ),

          Text(

            value,

            style:

                const TextStyle(

              fontSize: 18,

              fontWeight:

                  FontWeight.bold,

            ),

          ),

          const SizedBox(

            height: 3,

          ),

          Text(

            title,

            style: TextStyle(

              fontSize: 12,

              color: Theme.of(

                context,

              )

                  .colorScheme

                  .onSurfaceVariant,

            ),

          ),

        ],

      ),

    );

  }

}



// ============================================================

// PAYMENT CARD

// ============================================================



class _PaymentCard

    extends StatefulWidget {

  final PaymentTransaction

      transaction;



  const _PaymentCard({

    required this.transaction,

  });



  @override

  State<_PaymentCard> createState() =>

      _PaymentCardState();

}



class _PaymentCardState

    extends State<_PaymentCard> {

  Uint8List? signatureBytes;



  bool loadingSignature =

      false;



  bool signatureLoaded =

      false;



  Future<void> _loadSignature() async {

    if (signatureLoaded ||

        loadingSignature) {

      return;

    }



    final path =

        widget.transaction.signaturePath;



    if (path == null ||

        path.isEmpty) {

      setState(() {

        signatureLoaded = true;

      });

      return;

    }



    setState(() {

      loadingSignature = true;

    });



    final bytes =

        await TransactionService

            .downloadSignature(

      path,

    );



    if (!mounted) {

      return;

    }



    setState(() {

      signatureBytes = bytes;

      loadingSignature = false;

      signatureLoaded = true;

    });

  }



  @override

  Widget build(

    BuildContext context,

  ) {

    final payment =

        widget.transaction;



    return Card(

      margin:

          const EdgeInsets.only(

        bottom: 12,

      ),

      child: ExpansionTile(

        tilePadding:

            const EdgeInsets.symmetric(

          horizontal: 16,

          vertical: 4,

        ),

        childrenPadding:

            const EdgeInsets.fromLTRB(

          16,

          0,

          16,

          16,

        ),

        leading: CircleAvatar(

          backgroundColor:

              Colors.green

                  .withValues(alpha: 

            0.12,

          ),

          child: const Icon(

            Icons

                .check_circle_outline,

            color:

                Colors.green,

          ),

        ),

        title: Text(

          '+ ₹${payment.amount.toStringAsFixed(2)}',

          style:

              const TextStyle(

            fontWeight:

                FontWeight.bold,

            fontSize: 17,

          ),

        ),

        subtitle: Text(

          _formatDate(

            payment

                .transactionDate,

          ),

        ),

        children: [

          const Divider(),



          const SizedBox(

            height: 8,

          ),



          Row(

            children: [

              Expanded(

                child:

                    _BalanceItem(

                  label: 'Previous',

                  value:

                      '₹${payment.previousBalance.toStringAsFixed(2)}',

                ),

              ),

              Expanded(

                child:

                    _BalanceItem(

                  label: 'Remaining',

                  value:

                      '₹${payment.remainingBalance.toStringAsFixed(2)}',

                ),

              ),

            ],

          ),



          if (payment

              .notes

              .trim()

              .isNotEmpty) ...[

            const SizedBox(

              height: 16,

            ),



            Container(

              width:

                  double.infinity,

              padding:

                  const EdgeInsets.all(

                12,

              ),

              decoration:

                  BoxDecoration(

                color: Theme.of(

                  context,

                )

                    .colorScheme

                    .surfaceContainerHighest,

                borderRadius:

                    BorderRadius.circular(

                  10,

                ),

              ),

              child: Row(

                crossAxisAlignment:

                    CrossAxisAlignment

                        .start,

                children: [

                  const Icon(

                    Icons

                        .notes_outlined,

                    size: 19,

                  ),

                  const SizedBox(

                    width: 8,

                  ),

                  Expanded(

                    child: Text(

                      payment.notes,

                    ),

                  ),

                ],

              ),

            ),

          ],



          const SizedBox(

            height: 16,

          ),



          const Align(

            alignment:

                Alignment.centerLeft,

            child: Text(

              'Customer Signature',

              style:

                  TextStyle(

                fontWeight:

                    FontWeight.bold,

              ),

            ),

          ),



          const SizedBox(

            height: 8,

          ),



          if (!signatureLoaded)

            SizedBox(

              width:

                  double.infinity,

              child:

                  OutlinedButton.icon(

                onPressed:

                    loadingSignature

                        ? null

                        : _loadSignature,

                icon: loadingSignature

                    ? const SizedBox(

                        width: 18,

                        height: 18,

                        child:

                            CircularProgressIndicator(

                          strokeWidth:

                              2,

                        ),

                      )

                    : const Icon(

                        Icons

                            .visibility_outlined,

                      ),

                label: Text(

                  loadingSignature

                      ? 'Loading signature...'

                      : 'View Signature',

                ),

              ),

            )

          else if (signatureBytes !=

                  null &&

              signatureBytes!

                  .isNotEmpty)

            Container(

              width:

                  double.infinity,

              height: 150,

              decoration:

                  BoxDecoration(

                color:

                    Colors.white,

                border: Border.all(

                  color: Theme.of(

                    context,

                  )

                      .colorScheme

                      .outlineVariant,

                ),

                borderRadius:

                    BorderRadius.circular(

                  10,

                ),

              ),

              padding:

                  const EdgeInsets.all(

                10,

              ),

              child:

                  Image.memory(

                signatureBytes!,

                fit: BoxFit.contain,

              ),

            )

          else

            Container(

              width:

                  double.infinity,

              padding:

                  const EdgeInsets.all(

                12,

              ),

              decoration:

                  BoxDecoration(

                color: Theme.of(

                  context,

                )

                    .colorScheme

                    .surfaceContainerHighest,

                borderRadius:

                    BorderRadius.circular(

                  10,

                ),

              ),

              child: const Text(

                'Signature unavailable.',

              ),

            ),

        ],

      ),

    );

  }



  String _formatDate(

    DateTime date,

  ) {

    return '${date.day.toString().padLeft(2, '0')}/'

        '${date.month.toString().padLeft(2, '0')}/'

        '${date.year}  '

        '${date.hour.toString().padLeft(2, '0')}:'

        '${date.minute.toString().padLeft(2, '0')}';

  }

}



// ============================================================

// BALANCE ITEM

// ============================================================



class _BalanceItem

    extends StatelessWidget {

  final String label;

  final String value;



  const _BalanceItem({

    required this.label,

    required this.value,

  });



  @override

  Widget build(

    BuildContext context,

  ) {

    return Column(

      crossAxisAlignment:

          CrossAxisAlignment.start,

      children: [

        Text(

          label,

          style: TextStyle(

            fontSize: 12,

            color: Theme.of(

              context,

            )

                .colorScheme

                .onSurfaceVariant,

          ),

        ),

        const SizedBox(

          height: 4,

        ),

        Text(

          value,

          style:

              const TextStyle(

            fontWeight:

                FontWeight.w600,

          ),

        ),

      ],

    );

  }

}