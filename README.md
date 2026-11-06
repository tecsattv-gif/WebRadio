# WebRádio

App Android para ouvir **as suas rádios** pela internet: você monta a sua lista com os links de streaming e o app toca em segundo plano, com controles na notificação, na tela de bloqueio, no fone e no **Android Auto**.

Versão atual: **1.8.5**

## Funções

- **Visual**: tela de abertura (2,5 s) com versão e créditos; cartão "tocando agora" com a cor tirada do logo da rádio; equalizador animado quando está ao vivo; **player em tela cheia** (toque no cartão) com logo grande e controles.
- **Separar por gênero**: botões de gênero em cima da lista (Todas, Sertanejo, Podcast…), com a quantidade de rádios de cada um; também nas Rádios sugeridas. O campo Gênero do cadastro sugere os gêneros já usados. Com um gênero escolhido a lista não reordena (volte em "Todas" para arrastar).
- **Notificações**: ao abrir pela primeira vez o app explica e pede a permissão de notificação (Android 13+). Sem ela o Android/Xiaomi pode parar a rádio em segundo plano; enquanto estiver bloqueada aparece uma faixa na tela inicial que leva direto ao ajuste.
- **Outros apps, ligações e GPS**: por padrão a rádio **continua tocando** quando outro app pega o som (opção em Configurações > Geral). Só pausa em **ligação** (telefone ou WhatsApp, detectada pelo modo de áudio do Android) e volta sozinha ao desligar; vídeos e áudios curtos de outros apps não param a rádio; quando o GPS (Maps/Waze) fala, o volume abaixa e depois volta; ao desconectar o fone, pausa.
- **Cadeado**: no topo (tela inicial e player) fica o cadeado **fechado**; um toque mostra o balão "Toque e segure para travar" e o toque longo trava a tela. Travado, aparece o cadeado **aberto**: tocar nele ou em qualquer lugar da tela mostra o balão com a instrução, e segurar o cadeado (anel enchendo) destrava. O celular vibra ao travar (uma vibração firme) e ao destravar (duas curtas). Travado, os toques não fazem nada (não troca rádio) e o botão voltar não fecha o app. Opção em Configurações > Geral: **Fixar a tela ao travar** (fixação de app do Android; nem o botão de início sai).
- **Bluetooth**: ícone discreto no topo (tela inicial e player em tela cheia) que abre as configurações de Bluetooth do Android para conectar caixa de som, fone ou o carro. O Android não permite que apps liguem o Bluetooth sozinhos.
- **Configurações** (engrenagem no topo), com duas abas:
  - **Buscar rádios**: busca no diretório gratuito Radio Browser por nome, estilo (Sertanejo, Gospel, Notícias, Forró…) e país (Brasil por padrão). Toque no ▶ para ouvir antes e no + para adicionar à lista — o app já traz o logo (convertido) e o gênero. O botão **Rádios perto de mim (FM local)** (1.8.7) usa o GPS: mostra as rádios do diretório num raio de 120 km, a mais perto primeiro (com a distância), e depois as do seu estado/região sem posição no mapa. O país e o estado vêm do OpenStreetMap (Nominatim). A localização só é pedida quando você toca no botão. Só aparecem rádios que transmitem pela internet (o Radio Browser não tem todas as FMs; o celular não sintoniza FM pelo ar).
  - **Geral**: Rádios sugeridas, Sincronizar celulares, Backup e restauração, Gravações, Procurar atualização e Sobre.
