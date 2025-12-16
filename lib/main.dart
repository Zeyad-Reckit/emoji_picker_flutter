import 'package:flutter/material.dart';
import 'screens/basic_example_screen.dart';
import 'screens/controller_example_screen.dart';
import 'screens/custom_font_screen.dart';
import 'screens/dynamic_columns_screen.dart';
import 'screens/key_example_screen.dart';
import 'screens/whatsapp_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emoji Picker Examples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emoji Picker Examples'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Choose an example:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildExampleCard(
            context,
            title: 'Basic Example',
            description: 'Simple emoji picker implementation',
            icon: Icons.emoji_emotions,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BasicExampleScreen(),
              ),
            ),
          ),
          _buildExampleCard(
            context,
            title: 'Controller Example',
            description: 'Using EmojiPickerController to control categories',
            icon: Icons.category,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ControllerExampleScreen(),
              ),
            ),
          ),
          _buildExampleCard(
            context,
            title: 'Custom Font',
            description: 'Using Google Fonts with emoji picker',
            icon: Icons.font_download,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomFontScreen(),
              ),
            ),
          ),
          _buildExampleCard(
            context,
            title: 'Dynamic Columns',
            description: 'Responsive emoji columns based on screen size',
            icon: Icons.view_column,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DynamicColumnsScreen(),
              ),
            ),
          ),
          _buildExampleCard(
            context,
            title: 'Key Example',
            description: 'Using GlobalKey to clear recent emojis',
            icon: Icons.vpn_key,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const KeyExampleScreen(),
              ),
            ),
          ),
          _buildExampleCard(
            context,
            title: 'WhatsApp Style',
            description: 'Custom WhatsApp-style emoji picker',
            icon: Icons.message,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WhatsAppScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
