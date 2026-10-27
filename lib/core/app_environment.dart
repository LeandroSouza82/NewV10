/// Configuração única do Supabase (produção). Valores podem ser sobrescritos via --dart-define.
class AppEnvironment {
  static const productionProjectRef = 'uqxoadxqcwidxqsfayem';

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://$productionProjectRef.supabase.co',
  );

  static const publicKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_1CjXy3Z1lPIIYmcn8HFvGQ_kHR7EIi_',
  );
}
