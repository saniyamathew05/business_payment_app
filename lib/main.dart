

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';



import 'screens/owner/owner_main_screen.dart';

import 'screens/salesman/salesman_home.dart';

import 'services/theme_controller.dart';

import 'services/auth_service.dart';



Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();



  const supabaseUrl =

      'https://rxjexwtdhopkltrrlbnd.supabase.co';



  const supabasePublishableKey =

      String.fromEnvironment(

    'SUPABASE_PUBLISHABLE_KEY',

  );



  if (supabasePublishableKey.isEmpty) {

    throw Exception(

      'SUPABASE_PUBLISHABLE_KEY was not provided.',

    );

  }



  await Supabase.initialize(

    url: supabaseUrl,

    publishableKey: supabasePublishableKey,

  );



  await ThemeController.loadTheme();



  runApp(const BusinessPaymentApp());

}



// ============================================================

// APP

// ============================================================



class BusinessPaymentApp extends StatelessWidget {

  const BusinessPaymentApp({

    super.key,

  });



  @override

  Widget build(BuildContext context) {

    return ValueListenableBuilder<ThemeMode>(

      valueListenable: ThemeController.themeMode,

      builder: (

        context,

        themeMode,

        _,

      ) {

        return MaterialApp(

          debugShowCheckedModeBanner: false,

          title: 'Business Payment',

          themeMode: themeMode,

          theme: _buildLightTheme(),

          darkTheme: _buildDarkTheme(),

          home: const AuthGate(),

        );

      },

    );

  }



  // ==========================================================

  // LIGHT THEME

  // ==========================================================



