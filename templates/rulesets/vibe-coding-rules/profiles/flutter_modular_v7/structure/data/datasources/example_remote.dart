import '../models/example_model.dart';

class ExampleRemoteDataSource {
  Future<ExampleModel> fetch() async {
    return const ExampleModel(id: '1', title: 'Example');
  }
}
