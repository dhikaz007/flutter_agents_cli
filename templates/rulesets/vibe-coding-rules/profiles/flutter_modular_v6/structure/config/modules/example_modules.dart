import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../presentation/cubit/example_cubit.dart';
import '../../presentation/screens/example_screen.dart';
import '../bind_modules/example_bind_modules.dart';
import '../routes/example_routes.dart';

class ExampleModules extends Module {
  @override
  List<Module> get imports => <Module>[ExampleBindModules()];

  @override
  void routes(r) {
    r.child(ExampleRoutes.root, child: (_) {
      return BlocProvider(
        create: (_) => Modular.get<ExampleCubit>(),
        child: const ExampleScreen(),
      );
    });
  }
}
