# KDE NEU RSS

Widget de leitura de notícias RSS/Atom para PLASMA 6.

## Recursos

- Adicionar feeds RSS ou Atom manualmente (URL)
- Múltiplos feeds ao mesmo tempo; as notícias são mescladas e ordenadas
  por data.
- Visual limpo,com miniatura   da imagem quando o feed fornecee um breve resumo
- Clique na notícia abre o link no navegador; passe o mouse para ver o
  resumo.
- Atualização manual ou automática editável na aba feeds.
- Limite de notícias configurável (exibição).
- Feed sem XML válido é ignorado com aviso discreto.

## Requisitos

- KDE Plasma 6 (testado no Plasma 6.3) - DEBIAN 13
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