  ThemeData _buildLightTheme() {

    const primary =

        Color(0xFF0F766E);



    const secondary =

        Color(0xFF10B981);



    const background =

        Color(0xFFF6F8F7);



    const surface =

        Color(0xFFFFFFFF);



    const border =

        Color(0xFFDCE5E2);



    const textPrimary =

        Color(0xFF17211F);



    const textSecondary =

        Color(0xFF64736F);



    final colorScheme =

        ColorScheme.light(

      primary: primary,

      onPrimary: Colors.white,



      primaryContainer:

          const Color(0xFFDDF5EF),

      onPrimaryContainer:

          const Color(0xFF064E49),



      secondary: secondary,

      onSecondary: Colors.white,



      secondaryContainer:

          const Color(0xFFD1FAE5),

      onSecondaryContainer:

          const Color(0xFF065F46),



      surface: surface,

      onSurface: textPrimary,



      surfaceContainerLowest:

          Colors.white,



      surfaceContainerLow:

          const Color(0xFFFAFCFB),



      surfaceContainer:

          const Color(0xFFF1F5F3),



      surfaceContainerHigh:

          const Color(0xFFEAF1EE),



      surfaceContainerHighest:

          const Color(0xFFE2EBE8),



      onSurfaceVariant:

          textSecondary,



      outline:

          const Color(0xFFB9C9C4),



      outlineVariant:

          border,



      error:

          const Color(0xFFDC2626),

      onError:

          Colors.white,



      errorContainer:

          const Color(0xFFFEE2E2),

      onErrorContainer:

          const Color(0xFF7F1D1D),

    );



    return ThemeData(

      useMaterial3: true,

      brightness: Brightness.light,

      colorScheme: colorScheme,



      scaffoldBackgroundColor:

          background,



      appBarTheme:

          const AppBarTheme(

        backgroundColor: surface,

        foregroundColor: textPrimary,

        elevation: 0,

        centerTitle: false,

        surfaceTintColor:

            Colors.transparent,

      ),



      cardTheme:

          CardThemeData(

        color: surface,

        elevation: 0,

        margin: EdgeInsets.zero,

        surfaceTintColor:

            Colors.transparent,

        shape:

            RoundedRectangleBorder(

          borderRadius:

              BorderRadius.circular(18),

          side:

              const BorderSide(

            color: border,

          ),

        ),

      ),



      inputDecorationTheme:

          InputDecorationTheme(

        filled: true,

        fillColor:

            const Color(0xFFF8FAF9),



        contentPadding:

            const EdgeInsets.symmetric(

          horizontal: 16,

          vertical: 15,

        ),



        border:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: border,

          ),

        ),



        enabledBorder:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: border,

          ),

        ),



        focusedBorder:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: primary,

            width: 2,

          ),

        ),



        errorBorder:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: Color(0xFFDC2626),

          ),

        ),



        focusedErrorBorder:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: Color(0xFFDC2626),

            width: 2,

          ),

        ),



        labelStyle:

            const TextStyle(

          color: textSecondary,

        ),



        hintStyle:

            const TextStyle(

          color: Color(0xFF94A3A0),

        ),



        prefixIconColor:

            textSecondary,



        suffixIconColor:

            textSecondary,

      ),



      elevatedButtonTheme:

          ElevatedButtonThemeData(

        style:

            ElevatedButton.styleFrom(

          backgroundColor: primary,

          foregroundColor: Colors.white,



          disabledBackgroundColor:

              const Color(0xFFCBD5D1),

          disabledForegroundColor:

              const Color(0xFF64736F),



          elevation: 0,



          minimumSize:

              const Size(0, 50),



          padding:

              const EdgeInsets.symmetric(

            horizontal: 20,

            vertical: 14,

          ),



          shape:

              RoundedRectangleBorder(

            borderRadius:

                BorderRadius.circular(14),

          ),



          textStyle:

              const TextStyle(

            fontSize: 14,

            fontWeight:

                FontWeight.w700,

          ),

        ),

      ),



      outlinedButtonTheme:

          OutlinedButtonThemeData(

        style:

            OutlinedButton.styleFrom(

          foregroundColor: primary,



          minimumSize:

              const Size(0, 50),



          padding:

              const EdgeInsets.symmetric(

            horizontal: 20,

            vertical: 14,

          ),



          side:

              const BorderSide(

            color: border,

          ),



          shape:

              RoundedRectangleBorder(

            borderRadius:

                BorderRadius.circular(14),

          ),



          textStyle:

              const TextStyle(

            fontSize: 14,

            fontWeight:

                FontWeight.w700,

          ),

        ),

      ),



      textButtonTheme:

          TextButtonThemeData(

        style:

            TextButton.styleFrom(

          foregroundColor: primary,



          shape:

              RoundedRectangleBorder(

            borderRadius:

                BorderRadius.circular(10),

          ),



          textStyle:

              const TextStyle(

            fontWeight:

                FontWeight.w700,

          ),

        ),

      ),



      floatingActionButtonTheme:

          const FloatingActionButtonThemeData(

        backgroundColor: primary,

        foregroundColor: Colors.white,

        elevation: 3,

      ),



      navigationBarTheme:

          NavigationBarThemeData(

        backgroundColor: surface,

        indicatorColor:

            const Color(0xFFDDF5EF),

        elevation: 0,



        labelTextStyle:

            WidgetStateProperty.resolveWith(

          (states) {

            if (states.contains(

              WidgetState.selected,

            )) {

              return const TextStyle(

                fontSize: 12,

                fontWeight:

                    FontWeight.w700,

                color: primary,

              );

            }



            return const TextStyle(

              fontSize: 12,

              fontWeight:

                  FontWeight.w500,

              color: textSecondary,

            );

          },

        ),



        iconTheme:

            WidgetStateProperty.resolveWith(

          (states) {

            if (states.contains(

              WidgetState.selected,

            )) {

              return const IconThemeData(

                color: primary,

              );

            }



            return const IconThemeData(

              color: textSecondary,

            );

          },

        ),

      ),



      dividerTheme:

          const DividerThemeData(

        color: border,

        thickness: 1,

        space: 1,

      ),



      snackBarTheme:

          SnackBarThemeData(

        behavior:

            SnackBarBehavior.floating,

        backgroundColor:

            const Color(0xFF17211F),

        contentTextStyle:

            const TextStyle(

          color: Colors.white,

          fontSize: 13,

        ),

        shape:

            RoundedRectangleBorder(

          borderRadius:

              BorderRadius.circular(12),

        ),

      ),



      dialogTheme:

          DialogThemeData(

        backgroundColor: surface,

        surfaceTintColor:

            Colors.transparent,

        shape:

            RoundedRectangleBorder(

          borderRadius:

              BorderRadius.circular(22),

        ),

      ),



      bottomSheetTheme:

          const BottomSheetThemeData(

        backgroundColor: surface,

        surfaceTintColor:

            Colors.transparent,

        showDragHandle: true,

      ),



      progressIndicatorTheme:

          const ProgressIndicatorThemeData(

        color: primary,

      ),

    );

  }



  // ==========================================================

  // DARK THEME

  // ==========================================================



  ThemeData _buildDarkTheme() {

    const primary =

        Color(0xFF34D399);



    const secondary =

        Color(0xFF2DD4BF);



    const background =

        Color(0xFF0B1412);



    const surface =

        Color(0xFF111C19);



    const border =

        Color(0xFF263A35);



    const textPrimary =

        Color(0xFFF1F5F3);



    const textSecondary =

        Color(0xFFB7C7C2);



    final colorScheme =

        ColorScheme.dark(

      primary: primary,

      onPrimary:

          const Color(0xFF052E27),



      primaryContainer:

          const Color(0xFF123D35),

      onPrimaryContainer:

          const Color(0xFFA7F3D0),



      secondary: secondary,

      onSecondary:

          const Color(0xFF042F2E),



      secondaryContainer:

          const Color(0xFF123B37),

      onSecondaryContainer:

          const Color(0xFF99F6E4),



      surface: surface,

      onSurface: textPrimary,



      surfaceContainerLowest:

          const Color(0xFF07100E),



      surfaceContainerLow:

          const Color(0xFF0C1714),



      surfaceContainer:

          const Color(0xFF15221F),



      surfaceContainerHigh:

          const Color(0xFF1A2B27),



      surfaceContainerHighest:

          const Color(0xFF20332E),



      onSurfaceVariant:

          textSecondary,



      outline:

          const Color(0xFF48615A),



      outlineVariant:

          border,



      error:

          const Color(0xFFF87171),

      onError:

          const Color(0xFF450A0A),



      errorContainer:

          const Color(0xFF4C1D1D),

      onErrorContainer:

          const Color(0xFFFECACA),

    );



    return ThemeData(

      useMaterial3: true,

      brightness: Brightness.dark,

      colorScheme: colorScheme,



      scaffoldBackgroundColor:

          background,



      appBarTheme:

          const AppBarTheme(

        backgroundColor: background,

        foregroundColor: textPrimary,

        elevation: 0,

        centerTitle: false,

        surfaceTintColor:

            Colors.transparent,

      ),



      cardTheme:

          CardThemeData(

        color: surface,

        elevation: 0,

        margin: EdgeInsets.zero,

        surfaceTintColor:

            Colors.transparent,

        shape:

            RoundedRectangleBorder(

          borderRadius:

              BorderRadius.circular(18),

          side:

              const BorderSide(

            color: border,

          ),

        ),

      ),



      inputDecorationTheme:

          InputDecorationTheme(

        filled: true,

        fillColor:

            const Color(0xFF15221F),



        contentPadding:

            const EdgeInsets.symmetric(

          horizontal: 16,

          vertical: 15,

        ),



        border:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: border,

          ),

        ),



        enabledBorder:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: border,

          ),

        ),



        focusedBorder:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: primary,

            width: 2,

          ),

        ),



        errorBorder:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: Color(0xFFF87171),

          ),

        ),



        focusedErrorBorder:

            OutlineInputBorder(

          borderRadius:

              BorderRadius.circular(14),

          borderSide:

              const BorderSide(

            color: Color(0xFFF87171),

            width: 2,

          ),

        ),



        labelStyle:

            const TextStyle(

          color: textSecondary,

        ),



        hintStyle:

            const TextStyle(

          color: Color(0xFF82958F),

        ),



        prefixIconColor:

            textSecondary,



        suffixIconColor:

            textSecondary,

      ),



      elevatedButtonTheme:

          ElevatedButtonThemeData(

        style:

            ElevatedButton.styleFrom(

          backgroundColor: primary,

          foregroundColor:

              const Color(0xFF052E27),



          disabledBackgroundColor:

              const Color(0xFF33443F),

          disabledForegroundColor:

              const Color(0xFF91A39D),



          elevation: 0,



          minimumSize:

              const Size(0, 50),



          padding:

              const EdgeInsets.symmetric(

            horizontal: 20,

            vertical: 14,

          ),



          shape:

              RoundedRectangleBorder(

            borderRadius:

                BorderRadius.circular(14),

          ),



          textStyle:

              const TextStyle(

            fontSize: 14,

            fontWeight:

                FontWeight.w800,

          ),

        ),

      ),



      outlinedButtonTheme:

          OutlinedButtonThemeData(

        style:

            OutlinedButton.styleFrom(

          foregroundColor: primary,



          minimumSize:

              const Size(0, 50),



          padding:

              const EdgeInsets.symmetric(

            horizontal: 20,

            vertical: 14,

          ),



          side:

              const BorderSide(

            color: border,

          ),



          shape:

              RoundedRectangleBorder(

            borderRadius:

                BorderRadius.circular(14),

          ),



          textStyle:

              const TextStyle(

            fontSize: 14,

            fontWeight:

                FontWeight.w700,

          ),

        ),

      ),



      textButtonTheme:

          TextButtonThemeData(

        style:

            TextButton.styleFrom(

          foregroundColor: primary,



          shape:

              RoundedRectangleBorder(

            borderRadius:

                BorderRadius.circular(10),

          ),



          textStyle:

              const TextStyle(

            fontWeight:

                FontWeight.w700,

          ),

        ),

      ),



      floatingActionButtonTheme:

          const FloatingActionButtonThemeData(

        backgroundColor: primary,

        foregroundColor:

            Color(0xFF052E27),

        elevation: 3,

      ),



      navigationBarTheme:

          NavigationBarThemeData(

        backgroundColor: surface,

        indicatorColor:

            const Color(0xFF123D35),

        elevation: 0,



        labelTextStyle:

            WidgetStateProperty.resolveWith(

          (states) {

            if (states.contains(

              WidgetState.selected,

            )) {

              return const TextStyle(

                fontSize: 12,

                fontWeight:

                    FontWeight.w700,

                color: primary,

              );

            }



            return const TextStyle(

              fontSize: 12,

              fontWeight:

                  FontWeight.w500,

              color: textSecondary,

            );

          },

        ),



        iconTheme:

            WidgetStateProperty.resolveWith(

          (states) {

            if (states.contains(

              WidgetState.selected,

            )) {

              return const IconThemeData(

                color: primary,

              );

            }



            return const IconThemeData(

              color: textSecondary,

            );

          },

        ),

      ),



      dividerTheme:

          const DividerThemeData(

        color: border,

        thickness: 1,

        space: 1,

      ),



      snackBarTheme:

          SnackBarThemeData(

        behavior:

            SnackBarBehavior.floating,

        backgroundColor:

            const Color(0xFFE2F3ED),

        contentTextStyle:

            const TextStyle(

          color: Color(0xFF10201C),

          fontSize: 13,

        ),

        shape:

            RoundedRectangleBorder(

          borderRadius:

              BorderRadius.circular(12),

        ),

      ),



      dialogTheme:

          DialogThemeData(

        backgroundColor: surface,

        surfaceTintColor:

            Colors.transparent,

        shape:

            RoundedRectangleBorder(

          borderRadius:

              BorderRadius.circular(22),

        ),

      ),



      bottomSheetTheme:

          const BottomSheetThemeData(

        backgroundColor: surface,

        surfaceTintColor:

            Colors.transparent,

        showDragHandle: true,

      ),



      progressIndicatorTheme:

          const ProgressIndicatorThemeData(

        color: primary,

      ),

    );

  }

}



