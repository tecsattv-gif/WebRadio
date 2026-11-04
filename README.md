# WebRádio

App Android para ouvir **as suas rádios** pela internet: você monta a sua lista com os links de streaming e o app toca em segundo plano, com controles na notificação, na tela de bloqueio, no fone e no **Android Auto**.

Versão atual: **1.1.0**

## Funções

- **Minha lista de rádios**: adicionar, editar, excluir e reordenar (arraste pela alça ☰). Nome, link do streaming, gênero/cidade e logo (opcional).
- **Testar link** antes de salvar: diz se o link é de áudio ou de uma página.
- Aceita link direto (MP3, AAC, OGG), **HLS (.m3u8)** e playlists **.pls / .m3u / .asx** (o app acha o áudio dentro delas).
- **Toca em segundo plano** com notificação, tela de bloqueio e botões do fone (play/pausa, próxima, anterior).
- **Reconexão automática**: se o sinal cai (túnel, estrada sem cobertura), o app tenta reconectar sozinho por vários minutos.
- **Nome da música tocando**: mostra título e artista quando a rádio envia (metadados ICY), também na notificação e no Android Auto.
- **Timer para desligar**: 15, 30, 45 min, 1 h, 1 h 30, 2 h ou tempo livre; o volume baixa aos poucos nos últimos 20 segundos.
- **Gravar a rádio**: grava a transmissão direto em arquivo (MP3/AAC/OGG, sem perder qualidade). Tela **Gravações** para ouvir, compartilhar/salvar e apagar.
- **Android Auto**: aparece como app de mídia, com a pasta "Minhas rádios", próxima/anterior e comando de voz ("tocar <nome da rádio> no WebRádio").
- **Sincronizar celulares** (menu ⋮): crie um código num celular e digite o mesmo código nos outros; a lista de rádios fica igual em todos (vale a alteração mais recente). Sincroniza ao abrir o app, ao voltar para ele e a cada mudança.
- **Rádios sugeridas** (menu ⋮): lista pública publicada pelo administrador. Qualquer usuário busca e adiciona à própria lista com um toque.
- **Modo administrador** (Rádios sugeridas > ⋮ > Entrar como administrador): com o e-mail tecsattv@gmail.com e a senha cadastrada no Firebase, publica rádios da própria lista e remove sugeridas (segurar a rádio).
- **Importar / Exportar** a lista (arquivo JSON ou texto "Nome | link", uma rádio por linha, também aceita M3U).
- Tela **Sobre** com a versão e os créditos.

## Firebase (banco online)

Projeto **WebRadio001** (`webradio001-c911b`), plano Spark (grátis). O app usa a API REST do Firestore e do Authentication (sem SDK nativo).

- `radios_publicas/{id}`: rádios sugeridas (campos `name`, `url`, `genre`, `logoUrl`, `criado`). Leitura pública; gravação só do administrador.
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

Cadastre em **Settings > Secrets and variables > Actions**:

| Nome | Valor |
|---|---|
| `WEBRADIO_KEYSTORE` | chave em base64 (arquivo `segredos-github-webradio.txt`) |
| `WEBRADIO_KEYSTORE_PASSWORD` | senha da chave (mesmo arquivo) |

Sem esses segredos o APK é gerado com chave de teste, e cada versão nova exige desinstalar a anterior.

### Nova versão

Suba a versão à mão em `pubspec.yaml` a cada mudança (`1.0.0` → `1.1.0` → `1.2.0`…).

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
  screens/                      telas: início, editar rádio, gravações,
                                rádios sugeridas, sincronizar celulares
  widgets/                      cartão "tocando agora", logo, formatação
android_overlay/                manifesto Android (serviço de áudio + Android Auto)
tool/patch_android.py           ajusta a pasta android/ durante o build
assets/                         ícone do app
```

Tecnologia: Flutter, `just_audio` + `audio_service` (segundo plano e Android Auto).

## Histórico

- **1.1.0** – banco Firebase: sincronização da lista entre celulares por código, rádios sugeridas (lista pública) e modo administrador para publicar.
- **1.0.0** – primeira versão: lista de rádios, segundo plano, reconexão, nome da música, timer, gravação, Android Auto, importar/exportar.

---
Criado por **Luiz Alberto Cardoso** – tecsattv@gmail.com