- **Tela deitada e tablet**: em telas largas (central multimídia Android do carro, tablet, celular deitado) a tela inicial se divide em duas: player grande à esquerda e lista de rádios à direita. O player em tela cheia também tem versão deitada (logo de um lado, controles do outro). Em tablet em pé, o conteúdo e os formulários ficam centralizados.
- **Central multimídia do carro**: instala como em qualquer Android 7+ (baixe o APK em Releases pelo navegador da central ou copie por pendrive). Os botões de mídia do volante funcionam se a central repassar os botões padrão do Android.
- **Minha lista de rádios**: adicionar, editar, excluir e reordenar (arraste pela alça ☰). Nome, link do streaming, gênero/cidade e logo (opcional).
- **Logo automático**: escolha uma imagem da galeria ou cole o link de uma imagem; o app baixa e converte sozinho num logo pequeno (PNG 128 px) guardado dentro da rádio. Assim o logo funciona sem internet, aparece na notificação/Android Auto e vai junto na sincronização e nas rádios sugeridas. Aceita PNG, JPG, WEBP e GIF (SVG não).
- **Testar link** antes de salvar: diz se o link é de áudio ou de uma página.
- Aceita link direto (MP3, AAC, OGG), **HLS (.m3u8)** e playlists **.pls / .m3u / .asx** (o app acha o áudio dentro delas).
- **Toca em segundo plano** com notificação, tela de bloqueio e botões do fone (play/pausa, próxima, anterior). Fechar o app (arrastar para fora dos recentes) para a rádio.
- **Reconexão automática**: se o sinal cai (túnel, estrada sem cobertura), o app tenta reconectar sozinho por vários minutos.
- **Nome da música tocando**: mostra título e artista quando a rádio envia (metadados ICY), também na notificação e no Android Auto.
- **Timer para desligar**: 15, 30, 45 min, 1 h, 1 h 30, 2 h ou tempo livre; o volume baixa aos poucos nos últimos 20 segundos.
- **Gravar a rádio**: grava a transmissão direto em arquivo (MP3/AAC/OGG, sem perder qualidade). Tela **Gravações** para ouvir, compartilhar/salvar e apagar.
- **Android Auto**: aparece como app de mídia, com a pasta "Minhas rádios", próxima/anterior e comando de voz ("tocar <nome da rádio> no WebRádio").
- **Sincronizar celulares** (Configurações > Geral): crie um código num celular e digite o mesmo código nos outros; a lista de rádios fica igual em todos (vale a alteração mais recente). Sincroniza ao abrir o app, ao voltar para ele e a cada mudança.
- **Rádios sugeridas** (Configurações > Geral): lista pública publicada pelo administrador. Qualquer usuário busca e adiciona à própria lista com um toque.
- **Modo administrador** (Rádios sugeridas > ⋮ > Entrar como administrador): com o e-mail tecsattv@gmail.com e a senha cadastrada no Firebase, publica rádios da própria lista e remove sugeridas (segurar a rádio).
- **Rádios já instaladas** (1.8.6): quem instala o app pela primeira vez já encontra a lista padrão de 24 rádios (com gêneros e logos), tirada de um backup do app e guardada em `assets/default_stations.json`. Só vale na primeira abertura: quem já tem o app continua com a própria lista, e quem apagar todas as rádios não recebe a lista de volta. Para trocar a lista padrão, substitua esse arquivo por um backup novo e gere uma versão.
- **Backup e restauração** (Configurações > Geral): salvar o backup no celular (você escolhe a pasta; mesmo nome substitui o anterior), compartilhar (Drive, WhatsApp, e-mail) e restaurar, substituindo a lista ou só juntando as rádios que faltam. O backup leva as rádios com os logos; as gravações não entram.
- **Importar links** (em Backup e restauração): colar texto "Nome | link", uma rádio por linha, ou M3U.
- **Atualização pelo próprio app**: ao abrir, o app confere a última versão nas Releases do GitHub, pergunta se quer atualizar, baixa o APK e abre o instalador. Também em Configurações > Geral > Procurar atualização. Na primeira vez o Android pede para permitir "Instalar apps desconhecidos" para o WebRádio.
- Tela **Sobre** com a versão e os créditos.

## Firebase (banco online)

Projeto **WebRadio001** (`webradio001-c911b`), plano Spark (grátis). O app usa a API REST do Firestore e do Authentication (sem SDK nativo).

- `radios_publicas/{id}`: rádios sugeridas (campos `name`, `url`, `genre`, `logoUrl`, `logoData`, `criado`). Leitura pública; gravação só do administrador.
- `listas/{codigo}`: lista sincronizada de cada código (campos `dados` = JSON das rádios, `atualizado` = hora em ms).
- Authentication: provedor **E-mail/senha**, usuário administrador tecsattv@gmail.com. A senha não fica no código.

