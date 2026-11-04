class Config {
  // Chaves PÚBLICAS de cliente (protegidas por RLS no banco). Nunca coloque service_role aqui.
  static const supabaseUrl = 'https://jpoxxjjmxntwjdmgcypi.supabase.co';
  static const supabaseKey = 'sb_publishable__21zkEoebAUtpDQsF-Eizg_fc1YSfbX';

  static const repo = 'HkfatalX/master-music';
  static const appName = 'Master Music';
  static const authRedirect = 'mastermusic-auth://callback';
  static const spotifyPort = 43821;
  static const spotifyRedirect = 'http://127.0.0.1:43821/callback';
  static const siteUrl = 'https://hkfatalx.github.io/Master-Music/';
  static const youtubeScope = 'https://www.googleapis.com/auth/youtube.readonly';
}
