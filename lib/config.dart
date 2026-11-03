class Config {
  // Chaves PÚBLICAS de cliente (protegidas por RLS no banco). Nunca coloque service_role aqui.
  static const supabaseUrl = 'https://arrpflufaxgmjsogtfue.supabase.co';
  static const supabaseKey = 'sb_publishable_qSe0qW4ITgzB4U7zJbGEuQ_JMkij5OK';

  static const repo = 'HkfatalX/master-music';
  static const appName = 'Master Music';
  static const authRedirect = 'com.mastermusic.master_music://login-callback';
  static const spotifyRedirect = 'com.mastermusic.master_music://callback';
}
