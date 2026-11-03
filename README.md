# Master Music 🎵

App Android de música moderno, gratuito e seguro (Flutter + Supabase).

- Login/cadastro seguros (Supabase Auth) — favoritos, playlists e histórico salvos na conta (RLS)
- Catálogo gratuito e legal do Audius, letras via LRCLIB
- Player com segundo plano, fila, aleatório, repetir e timer para dormir
- Conexão oficial com o Spotify (OAuth PKCE) — playlists e curtidas
- Aviso de atualização opcional + log de novidades dentro do app

## Baixar
Aba **Releases** deste repositório → último `MasterMusic-x.y.z.apk`.

## Lançar uma nova versão
1. Aumente `version:` no `pubspec.yaml` (ex.: `1.0.1+2`)
2. Adicione a entrada no topo de `assets/changelog.json`
3. Faça push na `main` — o GitHub Actions gera o APK e publica a Release.
   Quem está na versão antiga vê o aviso de atualização ao abrir o app.
