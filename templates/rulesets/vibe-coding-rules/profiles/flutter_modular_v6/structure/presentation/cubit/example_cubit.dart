import 'package:flutter_bloc/flutter_bloc.dart';

import 'example_state.dart';

class ExampleCubit extends Cubit<ExampleState> {
  ExampleCubit() : super(const ExampleState.initial());

  Future<void> load() async {
    emit(const ExampleState.loading());
    // TODO: read from the repo, e.g. Modular.get<ExampleRepo>()
    emit(const ExampleState.loaded('done'));
  }
}
