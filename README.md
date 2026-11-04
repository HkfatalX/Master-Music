# Master Music 🎵

Player de música moderno, gratuito e seguro — **app Android + site**, mesma conta.

- Site: https://hkfatalx.github.io/Master-Music/
- App (APK): aba **Releases** → `MasterMusic-x.y.z.apk`

## Recursos
- Login por e-mail + código de 6 dígitos (Supabase), Continuar com Google
- Catálogo gratuito e legal do Audius, letras via LRCLIB
- Favoritos, playlists e histórico sincronizados entre app e site
- Conexão com Spotify e YouTube/Google (playlists e curtidas)
- Aviso de atualização opcional + log de novidades

## Estrutura
- `index.html`, `app.js`, `style.css`, `404.html`, `img/` — site (GitHub Pages, branch `main`)
- `lib/`, `pubspec.yaml`, `assets/`, `tool/` — app Flutter (APK gerado pelo GitHub Actions)

## Nova versão do app
Aumente `version:` no `pubspec.yaml`, adicione a entrada no topo de `assets/changelog.json` e faça push na `main`.
