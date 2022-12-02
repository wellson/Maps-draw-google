import 'package:draw_on_the_map_app/map_widget.dart';
import 'package:draw_on_the_map_app/points_mock.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'draw_map_app',
        home: HomeScreen(),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      markers: markersMock,
      onLocationDisabled: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ative a localização do dispositivo'),
          ),
        );
      },
    );
  }
}