Regras do Firestore:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /radios_publicas/{id} {
      allow read: if true;
      allow write: if request.auth != null
        && request.auth.token.email == 'tecsattv@gmail.com';
    }
    match /listas/{codigo} {
      allow read, write: if codigo.size() >= 12;
    }
  }
}
```

## Limitações

- Rádios em **HLS (.m3u8)** tocam, mas **não dá para gravar**.
- A gravação continua enquanto a rádio estiver tocando. Se pausar e deixar o app em segundo plano por muito tempo, o Android pode encerrar a gravação.
- Quem tiver o código de sincronização vê e altera a lista: só passe para quem você quiser.
- As gravações ficam na pasta interna do app (`Android/data/com.tecsattv.webradio/files/Gravacoes`). Para levar para outro lugar use **Compartilhar / salvar**.
- **Android Auto com APK instalado fora da Play Store**: no app Android Auto do celular, toque 10 vezes em "Versão" para ativar o modo desenvolvedor, depois nos três pontinhos > Configurações do desenvolvedor > marque **Fontes desconhecidas**. Sem isso o WebRádio não aparece no painel.

## Como gerar o APK

O APK é gerado automaticamente pelo GitHub Actions a cada envio para a branch `main`
(workflow `.github/workflows/build.yml`). O arquivo fica em:

- **Releases** do repositório (`WebRadio-<versão>.apk`), ou
- **Actions** > última execução > Artifacts.

### Chave de assinatura (para as atualizações instalarem por cima)

A chave fica no repositório **criptografada** (`keystore/release.jks.enc`). Só a senha abre, guardada como segredo em **Settings > Secrets and variables > Actions**:

| Nome | Valor |
|---|---|
| `WEBRADIO_KEYSTORE_PASSWORD` | senha da chave (arquivo `segredos-github-webradio.txt`) |

Sem esse segredo o APK é gerado com chave de teste, e cada versão nova exige desinstalar a anterior. O segredo `WEBRADIO_KEYSTORE` não é mais usado.

### Nova versão

Suba a versão à mão em `pubspec.yaml` a cada mudança (`1.0.0` → `1.1.0` → `1.2.0`…). O build publica a Release `v<versão>` e os celulares recebem o aviso de atualização. O repositório precisa continuar **público** para a atualização pelo app funcionar.

## Estrutura

```
lib/
  main.dart                     início do app e tema
  models/station.dart           dados de uma rádio
  services/radio_handler.dart   player, notificação, Android Auto, timer, reconexão
  services/recorder.dart        gravação da transmissão
  services/station_store.dart   lista salva no telefone, importar/exportar
  services/stream_resolver.dart links .pls/.m3u e teste de link
  services/firebase_api.dart    Firestore/Authentication (REST)
  services/sync_service.dart    sincronização da lista entre celulares
  services/logo_converter.dart  converte link/galeria em logo PNG pequeno
  services/radio_browser.dart   busca no diretório Radio Browser
  screens/settings_screen.dart  Configurações (abas Buscar rádios e Geral)
  screens/radio_search_tab.dart aba Buscar rádios
  services/update_service.dart  atualização pelo app (Releases do GitHub)
  screens/player_screen.dart    player em tela cheia
  screens/splash_screen.dart    abertura com créditos
  widgets/station_colors.dart   cor de cada rádio tirada do logo
  widgets/equalizer.dart        equalizador animado
  services/lock_service.dart    cadeado (trava toques, fixa a tela)
  widgets/lock_overlay.dart     botão do cadeado e camada de travamento
  widgets/bluetooth_button.dart atalho para o Bluetooth do Android
  widgets/genre_chips.dart      botões de gênero (filtro)
  screens/                      telas: início, editar rádio, gravações,
                                rádios sugeridas, sincronizar celulares,
                                backup e restauração
  widgets/                      cartão "tocando agora", logo, formatação