// ============================================================

// AUTH GATE

// ============================================================



class AuthGate extends StatefulWidget {

  const AuthGate({

    super.key,

  });



  @override

  State<AuthGate> createState() =>

      _AuthGateState();

}



class _AuthGateState

    extends State<AuthGate> {





  bool isLoading = true;

  String? errorMessage;



  @override

  void initState() {

    super.initState();

    _checkCurrentUser();

  }



  Future<void> _checkCurrentUser() async {

    final user =

        AuthService.currentUser;



    if (user == null) {

      if (!mounted) return;



      setState(() {

        isLoading = false;

      });



      return;

    }



    await _openCorrectDashboard(

      user.id,

    );

  }



  Future<void> _openCorrectDashboard(

    String userId,

  ) async {

    try {

      final profile =

          await AuthService.getProfile(

        userId,

      );



      if (profile == null) {

        await AuthService.signOut();



        if (!mounted) return;



        setState(() {

          errorMessage =

              'Your account profile was not found.';

          isLoading = false;

        });



        return;

      }



      final role =

          profile['role'] as String;



      final name =

          profile['name'] as String;



      if (!mounted) return;



      if (role == 'owner') {

        Navigator.of(context)

            .pushReplacement(

          MaterialPageRoute(

            builder: (_) =>

                const OwnerMainScreen(),

          ),

        );

      } else if (role == 'salesman') {

        Navigator.of(context)

            .pushReplacement(

          MaterialPageRoute(

            builder: (_) =>

                SalesmanHome(

              userName: name,

            ),

          ),

        );

      } else {

        await AuthService.signOut();



        setState(() {

          errorMessage =

              'Invalid account role.';

          isLoading = false;

        });

      }

    } catch (error) {

      if (!mounted) return;



      setState(() {

        errorMessage =

            error.toString();

        isLoading = false;

      });

    }

  }



  @override

  Widget build(

    BuildContext context,

  ) {

    if (isLoading) {

      return const Scaffold(

        body: Center(

          child:

              CircularProgressIndicator(),

        ),

      );

    }



    return LoginScreen(

      initialError: errorMessage,

    );

  }

}



