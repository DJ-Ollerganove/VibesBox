#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DJ B2B intro + Quickstart B2B: fließender Text, 30-Tage-Frist bei 14 Gratis-Tagen."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

DE = {
    "dj_b2b_intro": (
        "Bei DJ B2B wirbst du andere DJs für VibesBox an, und beide Seiten haben etwas davon: "
        "Der geworbene DJ bekommt zum Start 7 Tage Pro zum Testen – statt der üblichen 2 Tage. "
        "Du als Werber erhältst 14 Tage Pro gratis, sobald der Geworbene zum ersten Mal ein Pro-Abo abschließt; "
        "gutgeschrieben werden diese 14 Tage aber erst 30 Tage nach Beginn seines Abos. "
        "Du kannst sie ansammeln und einlösen, wann du willst – dazu beendest du dein aktives Abo, sofern es noch Pro ist. "
        "Wie lange du die eingelösten Tage nutzt, entscheidest du selbst."
    ),
    "dj_quickstart_p_b2b": (
        "Wirbt ein DJ einen anderen DJ für VibesBox an, erhält der Geworbene 7 Tage Pro zum Testen – statt der üblichen 2 Tage. "
        "Der Werber bekommt 14 Tage Pro gratis, sobald der Geworbene zum ersten Mal ein Pro-Abo abschließt; "
        "gutgeschrieben werden diese 14 Tage jedoch erst 30 Tage nach Abo-Beginn des Geworbenen. "
        "Sie lassen sich ansammeln und einlösen, wann er möchte – dazu beendet er sein aktives Abo, sofern es noch Pro ist. "
        "Wie lange er die gesammelten Tage nutzt, obliegt ihm allein."
    ),
}

