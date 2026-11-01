import '../datasources/example_remote.dart';
import '../models/example_model.dart';

class ExampleRepo {
  ExampleRepo(this._remote);

  final ExampleRemoteDataSource _remote;

  Future<ExampleModel> fetch() => _remote.fetch();
}
