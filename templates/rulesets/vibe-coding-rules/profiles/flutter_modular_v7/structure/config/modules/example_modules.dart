import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../data/repositories/example_repo.dart';
import '../../presentation/cubit/example_cubit.dart';
import '../../presentation/screens/example_screen.dart';
import '../routes/example_routes.dart';

final exampleModules = createModule(
  path: ExampleRoutes.base,
  register: (c) {
    c
      // Feature-scoped binds: bound on first route entry, disposed on last exit.
      ..addLazySingleton<ExampleRepo>(ExampleRepo.new)
      ..addLazySingleton<ExampleCubit>(ExampleCubit.new)
      ..route(
        ExampleRoutes.root,
        child: (ctx, state) => BlocProvider(
          create: (_) => inject<ExampleCubit>(),
          child: const ExampleScreen(),
        ),
      );
  },
);
