import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen

    extends StatelessWidget {

  final String userName;

  final String role;



  const ProfileScreen({

    super.key,

    required this.userName,

    required this.role,

  });



  @override

  Widget build(BuildContext context) {

    final user =

        Supabase.instance.client.auth.currentUser;



    final colors =

        Theme.of(context).colorScheme;



    return Scaffold(

      appBar: AppBar(

        title: const Text(

          'My Profile',

        ),

      ),

      body: ListView(

        padding: const EdgeInsets.all(20),

        children: [

          CircleAvatar(

            radius: 42,

            backgroundColor:

                colors.primaryContainer,

            child: Text(

              _initials(userName),

              style: TextStyle(

                color: colors.primary,

                fontSize: 24,

                fontWeight:

                    FontWeight.w800,

              ),

            ),

          ),



          const SizedBox(height: 18),



          Center(

            child: Text(

              userName,

              style: const TextStyle(

                fontSize: 22,

                fontWeight:

                    FontWeight.w800,

              ),

            ),

          ),



          const SizedBox(height: 6),



          Center(

            child: Text(

              role == 'owner'

                  ? 'Owner'

                  : 'Salesman',

              style: TextStyle(

                color:

                    colors.onSurfaceVariant,

              ),

            ),

          ),



          const SizedBox(height: 30),



          Card(

            child: Column(

              children: [

                ListTile(

                  leading: const Icon(

                    Icons.email_outlined,

                  ),

                  title: const Text(

                    'Email',

                  ),

                  subtitle: Text(

                    user?.email ??

                        'Not available',

                  ),

                ),

                const Divider(

                  height: 1,

                ),

                ListTile(

                  leading: const Icon(

                    Icons.badge_outlined,

                  ),

                  title: const Text(

                    'Role',

                  ),

                  subtitle: Text(

                    role == 'owner'

                        ? 'Owner'

                        : 'Salesman',

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  String _initials(String name) {

    final parts = name

        .trim()

        .split(RegExp(r'\s+'));



    if (parts.isEmpty ||

        parts.first.isEmpty) {

      return 'U';

    }



    if (parts.length == 1) {

      return parts.first[0]

          .toUpperCase();

    }



    return '${parts.first[0]}${parts.last[0]}'

        .toUpperCase();

  }

}
