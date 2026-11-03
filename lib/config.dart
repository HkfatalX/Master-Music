class Config {
  // Chaves PÚBLICAS de cliente (protegidas por RLS no banco). Nunca coloque service_role aqui.
  static const supabaseUrl = 'https://jpoxxjjmxntwjdmgcypi.supabase.co';
  static const supabaseKey = 'sb_publishable__21zkEoebAUtpDQsF-Eizg_fc1YSfbX';

  static const repo = 'HkfatalX/master-music';
  static const appName = 'Master Music';
  static const authRedirect = 'com.mastermusic.master_music://login-callback';
  static const spotifyRedirect = 'com.mastermusic.master_music://callback';
}
