import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'data/repositories/user_repository.dart';
import 'logic/auth_provider.dart';
import 'logic/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // UserProvider depends on AuthProvider's uid: whenever the signed-in
        // user changes, re-fetch (or clear) the health profile. This is the
        // "connect user data logic to Firestore" wiring -- swap
        // FirebaseUserRepository() for MockUserRepository() here if you want
        // to develop/test without hitting the network.
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(userRepository: FirebaseUserRepository()),
          update: (_, auth, userProvider) {
            final provider = userProvider ??
                UserProvider(userRepository: FirebaseUserRepository());
            if (auth.uid != null) {
              provider.loadProfile(auth.uid!);
            } else {
              provider.clear();
            }
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Canned Food & Noodles Health Advisor',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        // TODO (Phase 5 continued): replace with your real auth/dashboard
        // screens once presentation/screens/* has actual widgets in it --
        // this upload's screen folders were empty, so there was nothing to
        // route to yet. AuthGate below is a placeholder that proves the
        // Firebase Auth <-> Firestore <-> Provider wiring works.
        home: const AuthGate(),
      ),
    );
  }
}

// Placeholder root widget: shows a sign-in form when signed out, and the
// loaded UserHealthProfile when signed in. Delete this once your real
// onboarding/dashboard screens exist -- route to those instead, reading
// AuthProvider/UserProvider the same way this widget does.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isSignedIn) {
      return const _SignInPlaceholder();
    }
    return const _ProfilePlaceholder();
  }
}

class _SignInPlaceholder extends StatefulWidget {
  const _SignInPlaceholder();

  @override
  State<_SignInPlaceholder> createState() => _SignInPlaceholderState();
}

class _SignInPlaceholderState extends State<_SignInPlaceholder> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (auth.isLoading) const CircularProgressIndicator(),
            if (!auth.isLoading)
              ElevatedButton(
                onPressed: () => auth.signIn(
                  email: _emailController.text.trim(),
                  password: _passwordController.text,
                ),
                child: const Text('Sign In'),
              ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: Center(
        child: userProvider.isLoading
            ? const CircularProgressIndicator()
            : userProvider.errorMessage != null
                ? Text('Error: ${userProvider.errorMessage}')
                : userProvider.profile == null
                    ? const Text('No profile loaded.')
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Welcome, ${userProvider.profile!.displayName}'),
                          Text('Conditions: ${userProvider.profile!.conditions}'),
                          Text('Allergies: ${userProvider.profile!.allergies}'),
                          Text(
                            'Voice Assistant: '
                            '${userProvider.profile!.voiceAssistant ? "On" : "Off"}',
                          ),
                        ],
                      ),
      ),
    );
  }
}