android_overlay/                manifesto Android (serviço de áudio + Android Auto)
tool/patch_android.py           ajusta a pasta android/ durante o build
assets/                         ícone do app e lista padrão de rádios (default_stations.json)
```

Tecnologia: Flutter, `just_audio` + `audio_service` (segundo plano e Android Auto), `image_picker` (galeria), `file_picker` (backup), `open_filex` (instalar atualização), `app_settings` (atalho do Bluetooth), `vibration` (vibração do cadeado), `geolocator` (Rádios perto de mim). A permissão de notificação é pedida direto pelo código Android do app (canal `webradio/notif`).

## Histórico

- **1.8.8** – fechar o app (arrastar para fora dos apps recentes) **para a rádio**; antes continuava tocando. Minimizado (botão Início ou outro app na frente) continua tocando normalmente.
- **1.8.7** – **Rádios perto de mim (FM local)** na aba Buscar rádios: acha pelo GPS as rádios da sua região, mais perto primeiro.
- **1.8.6** – o app já vem com 24 rádios na primeira instalação (lista padrão tirada do backup do Luiz).
- **1.8.5** – publica o pedido de notificação (1.8.3) e o espaço da barra de navegação (1.8.4), que não compilaram; a permissão agora é pedida sem o plugin permission_handler.
- **1.8.4** – listas (Configurações, Busca, Backup, Sincronizar, Gravações, Sugeridas, tela inicial) deixam espaço para a barra de navegação do Android; o item "Sobre" não fica mais escondido.
- **1.8.3** – pede a permissão de notificação (necessária para não parar em segundo plano) e mostra aviso enquanto estiver desligada.
- **1.8.2** – a rádio não para mais com vídeos/áudios curtos de outros apps: só pausa em ligação de verdade (telefone ou WhatsApp) e retoma ao desligar.

### Xiaomi/HyperOS: para não parar em segundo plano
Configurações > Apps > WebRádio > Economia de bateria > **Sem restrições**; e ativar **Início automático**. Na tela de apps recentes, segure o WebRádio e toque no cadeado para fixá-lo.
- **1.8.1** – vibração real ao travar (uma firme) e destravar (duas curtas), funcionando mesmo com a vibração de toque do sistema desligada.
- **1.8.0** – cadeado para travar a tela (não troca rádio nem fecha o app; segurar 2 s para destravar) e opção de fixar a tela; inclui as mudanças da 1.7.2 (continua tocando com outros apps), que não chegou a ser publicada.
- **1.7.2** – não pausa mais ao abrir outro app (opção "Continuar tocando com outros apps"); pausa em ligação e retoma depois; abaixa o volume quando o GPS fala; pausa ao desconectar o fone.
- **1.7.1** – botão discreto de Bluetooth no topo (abre as configurações de Bluetooth do Android).
- **1.7.0** – Configurações com aba **Buscar rádios** (Radio Browser: nome, estilo, país, ouvir antes, adicionar com logo) e aba **Geral**; inclui o layout para tela deitada/tablet da 1.6.0 (que não chegou a ser publicada).
- **1.6.0** – layout para tela deitada e tablet: tela inicial dividida (player + lista), player em tela cheia deitado, formulários centralizados, abertura ajustada.
- **1.5.1** – corrige a tela de abertura desalinhada (fundo agora ocupa a tela toda, conteúdo centralizado).
- **1.5.0** – separar por gênero: botões de filtro na lista e nas sugeridas; sugestão de gêneros já usados no cadastro.
- **1.4.0** – visual novo: abertura com créditos, cores pelo logo da rádio, equalizador animado, player em tela cheia, lista com destaque na rádio atual.
- **1.3.1** – primeira versão assinada com a chave definitiva (segredos WEBRADIO_KEYSTORE). Quem tem versão anterior precisa desinstalar uma única vez; daí em diante as atualizações instalam por cima.
- **1.3.0** – atualização pelo próprio app (avisa, baixa e instala com autorização) e tela de Backup e restauração (salvar no celular, compartilhar, restaurar substituindo ou juntando).
- **1.2.0** – logo automático: escolher da galeria ou colar link, com conversão para logo pequeno guardado na rádio (aparece também na notificação e no carro).
- **1.1.0** – banco Firebase: sincronização da lista entre celulares por código, rádios sugeridas (lista pública) e modo administrador para publicar.
- **1.0.0** – primeira versão: lista de rádios, segundo plano, reconexão, nome da música, timer, gravação, Android Auto, importar/exportar.

---
Criado por **Luiz Alberto Cardoso** – tecsattv@gmail.com