TRANSLATIONS = {
    "en": {
        "dj_b2b_intro": (
            "With DJ B2B you refer other DJs to VibesBox, and both sides benefit: "
            "the referred DJ gets 7 days of Pro to try when starting out – instead of the usual 2 days. "
            "As the referrer you receive 14 days of Pro for free once the referred DJ purchases a Pro subscription for the first time; "
            "however, those 14 days are only credited 30 days after their subscription begins. "
            "You can accumulate and redeem them whenever you like – to do so, end your active subscription if it is still Pro. "
            "How long you use the redeemed days is entirely up to you."
        ),
        "dj_quickstart_p_b2b": (
            "When a DJ refers another DJ to VibesBox, the referred DJ gets 7 days of Pro to try – instead of the usual 2 days. "
            "The referrer receives 14 days of Pro for free once the referred DJ purchases a Pro subscription for the first time; "
            "however, those 14 days are only credited 30 days after the referred DJ's subscription begins. "
            "They can be accumulated and redeemed whenever they want – by ending their active subscription if it is still Pro. "
            "How long they use the accumulated days is entirely up to them."
        ),
    },
    "fr": {
        "dj_b2b_intro": (
            "Avec DJ B2B, tu parraines d'autres DJs sur VibesBox, et les deux y gagnent : "
            "le DJ parrainé reçoit 7 jours Pro à l'essai au départ – au lieu des 2 jours habituels. "
            "Toi, en tant que parrain, tu obtiens 14 jours Pro gratuits dès que le parrainé souscrit pour la première fois un abonnement Pro ; "
            "ces 14 jours ne sont toutefois crédités que 30 jours après le début de son abonnement. "
            "Tu peux les cumuler et les utiliser quand tu veux – en mettant fin à ton abonnement actif s'il est encore Pro. "
            "La durée pendant laquelle tu utilises ces jours te revient entièrement."
        ),
        "dj_quickstart_p_b2b": (
            "Si un DJ parraine un autre DJ pour VibesBox, le parrainé reçoit 7 jours Pro à l'essai – au lieu de 2 jours. "
            "Le parrain obtient 14 jours Pro gratuits dès que le parrainé souscrit pour la première fois un abonnement Pro ; "
            "ces 14 jours ne sont toutefois crédités que 30 jours après le début de l'abonnement du parrainé. "
            "Ils peuvent être cumulés et utilisés quand il le souhaite – en mettant fin à son abonnement actif s'il est encore Pro. "
            "La durée d'utilisation lui appartient entièrement."
        ),
    },
    "es": {
        "dj_b2b_intro": (
            "Con DJ B2B invitas a otros DJs a VibesBox, y ambos se benefician: "
            "el DJ recomendado recibe 7 días Pro de prueba al empezar – en lugar de los 2 días habituales. "
            "Tú como recomendador obtienes 14 días Pro gratis en cuanto el recomendado contrata por primera vez un abono Pro; "
            "sin embargo, esos 14 días solo se abonan 30 días después del inicio de su abono. "
            "Puedes acumularlos y canjearlos cuando quieras – finalizando tu abono activo si aún es Pro. "
            "Cuánto tiempo usas esos días lo decides tú."
        ),
        "dj_quickstart_p_b2b": (
            "Si un DJ recomienda a otro DJ a VibesBox, el recomendado recibe 7 días Pro de prueba – en lugar de 2 días. "
            "El recomendador obtiene 14 días Pro gratis cuando el recomendado contrata por primera vez un abono Pro; "
            "sin embargo, esos 14 días solo se abonan 30 días después del inicio del abono del recomendado. "
            "Pueden acumularse y canjearse cuando quiera – finalizando su abono activo si aún es Pro. "
            "Cuánto tiempo los usa lo decide él mismo."
        ),
    },
    "it": {
        "dj_b2b_intro": (
            "Con DJ B2B inviti altri DJ su VibesBox, e ne beneficiano entrambi: "
            "il DJ invitato riceve 7 giorni Pro di prova all'inizio – invece dei soliti 2 giorni. "
            "Tu come invitante ottieni 14 giorni Pro gratis non appena l'invitato sottoscrive per la prima volta un abbonamento Pro; "
            "tuttavia quei 14 giorni vengono accreditati solo 30 giorni dopo l'inizio del suo abbonamento. "
            "Puoi accumularli e riscattarli quando vuoi – terminando l'abbonamento attivo se è ancora Pro. "
            "Per quanto tempo usi quei giorni decidi tu."
        ),
        "dj_quickstart_p_b2b": (
            "Se un DJ invita un altro DJ a VibesBox, l'invitato riceve 7 giorni Pro di prova – invece di 2 giorni. "
            "Chi invita ottiene 14 giorni Pro gratis quando l'invitato sottoscrive per la prima volta un abbonamento Pro; "
            "tuttavia quei 14 giorni vengono accreditati solo 30 giorni dopo l'inizio dell'abbonamento dell'invitato. "
            "Possono essere accumulati e riscattati quando vuole – terminando l'abbonamento attivo se è ancora Pro. "
            "Per quanto tempo usarli decide lui."
        ),
    },
    "pt": {
        "dj_b2b_intro": (
            "Com o DJ B2B convidas outros DJs para a VibesBox, e ambos beneficiam: "
            "o DJ indicado recebe 7 dias Pro para testar no início – em vez dos habituais 2 dias. "
            "Tu como indicador obténs 14 dias Pro grátis assim que o indicado subscreve pela primeira vez um plano Pro; "
            "no entanto, esses 14 dias só são creditados 30 dias após o início da subscrição dele. "
            "Podes acumulá-los e resgatá-los quando quiseres – terminando a subscrição ativa se ainda for Pro. "
            "Quanto tempo usas esses dias decides tu."
        ),
        "dj_quickstart_p_b2b": (
            "Se um DJ indicar outro DJ para a VibesBox, o indicado recebe 7 dias Pro para testar – em vez de 2 dias. "
            "Quem indicou obtém 14 dias Pro grátis quando o indicado subscreve pela primeira vez um plano Pro; "
            "no entanto, esses 14 dias só são creditados 30 dias após o início da subscrição do indicado. "
            "Podem ser acumulados e resgatados quando quiser – terminando a subscrição ativa se ainda for Pro. "
            "Quanto tempo os usa decide ele."
        ),
    },
    "nl": {
        "dj_b2b_intro": (
            "Met DJ B2B werv je andere DJs voor VibesBox, en beiden profiteren: "
            "de geworvene krijgt bij de start 7 dagen Pro om te testen – in plaats van de gebruikelijke 2 dagen. "
            "Jij als werver ontvangt 14 dagen Pro gratis zodra de geworvene voor het eerst een Pro-abonnement afsluit; "
            "die 14 dagen worden echter pas 30 dagen na de start van zijn of haar abonnement bijgeschreven. "
            "Je kunt ze sparen en inwisselen wanneer je wilt – door je actieve abonnement te beëindigen als het nog Pro is. "
            "Hoe lang je die dagen gebruikt, bepaal je zelf."
        ),
        "dj_quickstart_p_b2b": (
            "Werft een DJ een andere DJ voor VibesBox, krijgt de geworvene 7 dagen Pro om te testen – in plaats van 2 dagen. "
            "De werver ontvangt 14 dagen Pro gratis zodra de geworvene voor het eerst een Pro-abonnement afsluit; "
            "die 14 dagen worden echter pas 30 dagen na de start van het abonnement van de geworvene bijgeschreven. "
            "Ze kunnen worden gespaard en ingewisseld wanneer hij wil – door het actieve abonnement te beëindigen als het nog Pro is. "
            "Hoe lang hij die dagen gebruikt, bepaalt hij zelf."
        ),
    },
    "pl": {
        "dj_b2b_intro": (
            "W programie DJ B2B zapraszasz innych DJ-ów do VibesBox i obie strony na tym korzystają: "
            "polecony DJ dostaje na start 7 dni Pro na test – zamiast zwykłych 2 dni. "
            "Ty jako polecający otrzymujesz 14 dni Pro gratis, gdy polecony po raz pierwszy kupi subskrypcję Pro; "
            "te 14 dni jest jednak naliczane dopiero 30 dni po rozpoczęciu jego subskrypcji. "
            "Możesz je zbierać i wykorzystać, kiedy chcesz – kończąc aktywną subskrypcję, jeśli nadal jest Pro. "
            "Jak długo korzystasz z tych dni, zależy od Ciebie."
        ),
        "dj_quickstart_p_b2b": (
            "Gdy DJ poleci VibesBox innemu DJ-owi, polecony dostaje 7 dni Pro na test – zamiast 2 dni. "
            "Polecający otrzymuje 14 dni Pro gratis, gdy polecony po raz pierwszy kupi subskrypcję Pro; "
            "te 14 dni jest jednak naliczane dopiero 30 dni po rozpoczęciu subskrypcji poleconego. "
            "Można je zbierać i wykorzystać, kiedy chce – kończąc aktywną subskrypcję, jeśli nadal jest Pro. "
            "Jak długo z nich korzysta, zależy wyłącznie od niego."
        ),
    },
    "cs": {
        "dj_b2b_intro": (
            "V programu DJ B2B doporučuješ jiné DJe do VibesBox a profitují obě strany: "
            "doporučený DJ dostane na začátek 7 dní Pro na vyzkoušení – místo obvyklých 2 dnů. "
            "Ty jako doporučující získáš 14 dní Pro zdarma, jakmile doporučený poprvé koupí Pro předplatné; "
            "těchto 14 dní se však připíše až 30 dní po začátku jeho předplatného. "
            "Můžeš je sbírat a uplatnit, kdy chceš – ukončením aktivního předplatného, pokud je stále Pro. "
            "Jak dlouho je využíváš, je jen na tobě."
        ),
        "dj_quickstart_p_b2b": (
            "Doporučí-li DJ jiného DJe do VibesBox, doporučený dostane 7 dní Pro na vyzkoušení – místo 2 dnů. "
            "Doporučující získá 14 dní Pro zdarma, jakmile doporučený poprvé koupí Pro předplatné; "
            "těchto 14 dní se však připíše až 30 dní po začátku předplatného doporučeného. "
            "Lze je sbírat a uplatnit, kdy chce – ukončením aktivního předplatného, pokud je stále Pro. "
            "Jak dlouho je využívá, je jen na něm."
        ),
    },
    "el": {
        "dj_b2b_intro": (
            "Με το DJ B2B προσκαλείς άλλους DJ στη VibesBox και ωφελούνται και οι δύο: "
            "ο προσκεκλημένος DJ παίρνει στην αρχή 7 ημέρες Pro δοκιμής – αντί για τις συνηθισμένες 2 ημέρες. "
            "Εσύ ως προσκαλών λαμβάνεις 14 ημέρες Pro δωρεάν μόλις ο προσκεκλημένος αγοράσει για πρώτη φορά συνδρομή Pro· "
            "αυτές οι 14 ημέρες πιστώνονται όμως μόνο 30 ημέρες μετά την έναρξη της συνδρομής του. "
            "Μπορείς να τις συσσωρεύεις και να τις εξαργυρώνεις όποτε θέλεις – τερματίζοντας την ενεργή συνδρομή αν είναι ακόμα Pro. "
            "Πόσο καιρό τις χρησιμοποιείς αποφασίζεις εσύ."
        ),
        "dj_quickstart_p_b2b": (
            "Αν ένας DJ προσκαλέσει άλλον DJ στη VibesBox, ο προσκεκλημένος παίρνει 7 ημέρες Pro δοκιμής – αντί για 2 ημέρες. "
            "Ο προσκαλών λαμβάνει 14 ημέρες Pro δωρεάν όταν ο προσκεκλημένος αγοράσει για πρώτη φορά συνδρομή Pro· "
            "αυτές οι 14 ημέρες πιστώνονται όμως μόνο 30 ημέρες μετά την έναρξη της συνδρομής του προσκεκλημένου. "
            "Μπορούν να συσσωρεύονται και να εξαργυρώνονται όποτε θέλει – τερματίζοντας την ενεργή συνδρομή αν είναι ακόμα Pro. "
            "Πόσο καιρό τις χρησιμοποιεί αποφασίζει μόνος του."
        ),
    },
    "ru": {
        "dj_b2b_intro": (
            "В программе DJ B2B вы приглашаете других DJ в VibesBox, и выигрывают обе стороны: "
            "приглашённый DJ получает на старте 7 дней Pro на пробу — вместо обычных 2 дней. "
            "Вы как пригласивший получаете 14 дней Pro бесплатно, когда приглашённый впервые оформит подписку Pro; "
            "однако эти 14 дней начисляются только через 30 дней после начала его подписки. "
            "Их можно накапливать и использовать, когда захотите — завершив активную подписку, если она ещё Pro. "
            "Как долго вы пользуетесь этими днями — решаете вы сами."
        ),
        "dj_quickstart_p_b2b": (
            "Если DJ приглашает другого DJ в VibesBox, приглашённый получает 7 дней Pro на пробу — вместо 2 дней. "
            "Пригласивший получает 14 дней Pro бесплатно, когда приглашённый впервые оформит подписку Pro; "
            "однако эти 14 дней начисляются только через 30 дней после начала подписки приглашённого. "
            "Их можно накапливать и использовать, когда захочет — завершив активную подписку, если она ещё Pro. "
            "Как долго он пользуется этими днями — решает только он."
        ),
    },
    "uk": {
        "dj_b2b_intro": (
            "У програмі DJ B2B ви запрошуєте інших DJ до VibesBox, і виграють обидві сторони: "
            "запрошений DJ отримує на старті 7 днів Pro на пробу — замість звичних 2 днів. "
            "Ви як запрошувач отримуєте 14 днів Pro безкоштовно, коли запрошений вперше оформить підписку Pro; "
            "однак ці 14 днів нараховуються лише через 30 днів після початку його підписки. "
            "Їх можна накопичувати та використовувати, коли забажаєте — завершивши активну підписку, якщо вона ще Pro. "
            "Як довго ви ними користуєтесь — вирішуєте ви."
        ),
        "dj_quickstart_p_b2b": (
            "Якщо DJ запрошує іншого DJ до VibesBox, запрошений отримує 7 днів Pro на пробу — замість 2 днів. "
            "Запрошувач отримує 14 днів Pro безкоштовно, коли запрошений вперше оформить підписку Pro; "
            "однак ці 14 днів нараховуються лише через 30 днів після початку підписки запрошеного. "
            "Їх можна накопичувати та використовувати, коли забажає — завершивши активну підписку, якщо вона ще Pro. "
            "Як довго він ними користується — вирішує лише він."
        ),
    },
    "tr": {
        "dj_b2b_intro": (
            "DJ B2B ile başka DJ'leri VibesBox'a davet edersiniz ve her iki taraf da kazanır: "
            "davet edilen DJ başlangıçta 2 gün yerine 7 gün Pro dener. "
            "Siz davet eden olarak, davet edilen ilk kez Pro aboneliği satın aldığında 14 gün ücretsiz Pro alırsınız; "
            "ancak bu 14 gün, onun aboneliği başladıktan 30 gün sonra hesabınıza eklenir. "
            "Bunları biriktirip istediğiniz zaman kullanabilirsiniz – aktif abonelik hâlâ Pro ise sonlandırarak. "
            "Ne kadar süre kullanacağınıza siz karar verirsiniz."
        ),
        "dj_quickstart_p_b2b": (
            "Bir DJ başka bir DJ'i VibesBox'a davet ederse, davet edilen 2 gün yerine 7 gün Pro dener. "
            "Davet eden, davet edilen ilk kez Pro aboneliği satın aldığında 14 gün ücretsiz Pro alır; "
            "ancak bu 14 gün, davet edilenin aboneliği başladıktan 30 gün sonra hesabına eklenir. "
            "Biriktirilip istendiğinde kullanılabilir – aktif abonelik hâlâ Pro ise sonlandırılarak. "
            "Ne kadar süre kullanacağına yalnızca o karar verir."
        ),
    },
    "ar": {
        "dj_b2b_intro": (
            "في DJ B2B تدعو DJs آخرين إلى VibesBox ويستفيد الطرفان: "
            "يحصل المدعو عند البداية على 7 أيام Pro للتجربة – بدلاً من يومين. "
            "وأنت كداعٍ تحصل على 14 يوماً Pro مجاناً بمجرد أن يشترك المدعو لأول مرة في Pro؛ "
            "غير أن هذه الـ 14 يوماً تُضاف إلى رصيدك فقط بعد 30 يوماً من بداية اشتراكه. "
            "يمكنك تجميعها واستخدامها متى شئت – بإنهاء اشتراكك النشط إن كان Pro. "
            "مدة استخدامك لها قرارك أنت."
        ),
        "dj_quickstart_p_b2b": (
            "إذا دعا DJ آخر DJ إلى VibesBox، يحصل المدعو على 7 أيام Pro للتجربة – بدلاً من يومين. "
            "ويحصل الداعي على 14 يوماً Pro مجاناً عندما يشترك المدعو لأول مرة في Pro؛ "
            "غير أن هذه الـ 14 يوماً تُضاف إلى رصيده فقط بعد 30 يوماً من بداية اشتراك المدعو. "
            "يمكن تجميعها واستخدامها متى شاء – بإنهاء الاشتراك النشط إن كان Pro. "
            "مدة استخدامه لها قراره هو."
        ),
    },
    "zh": {
        "dj_b2b_intro": (
            "通过 DJ B2B，你邀请其他 DJ 使用 VibesBox，双方都能受益："
            "被邀请的 DJ 入门时可试用 7 天 Pro——而非通常的 2 天。"
            "作为邀请人，当被邀请者首次购买 Pro 订阅时，你可获得 14 天免费 Pro；"
            "但这 14 天须在其订阅开始 30 天后才会计入你的账户。"
            "天数可累积并在需要时兑换——若当前订阅仍为 Pro，需先结束。"
            "使用多久由你自行决定。"
        ),
        "dj_quickstart_p_b2b": (
            "若一位 DJ 推荐另一位 DJ 使用 VibesBox，被推荐者可试用 7 天 Pro——而非通常的 2 天。"
            "当被推荐者首次购买 Pro 订阅时，推荐者可获得 14 天免费 Pro；"
            "但这 14 天须在其订阅开始 30 天后才会计入账户。"
            "天数可累积并在需要时兑换——若当前订阅仍为 Pro，需先结束。"
            "使用多久由其自行决定。"
        ),
    },
    "ja": {
        "dj_b2b_intro": (
            "DJ B2Bでは他のDJをVibesBoxに招待でき、双方がメリットを得ます。"
            "招待されたDJは通常2日の代わりに、最初に7日間Proを試せます。"
            "招待した側は、招待された人が初めてProを購入したとき14日間の無料Proを受け取れますが、"
            "この14日間は相手のサブスク開始から30日後に付与されます。"
            "日数は貯めて好きなときに使えます。まだProの場合は有効なサブスクを終了してください。"
            "使う期間はあなた次第です。"
        ),
        "dj_quickstart_p_b2b": (
            "DJが別のDJをVibesBoxに紹介すると、紹介された側は2日の代わりに7日間Proを試せます。"
            "紹介した側は、紹介された人が初めてProを購入したとき14日間の無料Proを受け取れますが、"
            "この14日間は相手のサブスク開始から30日後に付与されます。"
            "日数は貯めて好きなときに使えます。まだProの場合は有効なサブスクを終了します。"
            "使う期間は本人次第です。"
        ),
    },
    "hi": {
        "dj_b2b_intro": (
            "DJ B2B में आप अन्य DJ को VibesBox के लिए आमंत्रित करते हैं और दोनों को लाभ होता है: "
            "आमंत्रित DJ को शुरुआत में 2 दिनों के बजाय 7 दिन Pro मिलते हैं। "
            "आप आमंत्रक के रूप में, जब आमंत्रित पहली बार Pro खरीदता है तो 14 दिन मुफ्त Pro पाते हैं; "
            "लेकिन ये 14 दिन उसकी सदस्यता शुरू होने के 30 दिन बाद ही जमा होते हैं। "
            "आप इन्हें जमा करके जब चाहें उपयोग कर सकते हैं – सक्रिय Pro सदस्यता समाप्त करके। "
            "कितने समय तक उपयोग करेंगे, यह आप तय करते हैं।"
        ),
        "dj_quickstart_p_b2b": (
            "जब एक DJ दूसरे DJ को VibesBox के लिए आमंत्रित करता है, आमंत्रित को 2 दिनों के बजाय 7 दिन Pro मिलते हैं। "
            "आमंत्रक को 14 दिन मुफ्त Pro तब मिलते हैं जब आमंत्रित पहली बार Pro खरीदता है; "
            "लेकिन ये 14 दिन आमंत्रित की सदस्यता शुरू होने के 30 दिन बाद ही जमा होते हैं। "
            "इन्हें जमा करके जब चाहें उपयोग किया जा सकता है – सक्रिय Pro सदस्यता समाप्त करके। "
            "कितने समय तक उपयोग करेगा, यह उसी पर निर्भर है।"
        ),
    },
    "vi": {
        "dj_b2b_intro": (
            "Với DJ B2B bạn mời DJ khác dùng VibesBox và cả hai đều được lợi: "
            "DJ được giới thiệu nhận 7 ngày Pro dùng thử khi bắt đầu – thay vì 2 ngày thông thường. "
            "Bạn là người giới thiệu sẽ nhận 14 ngày Pro miễn phí khi người được giới thiệu mua Pro lần đầu; "
            "tuy nhiên 14 ngày này chỉ được cộng vào tài khoản sau 30 ngày kể từ khi gói của họ bắt đầu. "
            "Bạn có thể tích lũy và đổi khi muốn – bằng cách kết thúc gói Pro đang hoạt động. "
            "Dùng bao lâu là quyết định của bạn."
        ),
        "dj_quickstart_p_b2b": (
            "Khi một DJ giới thiệu DJ khác dùng VibesBox, người được giới thiệu nhận 7 ngày Pro dùng thử – thay vì 2 ngày. "
            "Người giới thiệu nhận 14 ngày Pro miễn phí khi người được giới thiệu mua Pro lần đầu; "
            "tuy nhiên 14 ngày này chỉ được cộng sau 30 ngày kể từ khi gói của người được giới thiệu bắt đầu. "
            "Có thể tích lũy và đổi khi muốn – bằng cách kết thúc gói Pro đang hoạt động. "
            "Dùng bao lâu là quyết định của chính họ."
        ),
    },
    "sq": {
        "dj_b2b_intro": (
            "Me DJ B2B fton DJ të tjerë në VibesBox dhe përfitojnë të dyja palët: "
            "DJ i ftuar merr në fillim 7 ditë Pro për provë – në vend të 2 ditëve të zakonshme. "
            "Ti si ftesës merr 14 ditë Pro falas sapo i ftuari blen për herë të parë abonimin Pro; "
            "por këto 14 ditë kreditohen vetëm 30 ditë pas fillimit të abonimit të tij. "
            "Mund t'i grumbullosh dhe t'i përdorësh kur të duash – duke përfunduar abonimin aktiv nëse është ende Pro. "
            "Sa kohë i përdor, vendos vetë."
        ),
        "dj_quickstart_p_b2b": (
            "Kur një DJ fton një DJ tjetër në VibesBox, i ftuari merr 7 ditë Pro për provë – në vend të 2 ditëve. "
            "Ftesësi merr 14 ditë Pro falas kur i ftuari blen për herë të parë abonimin Pro; "
            "por këto 14 ditë kreditohen vetëm 30 ditë pas fillimit të abonimit të të ftuarit. "
            "Mund të grumbullohen dhe të përdoren kur të dojë – duke përfunduar abonimin aktiv nëse është ende Pro. "
            "Sa kohë i përdor, vendos vetë."
        ),
    },
}


def main() -> None:
    en = TRANSLATIONS["en"]
    for arb in sorted(L10N.glob("app_*.arb")):
        code = arb.stem.replace("app_", "")
        updates = DE if code == "de" else TRANSLATIONS.get(code, en)
        data = json.loads(arb.read_text(encoding="utf-8"))
        for k, v in updates.items():
            data[k] = v
        arb.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
        print(f"updated {arb.name}")


if __name__ == "__main__":
    main()