// ============================================================

// LOGIN SCREEN

// ============================================================



class LoginScreen

    extends StatefulWidget {

  final String? initialError;



  const LoginScreen({

    super.key,

    this.initialError,

  });



  @override

  State<LoginScreen> createState() =>

      _LoginScreenState();

}



class _LoginScreenState

    extends State<LoginScreen> {

  final emailController =

      TextEditingController();



  final passwordController =

      TextEditingController();







  bool isLoading = false;

  bool obscurePassword = true;



  @override

  void initState() {

    super.initState();



    if (widget.initialError != null) {

      WidgetsBinding.instance

          .addPostFrameCallback((_) {

        if (mounted) {

          _showError(

            widget.initialError!,

          );

        }

      });

    }

  }



  @override

  void dispose() {

    emailController.dispose();

    passwordController.dispose();

    super.dispose();

  }



  Future<void> login() async {

    final email =

        emailController.text.trim();



    final password =

        passwordController.text;



    if (email.isEmpty ||

        password.isEmpty) {

      _showError(

        'Please enter email and password.',

      );



      return;

    }



    setState(() {

      isLoading = true;

    });



    try {

      final response =

          await AuthService.signIn(

        email: email,

        password: password,

      );



      final user = response.user;



      if (user == null) {

        throw Exception(

          'Login failed.',

        );

      }



      final profile =

          await AuthService.getProfile(

        user.id,

      );



      if (profile == null) {

        await AuthService.signOut();



        throw Exception(

          'No profile was found for this account.',

        );

      }



      final name =

          profile['name'] as String;



      final role =

          profile['role'] as String;



      if (!mounted) return;



      if (role == 'owner') {

        Navigator.pushReplacement(

          context,

          MaterialPageRoute(

            builder: (_) =>

                const OwnerMainScreen(),

          ),

        );

      } else if (role == 'salesman') {

        Navigator.pushReplacement(

          context,

          MaterialPageRoute(

            builder: (_) =>

                SalesmanHome(

              userName: name,

            ),

          ),

        );

      } else {

        await AuthService.signOut();



        throw Exception(

          'This account has an invalid role.',

        );

      }

    } on AuthException catch (error) {

      _showError(

        error.message,

      );

    } catch (error) {

      _showError(

        error.toString().replaceFirst(

              'Exception: ',

              '',

            ),

      );

    } finally {

      if (mounted) {

        setState(() {

          isLoading = false;

        });

      }

    }

  }



  void _showError(

    String message,

  ) {

    ScaffoldMessenger.of(context)

        .showSnackBar(

      SnackBar(

        content: Text(message),

      ),

    );

  }



  @override

  Widget build(

    BuildContext context,

  ) {

    final colors =

        Theme.of(context)

            .colorScheme;



    final isDark =

        Theme.of(context)

            .brightness ==

            Brightness.dark;



    return Scaffold(

      body: SafeArea(

        child: Center(

          child: SingleChildScrollView(

            padding:

                const EdgeInsets.all(24),

            child: ConstrainedBox(

              constraints:

                  const BoxConstraints(

                maxWidth: 420,

              ),

              child: Column(

                children: [

                  // ------------------------------------------------

                  // LOGO

                  // ------------------------------------------------



                  Container(

                    width: 78,

                    height: 78,

                    decoration:

                        BoxDecoration(

                      gradient:

                          LinearGradient(

                        begin:

                            Alignment.topLeft,

                        end:

                            Alignment.bottomRight,

                        colors: [

                          colors.primary,

                          colors.secondary,

                        ],

                      ),

                      borderRadius:

                          BorderRadius.circular(

                        22,

                      ),

                      boxShadow: [

                        BoxShadow(

                          color: colors

                              .primary

                              .withValues(alpha: 0.22,

                          ),

                          blurRadius: 25,

                          offset:

                              const Offset(

                            0,

                            10,

                          ),

                        ),

                      ],

                    ),

                    child: const Icon(

                      Icons

                          .account_balance_wallet_rounded,

                      color:

                          Colors.white,

                      size: 38,

                    ),

                  ),



                  const SizedBox(

                    height: 22,

                  ),



                  const Text(

                    'Business Payment',

                    style: TextStyle(

                      fontSize: 30,

                      fontWeight:

                          FontWeight.w800,

                      letterSpacing: -0.8,

                    ),

                  ),



                  const SizedBox(

                    height: 7,

                  ),



                  Text(

                    'Sign in to continue',

                    style: TextStyle(

                      color: colors

                          .onSurfaceVariant,

                      fontSize: 14,

                    ),

                  ),



                  const SizedBox(

                    height: 34,

                  ),



                  // ------------------------------------------------

                  // LOGIN CARD

                  // ------------------------------------------------



                  Container(

                    padding:

                        const EdgeInsets.all(

                      22,

                    ),

                    decoration:

                        BoxDecoration(

                      color:

                          colors.surface,

                      borderRadius:

                          BorderRadius.circular(

                        22,

                      ),

                      border: Border.all(

                        color: colors

                            .outlineVariant,

                      ),

                      boxShadow: isDark

                          ? null

                          : [

                              BoxShadow(

                                color: Colors

                                    .black

                                    .withValues(alpha: 0.04,

                                ),

                                blurRadius: 25,

                                offset:

                                    const Offset(

                                  0,

                                  8,

                                ),

                              ),

                            ],

                    ),

                    child: Column(

                      children: [

                        TextField(

                          controller:

                              emailController,

                          keyboardType:

                              TextInputType

                                  .emailAddress,

                          decoration:

                              const InputDecoration(

                            labelText:

                                'Email',

                            prefixIcon:

                                Icon(

                              Icons

                                  .email_outlined,

                            ),

                          ),

                        ),



                        const SizedBox(

                          height: 14,

                        ),



                        TextField(

                          controller:

                              passwordController,

                          obscureText:

                              obscurePassword,

                          decoration:

                              InputDecoration(

                            labelText:

                                'Password',

                            prefixIcon:

                                const Icon(

                              Icons

                                  .lock_outline_rounded,

                            ),

                            suffixIcon:

                                IconButton(

                              onPressed: () {

                                setState(() {

                                  obscurePassword =

                                      !obscurePassword;

                                });

                              },

                              icon: Icon(

                                obscurePassword

                                    ? Icons

                                        .visibility_outlined

                                    : Icons

                                        .visibility_off_outlined,

                              ),

                            ),

                          ),

                        ),



                        const SizedBox(

                          height: 20,

                        ),



                        SizedBox(

                          width:

                              double.infinity,

                          height: 52,

                          child:

                              ElevatedButton(

                            onPressed:

                                isLoading

                                    ? null

                                    : login,

                            child: isLoading

                                ? const SizedBox(

                                    width: 22,

                                    height: 22,

                                    child:

                                        CircularProgressIndicator(

                                      strokeWidth:

                                          2.2,

                                    ),

                                  )

                                : const Text(

                                    'Login',

                                  ),

                          ),

                        ),

                      ],

                    ),

                  ),



                  const SizedBox(

                    height: 24,

                  ),



                  Row(

                    mainAxisAlignment:

                        MainAxisAlignment.center,

                    children: [

                      Icon(

                        Icons

                            .verified_user_outlined,

                        size: 14,

                        color: colors

                            .onSurfaceVariant,

                      ),

                      const SizedBox(

                        width: 6,

                      ),

                      Text(

                        'Secure business account',

                        style: TextStyle(

                          fontSize: 12,

                          color: colors

                              .onSurfaceVariant,

                        ),

                      ),

                    ],

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

}


