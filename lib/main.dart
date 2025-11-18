import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/task_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/species_provider.dart';
import 'providers/preset_provider.dart';
import 'providers/rembg_model_provider.dart';
import 'theme/app_theme.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 打印 API 配置信息（调试用）
  ApiConfig.printConfig();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SpeciesProvider()),
        ChangeNotifierProvider(create: (_) => PresetProvider()),
        ChangeNotifierProvider(create: (_) => RembgModelProvider()),
      ],
      child: MaterialApp(
        title: '宠物AI动作生成实验室',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}

