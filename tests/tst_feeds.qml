import QtQuick
import QtTest
import "feeds.js" as F

TestCase {
    name: "feeds"
    id: t

    readonly property string rssSample: '<?xml version="1.0" encoding="UTF-8"?>' +
        '<rss version="2.0"><channel>' +
        '<title>Exemplo Notícias</title>' +
        '<item><title>Primeira notícia &amp; mais</title><link>https://exemplo.com/1</link>' +
        '<pubDate>Tue, 25 Aug 2026 12:30:00 GMT</pubDate>' +
        '<description><![CDATA[<p>Texto <b>com</b> tags &amp; entidades.</p>]]></description>' +
        '<enclosure url="https://exemplo.com/img1.jpg" type="image/jpeg"/>' +
        '</item>' +
        '<item><title>Segunda notícia</title><link>https://exemplo.com/2</link>' +
        '<pubDate>Wed, 26 Aug 2026 08:00:00 GMT</pubDate></item>' +
        '</channel></rss>'

    readonly property string mediaSample: '<?xml version="1.0"?>' +
        '<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">' +
        '<channel><title>Com mídia</title>' +
        '<item><title>Com foto</title><link>https://m.com/1</link>' +
        '<media:content url="https://m.com/foto.jpg"/>' +
        '<description>&lt;img src="https://m.com/desc.jpg"/&gt; texto</description>' +
        '</item></channel></rss>'

    readonly property string atomSample: '<?xml version="1.0"?>' +
        '<feed xmlns="http://www.w3.org/2005/Atom">' +
        '<title>Feed Atom</title>' +
        '<entry><title>Notícia atom &amp; cia.</title><link rel="alternate" href="https://atom.com/1"/>' +
        '<updated>2026-08-27T10:00:00Z</updated><summary>Resumo simples</summary></entry>' +
        '</feed>'

    readonly property string googleAtomSample: '<?xml version="1.0"?>' +
        '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">' +
        '<channel><title>Google News estilo</title>' +
        '<item><title>Título</title>' +
        '<atom:link href="https://news.com/x"/>' +
        '<pubDate>Thu, 27 Aug 2026 15:00:00 GMT</pubDate>' +
        '</item></channel></rss>'

    readonly property string noDeclSample: '\ufeff<rss version="2.0"><channel>' +
        '<title>Sem declaração</title>' +
        '<item><title>Notícia sem XML decl</title><link>https://semd.cl/1</link>' +
        '<pubDate>Tue, 25 Aug 2026 12:30:00 GMT</pubDate></item></channel></rss>'

    function test_stripTags() {
        compare(F.stripTags("<p>Oi <b>amigo</b> &amp; tal</p>"), "Oi amigo & tal");
        compare(F.stripTags("a<br/>b"), "a b");
        compare(F.stripTags("x</p> <p>y"), "x y");
        compare(F.stripTags(null), "");
    }

    function test_parseDate() {
        verify(F.parseDate("Tue, 25 Aug 2026 12:30:00 GMT") > 0);
        verify(F.parseDate("2026-08-27T10:00:00Z") > 0);
        verify(F.parseDate("Wed, 26 Aug 26 08:00:00 GMT") > 0); // ano de 2 dígitos
        compare(F.parseDate(""), 0);
        compare(F.parseDate("lixo"), 0);
    }

    function test_relativeTime() {
        var now = Date.parse("2026-08-30T12:00:00Z");
        compare(F.relativeTime(now - 300000, now), "há 5 min");
        compare(F.relativeTime(now - 7200000, now), "há 2 h");
        compare(F.relativeTime(now - 3 * 86400000, now), "há 3 dias");
        compare(F.relativeTime(now - 30 * 86400000, now), "31 jul");
        compare(F.relativeTime(0, now), "");
    }

    function test_rootDetection() {
        verify(F.isFeed(rssSample));
        verify(F.isFeed(atomSample));
        verify(F.isFeed(noDeclSample)); // UOL: começa direto em <rss>, sem declaração
        verify(F.isAtom(atomSample));
        compare(F.feedSourceName(noDeclSample), "Sem declaração");
        compare(F.feedSourceName("não é xml"), "");
    }

    function test_parseNoDecl() {
        var items = F.parseRSSItems(noDeclSample, F.feedSourceName(noDeclSample));
        compare(items.length, 1);
        compare(items[0].title, "Notícia sem XML decl");
        compare(items[0].link, "https://semd.cl/1");
        verify(items[0].time > 0);
    }

    function test_parseRSS() {
        var items = F.parseRSSItems(rssSample, F.feedSourceName(rssSample));
        compare(items.length, 2);
        compare(items[0].title, "Primeira notícia & mais");
        compare(items[0].link, "https://exemplo.com/1");
        compare(items[0].source, "Exemplo Notícias");
        compare(items[0].image, "https://exemplo.com/img1.jpg");
        compare(items[0].summary, "Texto com tags & entidades.");
        verify(items[0].time > 0);
        compare(items[1].image, ""); // item sem imagem
        verify(items[1].time > items[0].time); // 26 ago é mais recente que 25 ago
    }

    function test_mediaContent() {
        var items = F.parseRSSItems(mediaSample, "Com mídia");
        compare(items.length, 1);
        compare(items[0].image, "https://m.com/foto.jpg"); // media:content tem prioridade
    }

    function test_atomLinkInRss() {
        var items = F.parseRSSItems(googleAtomSample, "Google News estilo");
        compare(items.length, 1);
        compare(items[0].link, "https://news.com/x"); // <atom:link href>
    }

    function test_parseAtom() {
        var items = F.parseAtomItems(atomSample, "Feed Atom");
        compare(items.length, 1);
        compare(items[0].title, "Notícia atom & cia.");
        compare(items[0].link, "https://atom.com/1");
        compare(items[0].summary, "Resumo simples");
        verify(items[0].time > 0);
    }

    function test_imageFromDescription() {
        compare(F.imageFromDescription('x <img src="https://a/b.jpg" alt="oi"> y'), "https://a/b.jpg");
        compare(F.imageFromDescription("sem imagem"), "");
    }

    function test_applyLimits() {
        var mk = function(t, n) { return { title: t, link: "", source: "s", time: n, summary: "", image: "" }; };
        var g1 = { items: [mk("a", 10), mk("b", 9), mk("c", 8), mk("d", 7)], cap: 2 };
        var g2 = { items: [mk("e", 12), mk("f", 11)], cap: 0 }; // sem limite por feed
        var r = F.applyLimits([g1, g2], 3);
        compare(r.length, 3); // limite global 3
        compare(r[0].title, "e"); // mais recente primeiro (12)
        compare(r[1].title, "f");
        compare(r[2].title, "a");
        var r2 = F.applyLimits([{ items: [mk("x", 1), mk("y", 2)], cap: 1 }], 100);
        compare(r2.length, 1);
        compare(r2[0].title, "x"); // <item> mais recente do feed é mantido conforme chega
        compare(F.applyLimits([], 10).length, 0);
    }

    function test_xhrAvailable() {
        verify(typeof XMLHttpRequest !== "undefined");
    }
}