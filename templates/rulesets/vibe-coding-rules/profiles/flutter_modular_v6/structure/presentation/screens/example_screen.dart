import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/example_cubit.dart';

class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExampleCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Example')),
      body: Center(child: Text(state.toString())),
    );
  }
}
