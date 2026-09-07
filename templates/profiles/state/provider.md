# State Profile — provider

- Reuse existing ChangeNotifier/ValueNotifier/Provider patterns rather than introducing another state framework.
- Business state should not own navigation/dialog/snackbar side effects.
- Provider ownership/disposal must match widget/navigation lifetime.
- Keep mutations duplicate-safe and avoid rebuilding unrelated large widget subtrees.
