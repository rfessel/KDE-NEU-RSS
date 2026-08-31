# RSS Notícias — plasmoid de notícias para KDE Plasma 6

Widget de leitura de feeds RSS/Atom com visual inspirado no widget de
notícias do Windows 11: cartões arredondados, manchete em destaque, fonte
e tempo relativo, atualização automática e adição de feeds manualmente.

## Recursos

- Adicionar feeds RSS ou Atom manualmente (URL), direto no widget ou
  pelas configurações.
- Múltiplos feeds ao mesmo tempo; as notícias são mescladas e ordenadas
  por data.
- Visual estilo Windows 11: cartões com cantos arredondados, miniatura
  da imagem quando o feed fornece (enclosure / media:content), fonte e
  "há 5 min / há 2 h / há 3 dias".
- Clique na notícia abre o link no navegador; passe o mouse para ver o
  resumo.
- Atualização automática a cada 10 minutos + botão de atualizar; recarrega
  ao abrir o popup no painel.
- Limite de notícias configurável (exibição).
- Feed sem XML válido é ignorado com aviso discreto.

## Requisitos

- KDE Plasma 6 (testado no Plasma 6.3)
- `kpackagetool6` (parte do `plasma-workspace`)

## Instalação

```sh
cd ~/RSSNoticias
./install.sh
```

Ou manualmente:

```sh
kpackagetool6 -t Plasma/Applet -i ./plasmoid
```

Depois: botão direito no desktop → **Adicionar Widgets** → pesquise por
**RSS Notícias**. Se o widget não aparecer na lista, reinicie o
plasmashell:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

## Uso

1. Adicione o widget ao desktop (ou ao painel — na versão compacta, o
   ícone abre o popup).
2. Clique no botão **+** no cabeçalho e cole a URL de um feed, ou
   adicione pelas configurações (botão direito → *Configure RSS Notícias*).
3. Feeds sugeridos para testar:
   - `https://g1.globo.com/rss/g1/tecnologia/`
   - `https://www.tweakers.net/nieuws/overzicht/feed.xml`
   - `https://feeds.npr.org/1001/rss.xml`

## Desinstalação

```sh
cd ~/RSSNoticias
./uninstall.sh
```

## Estrutura

```
plasmoid/
├── metadata.json                 # metadados do pacote (Plasma/Applet)
└── contents/
    ├── config/
    │   ├── config.qml            # define a página de configurações
    │   └── main.xml              # esquema de configuração (feeds, maxItems)
    └── ui/
        ├── main.qml              # widget (PlasmoidItem + UI estilo Win11)
        ├── configGeneral.qml     # página: adicionar/remover feeds
        └── js/feeds.js           # parser RSS/Atom + carregamento (JS puro)
```

`feeds.js` não depende de `DOMParser` nem de `XmlListModel` (indisponíveis
neste Qt 6): faz a varredura XML com tokenização própria, cobrindo RSS 2.0,
Atom, CDATA, entidades, `enclosure`/`media:content` e links do tipo
`<atom:link href="…"/>` (Google Notícias).

## Testes

O parser é testado com `qmltestrunner` (Qt Quick Test), incluindo um teste
de ponta a ponta com o feed do G1:

```sh
cd tests
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tst_feeds.qml
```

## Licença

GPL-2.0-or-later