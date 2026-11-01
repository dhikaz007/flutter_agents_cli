import 'package:flutter_modular/flutter_modular.dart';

import '../../data/repositories/example_repo.dart';
import '../../presentation/cubit/example_cubit.dart';

class ExampleBindModules extends Module {
  @override
  List<Module> get imports => <Module>[
        // Add shared or core bind modules here, e.g. ServiceBindModules(),
      ];

  @override
  void exportedBinds(Injector i) {
    i.addLazySingleton<ExampleRepo>(ExampleRepo.new);
    i.addLazySingleton<ExampleCubit>(ExampleCubit.new);
  }
}
