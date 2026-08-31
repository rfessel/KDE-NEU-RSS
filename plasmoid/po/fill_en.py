#!/usr/bin/env python3
"""Preenche as traduções em inglês no po/en_US.po.
As msgids estão em português; este script aplica o dicionário EN.
Lida com msgids/msgstrs quebrados em várias linhas pelo gettext.
"""

import os, re

BASE = os.path.dirname(__file__)

EN = {
    "Informe uma URL válida (ex.: https://exemplo.com/feed.xml).":
        "Enter a valid URL (e.g. https://example.com/feed.xml).",
    "Esse feed já foi adicionado.": "This feed has already been added.",
    "Adicionar feed RSS": "Add RSS feed",
    "URL do feed (RSS ou Atom)…": "Feed URL (RSS or Atom)…",
    "Limpar": "Clear",
    "Adicionar": "Add",
    "Testando…": "Testing…",
    "Testar": "Test",
    "Seus feeds (%1)": "Your feeds (%1)",
    "Atualizar": "Update",
    "Atualização automática dos feeds": "Automatic feed update",
    "Nenhum feed adicionado. Cole a URL de um feed no campo acima e clique em “Adicionar”.":
        "No feed added. Paste a feed URL in the field above and click “Add”.",
    "Remover feed": "Remove feed",
    "Limite de notícias deste feed:": "News limit for this feed:",
    "notícias": "news items",
    "O limite total de notícias da lista está na seção “Exibição”. As alterações são aplicadas imediatamente.":
        "The total list news limit is in the “Display” section. Changes are applied immediately.",
    "Escolher ícone": "Choose icon",
    "Imagens (*.png *.jpg *.jpeg *.svg *.webp *.bmp)":
        "Images (*.png *.jpg *.jpeg *.svg *.webp *.bmp)",
    "Todos os arquivos (*)": "All files (*)",
    "Exibição": "Display",
    "Máximo total de notícias na lista:": "Maximum total news in the list:",
    "Linhas da chamada da matéria:": "Headline lines:",
    "linhas por notícia": "lines per news item",
    "Colunas de notícias:": "News columns:",
    "colunas no widget": "columns in widget",
    "Com mais de 1 coluna, as notícias são distribuídas automaticamente entre as colunas.":
        "With more than 1 column, the news items are distributed automatically between the columns.",
    "Este limite vale para a lista inteira, somando todos os feeds. Para ajustar cada fonte individualmente, use a seção “Feeds de notícias”.":
        "This limit applies to the whole list, adding up all feeds. To adjust each source individually, use the “News feeds” section.",
    "As alterações são aplicadas imediatamente ao widget.":
        "Changes are applied to the widget immediately.",
    "Ícone do widget": "Widget icon",
    "Este ícone aparece na barra de tarefas e no próprio widget.":
        "This icon appears on the taskbar and on the widget itself.",
    "Usar padrão": "Use default",
    "Carregar arquivo próprio…": "Load custom file…",
    "Use uma imagem (PNG, SVG, JPG…) do seu computador como ícone.":
        "Use an image (PNG, SVG, JPG…) from your computer as the icon.",
    "Ícone próprio em uso:\n%1": "Custom icon in use:\n%1",
    "Remover arquivo": "Remove file",
    "Digite o nome de um ícone…": "Type the name of an icon…",
    "Escolha um dos ícones acima, digite o nome de qualquer ícone do tema (ex.: rss, internet-mail, text-html) ou carregue um arquivo próprio.":
        "Choose one of the icons above, type the name of any theme icon (e.g. rss, internet-mail, text-html) or load a custom file.",
    "tempo esgotado": "timeout",
    "falha de conexão": "connection failure",
    "resposta inválida (não é RSS) ou servidor inacessível":
        "invalid response (not RSS) or unreachable server",
    "HTTP %1": "HTTP %1",
    "%1 — %2": "%1 — %2",
    "Falha em %1 (%2)": "Failure in %1 (%2)",
    "Atualizar notícias": "Update news",
    "Nenhum feed configurado": "No feed configured",
    "Nenhuma notícia encontrada": "No news found",
    "Nenhuma notícia carregada. Veja os detalhes abaixo.":
        "No news loaded. See details below.",
    "Adicionar feed…": "Add feed…",
    "Tentar novamente": "Try again",
    "Alguns feeds não carregaram:": "Some feeds did not load:",
    "Atualizado às %1": "Updated at %1",
    "Bom dia": "Good morning",
    "Boa tarde": "Good afternoon",
    "Boa noite": "Good evening",
}


def decode(s):
    return (s.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\'))


def encode(s):
    return (s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n'))


def parse(text):
    """Retorna lista de entradas: dict(msgid, msgstr, mparts, sparts, start).
    msgid/msgstr são as formas decodificadas (sem escapes gettext)."""
    lines = text.split('\n')
    entries, cur = [], None
    for idx, line in enumerate(lines):
        if line.startswith('msgid '):
            if cur:
                entries.append(cur)
            cur = {'msgid': '', 'mparts': [], 'str': '', 'sparts': [], 'start': idx}
            raw = line[6:].strip()
            if raw.startswith('"') and raw.endswith('"'):
                cur['mparts'].append(raw)
                cur['msgid'] = decode(raw[1:-1])
            else:
                cur['mparts'].append(line)
        elif line.startswith('msgstr ') and cur is not None:
            raw = line[7:].strip()
            if raw.startswith('"') and raw.endswith('"'):
                cur['sparts'].append(raw)
                cur['str'] = decode(raw[1:-1])
            else:
                cur['sparts'].append(line)
        elif line.startswith('"') and cur is not None:
            frag = line.strip()
            frag_inner = frag[1:-1]
            if cur['sparts']:
                cur['sparts'].append(frag)
                cur['str'] += decode(frag_inner)
            else:
                cur['mparts'].append(frag)
                cur['msgid'] += decode(frag_inner)
    if cur:
        entries.append(cur)
    return entries, lines


def main():
    path = os.path.join(BASE, 'en_US.po')
    entries, lines = parse(open(path, encoding='utf-8').read())
    edits = {}
    missing = []
    header = next((e for e in entries if e['start'] == 0 or (e['msgid'] == '' and e['sparts'])), None)
    for e in entries:
        if e['msgid'] == '':
            continue
        if e['msgid'] not in EN:
            missing.append(e['msgid'])
            continue
        edits[e['start']] = e
    if missing:
        print('SEM TRADUCAO: %d' % len(missing))
        for m in missing:
            print(' -', repr(m))
    out = []
    i = 0
    while i < len(lines):
        if i in edits:
            e = edits[i]
            val = EN[e['msgid']]
            out.append('msgid "%s"' % encode(e['msgid']))
            out.append('msgstr "%s"' % encode(val))
            i = e['start'] + len(e['mparts']) + len(e['sparts'])
        else:
            out.append(lines[i])
            i += 1
    open(path, 'w', encoding='utf-8').write('\n'.join(out))


if __name__ == '__main__':
    main()