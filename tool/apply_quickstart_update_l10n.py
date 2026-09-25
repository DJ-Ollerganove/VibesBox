#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Quickstart: Berechtigungen, Vorab-Wünsche, Nachlaufzeit, DJ B2B, VibesBox-Update."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

REMOVE_KEYS = ("dj_quickstart_h1_stability", "dj_quickstart_p_stability")

DE = {
    "dj_quickstart_p_vibesbox": (
        "In der VibesBox bearbeitest du alle eingegangenen Wünsche. Alle regulären Gästewünsche landen in der Rubrik „Offen“. Vorabwünsche – sofern für die Party aktiviert – findest du ggf. in einer vierten Rubrik „Vorab“.\n\n"
        "Gewünschte Titel kannst du als gespielt markieren, ablehnen oder löschen. Beim Löschen werden sie vollständig aus der Datenbank entfernt. Besonders wichtige offene Wünsche markierst du mit dem Herz als Favorit.\n\n"
        "Alle Wünsche lassen sich per Drag & Drop in die gewünschte Reihenfolge verschieben. Bis zu drei Songs kannst du verankern – sie bleiben dann immer am Anfang der Wunschliste.\n\n"
        "Du kannst einen Gast sperren. Die Sperre basiert auf einem digitalen Fingerabdruck des Gastgeräts. Dieser ist nicht zu 100 % einmalig – in sehr seltenen Fällen können dadurch zwei oder mehr Gäste gemeinsam gesperrt erscheinen. Gesperrte Gäste kannst du bei Bedarf wieder freischalten."
    ),
    "dj_quickstart_h1_prewishes": "Vorab-Wünsche",
    "dj_quickstart_p_prewishes": (
        "Bei der Partyerstellung oder Partybearbeitung kannst du Vorabwünsche aktivieren – sofern der Start der Party noch mindestens mehr als 6 Stunden in der Zukunft liegt. "
        "Gäste können dann schon vor Partybeginn Titel vorschlagen. Du legst fest, ob die Vorabwünsche unbegrenzt sind oder pro Gast auf eine von dir gewünschte Anzahl begrenzt werden."
    ),
    "dj_quickstart_h1_grace": "Nachlaufzeit",
    "dj_quickstart_p_grace": (
        "Wenn die Party offiziell beendet ist, die Feier vor Ort aber noch weiterläuft, kannst du in den Einstellungen eine Nachlaufzeit einstellen. "
        "Du wählst dabei zwischen 0 und 120 Minuten. Solange bleibt die VibesBox für dich als DJ geöffnet – inklusive Rubrik Gesperrte Gäste und History-Liste."
    ),
    "dj_quickstart_h1_b2b": "DJ B2B",
    "dj_quickstart_p_b2b": (
        "Wirbt ein DJ einen anderen DJ für VibesBox an, erhält der Geworbene 7 Tage Pro zum Testen – statt der üblichen 2 Tage. "
        "Der Werber bekommt 14 Tage Pro gratis, sobald der Geworbene zum ersten Mal ein Pro-Abo abschließt. Diese Tage kann er ansammeln und einlösen, wann er möchte. "
        "Dazu beendet er sein aktives Abo, sofern es noch Pro ist. Wie lange er die gesammelten Tage nutzt, entscheidet er selbst. "
        "Die Gutschrift erfolgt erst 30 Tage nach Abo-Beginn des Geworbenen."
    ),
    "dj_quickstart_h1_permissions": "Berechtigungen",
    "dj_quickstart_p_permissions": (
        "Für stabile Erkennung und Hinweise: Mikrofon-Zugriff erlauben. "
        "In den Systemeinstellungen die Akku- bzw. Batterieoptimierung für die App lockern oder die App ausnehmen, "
        "damit Hintergrundaktivität und Benachrichtigungen zuverlässig bleiben."
    ),
}

TRANSLATIONS = {
    "en": {
        "dj_quickstart_p_vibesbox": (
            "In the VibesBox you handle all incoming requests. Regular guest requests appear under Open. Pre-wishes—if enabled for the party—may appear in a fourth tab, Pre-wishes.\n\n"
            "You can mark tracks as played, reject them, or delete them; deleting removes them completely from the database. Mark especially important open requests with the heart as favorites.\n\n"
            "All requests can be reordered by drag & drop. You can anchor up to three songs—they always stay at the top of the wish list.\n\n"
            "You can block a guest. Blocking is based on a digital fingerprint of the guest device. It is not 100% unique—in very rare cases two or more guests may appear blocked together. You can unblock guests when needed."
        ),
        "dj_quickstart_h1_prewishes": "Pre-wishes",
        "dj_quickstart_p_prewishes": (
            "When creating or editing a party, you can enable pre-wishes if the party start is still more than 6 hours in the future. "
            "Guests can then suggest tracks before the party begins. You decide whether pre-wishes are unlimited or limited to a number you choose per guest."
        ),
        "dj_quickstart_h1_grace": "Grace period",
        "dj_quickstart_p_grace": (
            "If the party has officially ended but the event on site is still running, you can set a grace period in Settings. "
            "Choose between 0 and 120 minutes. During that time the VibesBox stays open for you as the DJ—including Blocked guests and the History list."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "When a DJ refers another DJ to VibesBox, the referred DJ gets 7 days of Pro to try—instead of the usual 2 days. "
            "The referrer receives 14 days of Pro for free once the referred DJ purchases a Pro subscription for the first time. "
            "These days can be accumulated and redeemed whenever they want. To do so, they end their active subscription if it is still Pro. "
            "How long they use the accumulated days is up to them. The credit is granted only 30 days after the referred DJ's subscription begins."
        ),
        "dj_quickstart_h1_permissions": "Permissions",
        "dj_quickstart_p_permissions": (
            "For stable recognition and alerts: allow microphone access. "
            "In system settings, relax battery optimization for the app or exempt it so background activity and notifications stay reliable."
        ),
    },
    "fr": {
        "dj_quickstart_p_vibesbox": (
            "Dans la VibesBox, tu traites toutes les demandes reçues. Les demandes classiques arrivent dans Ouvert. Les pré-demandes – si activées – peuvent apparaître dans un quatrième onglet Pré-demandes.\n\n"
            "Tu peux marquer comme joué, refuser ou supprimer ; la suppression efface complètement la base de données. Marque les demandes importantes avec le cœur en favoris.\n\n"
            "Toutes les demandes peuvent être réordonnées par glisser-déposer. Tu peux ancrer jusqu'à trois titres – ils restent toujours en tête de la liste.\n\n"
            "Tu peux bloquer un invité via une empreinte numérique de l'appareil. Elle n'est pas unique à 100 % – dans de très rares cas, plusieurs invités peuvent sembler bloqués ensemble. Tu peux les débloquer si besoin."
        ),
        "dj_quickstart_h1_prewishes": "Pré-demandes",
        "dj_quickstart_p_prewishes": (
            "Lors de la création ou de la modification d'une soirée, tu peux activer les pré-demandes si le début est encore à plus de 6 heures. "
            "Les invités peuvent alors proposer des titres avant le début. Tu choisis si les pré-demandes sont illimitées ou limitées par invité."
        ),
        "dj_quickstart_h1_grace": "Prolongation",
        "dj_quickstart_p_grace": (
            "Si la soirée est officiellement terminée mais continue sur place, tu peux définir une prolongation dans les réglages – entre 0 et 120 minutes. "
            "Pendant ce temps, la VibesBox reste ouverte pour toi en tant que DJ, y compris Invités bloqués et Historique."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Si un DJ parraine un autre DJ pour VibesBox, le parrainé reçoit 7 jours Pro à l'essai – au lieu de 2 jours. "
            "Le parrain obtient 14 jours Pro gratuits dès que le parrainé souscrit pour la première fois un abonnement Pro. "
            "Ces jours peuvent être cumulés et utilisés quand il le souhaite, en mettant fin à son abonnement actif s'il est encore Pro. "
            "La durée d'utilisation des jours cumulés lui appartient. Le crédit n'est accordé que 30 jours après le début de l'abonnement du parrainé."
        ),
        "dj_quickstart_h1_permissions": "Autorisations",
        "dj_quickstart_p_permissions": (
            "Pour une reconnaissance et des alertes stables : autorise l'accès au micro. "
            "Dans les réglages système, assouplis l'optimisation batterie pour l'app ou exempte-la pour que l'activité en arrière-plan et les notifications restent fiables."
        ),
    },
    "es": {
        "dj_quickstart_p_vibesbox": (
            "En la VibesBox gestionas todas las peticiones entrantes. Las normales van a Abierto. Las anticipadas – si están activadas – pueden verse en una cuarta pestaña Anticipadas.\n\n"
            "Puedes marcar como reproducido, rechazar o eliminar; al eliminar se borran por completo de la base de datos. Marca peticiones importantes con el corazón como favoritas.\n\n"
            "Todas las peticiones se pueden reordenar arrastrando. Puedes anclar hasta tres canciones – siempre quedan al inicio de la lista.\n\n"
            "Puedes bloquear a un invitado mediante una huella digital del dispositivo. No es 100 % única – en casos muy raros varios invitados pueden quedar bloqueados juntos. Puedes desbloquearlos si hace falta."
        ),
        "dj_quickstart_h1_prewishes": "Peticiones anticipadas",
        "dj_quickstart_p_prewishes": (
            "Al crear o editar una fiesta puedes activar peticiones anticipadas si el inicio está a más de 6 horas en el futuro. "
            "Los invitados pueden sugerir temas antes del comienzo. Tú decides si son ilimitadas o limitadas por invitado."
        ),
        "dj_quickstart_h1_grace": "Tiempo de gracia",
        "dj_quickstart_p_grace": (
            "Si la fiesta ha terminado oficialmente pero sigue en el local, puedes configurar un tiempo de gracia en Ajustes – entre 0 y 120 minutos. "
            "Mientras tanto la VibesBox sigue abierta para ti como DJ, incluidos Invitados bloqueados e Historial."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Si un DJ recomienda a otro DJ a VibesBox, el recomendado recibe 7 días Pro de prueba – en lugar de 2 días. "
            "El recomendador obtiene 14 días Pro gratis cuando el recomendado contrata por primera vez un abono Pro. "
            "Puede acumular esos días y canjearlos cuando quiera, finalizando su abono activo si aún es Pro. "
            "La duración de uso le corresponde a él. El crédito se concede 30 días después del inicio del abono del recomendado."
        ),
        "dj_quickstart_h1_permissions": "Permisos",
        "dj_quickstart_p_permissions": (
            "Para un reconocimiento y avisos estables: permite el acceso al micrófono. "
            "En los ajustes del sistema, relaja la optimización de batería de la app o exímela para que la actividad en segundo plano y las notificaciones sigan siendo fiables."
        ),
    },
    "it": {
        "dj_quickstart_p_vibesbox": (
            "Nella VibesBox gestisci tutte le richieste in arrivo. Quelle regolari finiscono in Aperti. I pre-desideri – se attivati – possono comparire in una quarta scheda Pre-desideri.\n\n"
            "Puoi segnare come suonato, rifiutare o eliminare; l'eliminazione rimuove completamente dal database. Segna le richieste importanti con il cuore come preferiti.\n\n"
            "Tutte le richieste si possono riordinare trascinando. Puoi ancorare fino a tre brani – restano sempre in cima alla lista.\n\n"
            "Puoi bloccare un ospite tramite impronta digitale del dispositivo. Non è unica al 100% – in casi rarissimi più ospiti possono risultare bloccati insieme. Puoi sbloccarli se serve."
        ),
        "dj_quickstart_h1_prewishes": "Pre-desideri",
        "dj_quickstart_p_prewishes": (
            "Creando o modificando una festa puoi attivare i pre-desideri se l'inizio è ancora a più di 6 ore nel futuro. "
            "Gli ospiti possono proporre brani prima dell'inizio. Decidi se sono illimitati o limitati per ospite."
        ),
        "dj_quickstart_h1_grace": "Periodo di grazia",
        "dj_quickstart_p_grace": (
            "Se la festa è ufficialmente terminata ma continua sul posto, puoi impostare un periodo di grazia nelle Impostazioni – da 0 a 120 minuti. "
            "Nel frattempo la VibesBox resta aperta per te come DJ, inclusi Ospiti bloccati e Cronologia."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Se un DJ invita un altro DJ a VibesBox, l'invitato riceve 7 giorni Pro di prova – invece dei soliti 2 giorni. "
            "Chi invita ottiene 14 giorni Pro gratis quando l'invitato sottoscrive per la prima volta un abbonamento Pro. "
            "Può accumulare questi giorni e riscattarli quando vuole, terminando l'abbonamento attivo se è ancora Pro. "
            "Per quanto tempo usarli decide lui. Il accredito avviene solo 30 giorni dopo l'inizio dell'abbonamento dell'invitato."
        ),
        "dj_quickstart_h1_permissions": "Autorizzazioni",
        "dj_quickstart_p_permissions": (
            "Per riconoscimento e avvisi stabili: consenti l'accesso al microfono. "
            "Nelle impostazioni di sistema, riduci l'ottimizzazione batteria per l'app o escludila così attività in background e notifiche restano affidabili."
        ),
    },
    "pt": {
        "dj_quickstart_p_vibesbox": (
            "Na VibesBox tratas todos os pedidos recebidos. Os normais vão para Abertos. Pedidos antecipados – se ativados – podem aparecer num quarto separador Antecipados.\n\n"
            "Podes marcar como tocado, rejeitar ou apagar; ao apagar removem-se completamente da base de dados. Marca pedidos importantes com o coração como favoritos.\n\n"
            "Todos os pedidos podem ser reordenados arrastando. Podes ancorar até três músicas – ficam sempre no topo da lista.\n\n"
            "Podes bloquear um convidado com impressão digital do dispositivo. Não é 100% única – em casos muito raros vários convidados podem ficar bloqueados juntos. Podes desbloquear se necessário."
        ),
        "dj_quickstart_h1_prewishes": "Pedidos antecipados",
        "dj_quickstart_p_prewishes": (
            "Ao criar ou editar uma festa podes ativar pedidos antecipados se o início ainda estiver a mais de 6 horas no futuro. "
            "Os convidados podem sugerir músicas antes do início. Tu decides se são ilimitados ou limitados por convidado."
        ),
        "dj_quickstart_h1_grace": "Período de tolerância",
        "dj_quickstart_p_grace": (
            "Se a festa terminou oficialmente mas continua no local, podes definir um período de tolerância nas Definições – entre 0 e 120 minutos. "
            "Enquanto isso a VibesBox permanece aberta para ti como DJ, incluindo Convidados bloqueados e Histórico."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Se um DJ indicar outro DJ para a VibesBox, o indicado recebe 7 dias Pro para testar – em vez dos habituais 2 dias. "
            "Quem indicou recebe 14 dias Pro grátis quando o indicado subscreve pela primeira vez um plano Pro. "
            "Pode acumular esses dias e resgatá-los quando quiser, terminando a subscrição ativa se ainda for Pro. "
            "O crédito é concedido apenas 30 dias após o início da subscrição do indicado."
        ),
        "dj_quickstart_h1_permissions": "Permissões",
        "dj_quickstart_p_permissions": (
            "Para reconhecimento e alertas estáveis: permite acesso ao microfone. "
            "Nas definições do sistema, reduz a otimização de bateria da app ou isenta-a para que a atividade em segundo plano e as notificações permaneçam fiáveis."
        ),
    },
    "nl": {
        "dj_quickstart_p_vibesbox": (
            "In de VibesBox verwerk je alle binnenkomende verzoeken. Gewone gastverzoeken komen in Open. Vooraf-verzoeken – indien ingeschakeld – staan eventueel in een vierde tab Vooraf.\n\n"
            "Je kunt nummers als gedraaid markeren, afwijzen of verwijderen; verwijderen haalt ze volledig uit de database. Markeer belangrijke open verzoeken met het hart als favoriet.\n\n"
            "Alle verzoeken kun je herschikken via slepen. Je kunt tot drie nummers verankeren – die blijven altijd bovenaan de lijst.\n\n"
            "Je kunt een gast blokkeren via een digitale vingerafdruk van het apparaat. Die is niet 100% uniek – in zeer zeldzame gevallen kunnen meerdere gasten samen geblokkeerd lijken. Je kunt gasten weer deblokkeren."
        ),
        "dj_quickstart_h1_prewishes": "Vooraf-verzoeken",
        "dj_quickstart_p_prewishes": (
            "Bij het aanmaken of bewerken van een feest kun je vooraf-verzoeken inschakelen als de start nog meer dan 6 uur in de toekomst ligt. "
            "Gasten kunnen dan al vóór de start titels voorstellen. Jij bepaalt of ze onbeperkt zijn of per gast beperkt."
        ),
        "dj_quickstart_h1_grace": "Nachloopperiode",
        "dj_quickstart_p_grace": (
            "Als het feest officieel is afgelopen maar ter plaatse nog doorgaat, kun je in Instellingen een nachloopperiode instellen – tussen 0 en 120 minuten. "
            "Zolang blijft de VibesBox voor jou als DJ open, inclusief Geblokkeerde gasten en Geschiedenis."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Werft een DJ een andere DJ voor VibesBox, krijgt de geworvene 7 dagen Pro om te testen – in plaats van de gebruikelijke 2 dagen. "
            "De werver ontvangt 14 dagen Pro gratis zodra de geworvene voor het eerst een Pro-abonnement afsluit. "
            "Die dagen kunnen worden gespaard en ingewisseld wanneer gewenst, door het actieve abonnement te beëindigen als het nog Pro is. "
            "De tegoedverlening gebeurt pas 30 dagen na de start van het abonnement van de geworvene."
        ),
        "dj_quickstart_h1_permissions": "Machtigingen",
        "dj_quickstart_p_permissions": (
            "Voor stabiele herkenning en meldingen: sta microfoontoegang toe. "
            "Versoepel in de systeeminstellingen de batterijoptimalisatie voor de app of neem de app uit zodat achtergrondactiviteit en meldingen betrouwbaar blijven."
        ),
    },
    "pl": {
        "dj_quickstart_p_vibesbox": (
            "W VibesBox obsługujesz wszystkie przychodzące prośby. Zwykłe trafiają do Otwarte. Prośby z wyprzedzeniem – jeśli włączone – mogą być w czwartej zakładce Z wyprzedzeniem.\n\n"
            "Możesz oznaczyć jako zagrane, odrzucić lub usunąć; usunięcie całkowicie usuwa z bazy. Ważne otwarte oznacz sercem jako ulubione.\n\n"
            "Wszystkie prośby można zmieniać kolejnośćą przez przeciąganie. Możesz zakotwiczyć do trzech utworów – zawsze pozostają na początku listy.\n\n"
            "Możesz zablokować gościa po cyfrowym odcisku urządzenia. Nie jest w 100% unikalny – w bardzo rzadkich przypadkach kilku gości może wyglądać na zablokowanych razem. Możesz odblokować."
        ),
        "dj_quickstart_h1_prewishes": "Prośby z wyprzedzeniem",
        "dj_quickstart_p_prewishes": (
            "Przy tworzeniu lub edycji imprezy możesz włączyć prośby z wyprzedzeniem, jeśli start jest jeszcze za ponad 6 godzin. "
            "Goście mogą proponować utwory przed rozpoczęciem. Ty decydujesz, czy są bez limitu, czy ograniczone na gościa."
        ),
        "dj_quickstart_h1_grace": "Czas prolongaty",
        "dj_quickstart_p_grace": (
            "Gdy impreza oficjalnie się zakończyła, ale na miejscu jeszcze trwa, możesz ustawić czas prolongaty w Ustawieniach – od 0 do 120 minut. "
            "Przez ten czas VibesBox pozostaje otwarta dla Ciebie jako DJ – w tym Zablokowani goście i Historia."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Gdy DJ poleci VibesBox innemu DJ-owi, polecony otrzymuje 7 dni Pro na test – zamiast zwykłych 2 dni. "
            "Polecający dostaje 14 dni Pro gratis, gdy polecony po raz pierwszy kupi subskrypcję Pro. "
            "Dni można zbierać i wykorzystać, gdy chce – kończąc aktywną subskrypcję, jeśli nadal jest Pro. "
            "Naliczenie następuje dopiero 30 dni po rozpoczęciu subskrypcji poleconego."
        ),
        "dj_quickstart_h1_permissions": "Uprawnienia",
        "dj_quickstart_p_permissions": (
            "Dla stabilnego rozpoznawania i alertów: zezwól na dostęp do mikrofonu. "
            "W ustawieniach systemu złagodź optymalizację baterii dla aplikacji lub wyklucz ją, aby działanie w tle i powiadomienia były niezawodne."
        ),
    },
    "cs": {
        "dj_quickstart_p_vibesbox": (
            "Ve VibesBox zpracováváš všechna příchozí přání. Běžná končí v Otevřené. Předpřání – pokud jsou zapnutá – mohou být ve čtvrté záložce Předem.\n\n"
            "Můžeš označit jako přehrané, odmítnout nebo smazat; smazání je úplně odstraní z databáze. Důležitá otevřená označ srdcem jako oblíbená.\n\n"
            "Všechna přání lze přesouvat přetažením. Můžeš ukotvit až tři skladby – vždy zůstanou na začátku seznamu.\n\n"
            "Můžeš zablokovat hosta podle digitálního otisku zařízení. Není 100% jedinečný – ve velmi vzácných případech může být zablokováno více hostů najednou. Můžeš odblokovat."
        ),
        "dj_quickstart_h1_prewishes": "Předpřání",
        "dj_quickstart_p_prewishes": (
            "Při vytváření nebo úpravě party můžeš zapnout předpřání, pokud začátek je ještě více než 6 hodin v budoucnu. "
            "Hosté pak mohou navrhovat skladby před začátkem. Ty rozhoduješ, zda jsou neomezená, nebo omezená na hosta."
        ),
        "dj_quickstart_h1_grace": "Dodatečná doba",
        "dj_quickstart_p_grace": (
            "Když je party oficiálně ukončena, ale na místě pokračuje, můžeš v Nastavení nastavit dodatečnou dobu – 0 až 120 minut. "
            "Po tu dobu zůstane VibesBox pro tebe jako DJ otevřená – včetně Zablokovaných hostů a Historie."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Doporučí-li DJ jiného DJe do VibesBox, doporučený dostane 7 dní Pro na vyzkoušení – místo obvyklých 2 dnů. "
            "Doporučující získá 14 dní Pro zdarma, jakmile doporučený poprvé koupí Pro předplatné. "
            "Dny lze sbírat a uplatnit, kdy chce – ukončením aktivního předplatného, pokud je stále Pro. "
            "Připsání proběhne až 30 dní po začátku předplatného doporučeného."
        ),
        "dj_quickstart_h1_permissions": "Oprávnění",
        "dj_quickstart_p_permissions": (
            "Pro stabilní rozpoznávání a upozornění: povol přístup k mikrofonu. "
            "V systémovém nastavení omez optimalizaci baterie pro aplikaci nebo ji vyjmi, aby pozadí a oznámení fungovaly spolehlivě."
        ),
    },
    "el": {
        "dj_quickstart_p_vibesbox": (
            "Στη VibesBox διαχειρίζεσαι όλα τα εισερχόμενα αιτήματα. Τα κανονικά πηγαίνουν στα Ανοιχτά. Τα προ-αιτήματα – αν ενεργοποιηθούν – μπορεί να είναι σε τέταρτη καρτέλα.\n\n"
            "Μπορείς να σημειώσεις ως παιγμένο, απόρριψη ή διαγραφή· η διαγραφή τα αφαιρεί πλήρως από τη βάση. Σημαντικά ανοιχτά με καρδιά ως αγαπημένα.\n\n"
            "Όλα τα αιτήματα αναδιατάσσονται με drag & drop. Μπορείς να αγκυρώσεις έως τρία τραγούδια – μένουν πάντα στην κορυφή.\n\n"
            "Μπορείς να μπλοκάρεις καλεσμένο με ψηφιακό αποτύπωμα συσκευής. Δεν είναι 100% μοναδικό – σπάνια πολλοί καλεσμένοι μπορεί να φαίνονται μπλοκαρισμένοι μαζί."
        ),
        "dj_quickstart_h1_prewishes": "Προ-αιτήματα",
        "dj_quickstart_p_prewishes": (
            "Κατά τη δημιουργία ή επεξεργασία πάρτι μπορείς να ενεργοποιήσεις προ-αιτήματα αν η έναρξη είναι ακόμα πάνω από 6 ώρες στο μέλλον. "
            "Οι καλεσμένοι προτείνουν τραγούδια πριν την έναρξη. Εσύ αποφασίζεις αν είναι απεριόριστα ή ανά καλεσμένο."
        ),
        "dj_quickstart_h1_grace": "Περίοδος χάριτος",
        "dj_quickstart_p_grace": (
            "Αν το πάρτι έχει τελειώσει επίσημα αλλά συνεχίζεται στον χώρο, μπορείς να ορίσεις περίοδο χάριτος στις Ρυθμίσεις – 0 έως 120 λεπτά. "
            "Μέχρι τότε η VibesBox μένει ανοιχτή για εσένα ως DJ, συμπεριλαμβανομένων Μπλοκαρισμένων και Ιστορικού."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Αν ένας DJ προσκαλέσει άλλον DJ στη VibesBox, ο προσκεκλημένος παίρνει 7 ημέρες Pro δοκιμής – αντί για 2 ημέρες. "
            "Ο προσκαλών παίρνει 14 ημέρες Pro δωρεάν όταν ο προσκεκλημένος αγοράσει για πρώτη φορά συνδρομή Pro. "
            "Οι ημέρες συσσωρεύονται και εξαργυρώνονται όποτε θέλει, τερματίζοντας την ενεργή συνδρομή αν είναι ακόμα Pro. "
            "Η πίστωση γίνεται 30 ημέρες μετά την έναρξη της συνδρομής του προσκεκλημένου."
        ),
        "dj_quickstart_h1_permissions": "Άδειες",
        "dj_quickstart_p_permissions": (
            "Για σταθερή αναγνώριση και ειδοποιήσεις: επέτρεψε πρόσβαση στο μικρόφωνο. "
            "Στις ρυθμίσεις συστήματος χαλάρωσε τη βελτιστοποίηση μπαταρίας για την εφαρμογή ή εξαίρεσέ την."
        ),
    },
    "ru": {
        "dj_quickstart_p_vibesbox": (
            "В VibesBox вы обрабатываете все входящие пожелания. Обычные попадают в «Открытые». Предварительные — при включении — могут быть во вкладке «Предварительные».\n\n"
            "Можно отметить как сыгранное, отклонить или удалить; при удалении запись полностью удаляется из базы. Важные открытые отмечайте сердцем как избранные.\n\n"
            "Все пожелания можно менять порядком перетаскиванием. Можно закрепить до трёх песен — они всегда остаются в начале списка.\n\n"
            "Можно заблокировать гостя по цифровому отпечатку устройства. Он не уникален на 100% — в редких случаях могут быть заблокированы несколько гостей. Их можно разблокировать."
        ),
        "dj_quickstart_h1_prewishes": "Предварительные пожелания",
        "dj_quickstart_p_prewishes": (
            "При создании или редактировании вечеринки можно включить предварительные пожелания, если до начала осталось более 6 часов. "
            "Гости могут предлагать треки до старта. Вы решаете, безлимитны они или ограничены на гостя."
        ),
        "dj_quickstart_h1_grace": "Дополнительное время",
        "dj_quickstart_p_grace": (
            "Если вечеринка официально завершена, но на месте ещё продолжается, в Настройках можно задать дополнительное время — от 0 до 120 минут. "
            "Пока VibesBox остаётся открытой для вас как DJ — включая «Заблокированные» и «История»."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Если DJ приглашает другого DJ в VibesBox, приглашённый получает 7 дней Pro на пробу — вместо обычных 2 дней. "
            "Пригласивший получает 14 дней Pro бесплатно, когда приглашённый впервые оформит подписку Pro. "
            "Дни можно накапливать и использовать, когда захочет, завершив активную подписку, если она ещё Pro. "
            "Начисление происходит только через 30 дней после начала подписки приглашённого."
        ),
        "dj_quickstart_h1_permissions": "Разрешения",
        "dj_quickstart_p_permissions": (
            "Для стабильного распознавания и уведомлений: разрешите доступ к микрофону. "
            "В системных настройках ослабьте оптимизацию батареи для приложения или исключите его."
        ),
    },
    "uk": {
        "dj_quickstart_p_vibesbox": (
            "У VibesBox ви обробляєте всі вхідні побажання. Звичайні — у «Відкриті». Попередні — за наявності — у вкладці «Попередні».\n\n"
            "Можна позначити як зігране, відхилити або видалити. Важливі відкриті позначайте серцем. Усі побажання можна переставляти перетягуванням. До трьох пісень можна закріпити — вони завжди на початку списку.\n\n"
            "Можна заблокувати гостя за цифровим відбитком пристрою — не на 100% унікальним; у рідкісних випадках кілька гостей можуть бути заблоковані разом."
        ),
        "dj_quickstart_h1_prewishes": "Попередні побажання",
        "dj_quickstart_p_prewishes": (
            "Під час створення або редагування вечірки можна ввімкнути попередні побажання, якщо до початку ще понад 6 годин. "
            "Гості можуть пропонувати треки до старту. Ви вирішуєте, безлімітні вони чи обмежені на гостя."
        ),
        "dj_quickstart_h1_grace": "Додатковий час",
        "dj_quickstart_p_grace": (
            "Якщо вечірка офіційно завершена, але на місці ще триває, у Налаштуваннях можна задати додатковий час — від 0 до 120 хвилин. "
            "Поки VibesBox залишається відкритою для вас як DJ — включно з «Заблоковані» та «Історія»."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Якщо DJ запрошує іншого DJ до VibesBox, запрошений отримує 7 днів Pro на пробу — замість звичних 2 днів. "
            "Запрошувач отримує 14 днів Pro безкоштовно, коли запрошений вперше оформить підписку Pro. "
            "Дні можна накопичувати та використовувати, завершивши активну підписку, якщо вона ще Pro. "
            "Нарахування відбувається лише через 30 днів після початку підписки запрошеного."
        ),
        "dj_quickstart_h1_permissions": "Дозволи",
        "dj_quickstart_p_permissions": (
            "Для стабільного розпізнавання та сповіщень: дозвольте доступ до мікрофона. "
            "У системних налаштуваннях послабте оптимізацію батареї для застосунку або виключіть його."
        ),
    },
    "tr": {
        "dj_quickstart_p_vibesbox": (
            "VibesBox'ta tüm gelen istekleri yönetirsiniz. Normal istekler Açık'ta. Ön istekler – etkinse – dördüncü sekmede olabilir.\n\n"
            "Çalındı, reddedildi veya silindi işaretlenebilir; silme veritabanından tamamen kaldırır. Önemli açık istekleri kalp ile favori yapın.\n\n"
            "Tüm istekler sürükleyerek yeniden sıralanabilir. En fazla üç şarkıyı sabitleyebilirsiniz – her zaman listenin başında kalırlar.\n\n"
            "Misafiri cihaz parmak iziyle engelleyebilirsiniz – %100 benzersiz değildir; nadir durumlarda birden fazla misafir engellenmiş görünebilir."
        ),
        "dj_quickstart_h1_prewishes": "Ön istekler",
        "dj_quickstart_p_prewishes": (
            "Parti oluştururken veya düzenlerken, başlangıç hâlâ 6 saatten fazla gelecekteyse ön istekleri etkinleştirebilirsiniz. "
            "Misafirler parti başlamadan önce şarkı önerebilir. Sınırsız mı yoksa misafir başına sınırlı mı olacağına siz karar verirsiniz."
        ),
        "dj_quickstart_h1_grace": "Ek süre",
        "dj_quickstart_p_grace": (
            "Parti resmen bitti ama mekânda devam ediyorsa Ayarlar'da 0–120 dakika arası ek süre belirleyebilirsiniz. "
            "Bu süre boyunca VibesBox DJ olarak sizin için açık kalır – Engellenen misafirler ve Geçmiş dahil."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Bir DJ başka bir DJ'i VibesBox'a davet ederse, davet edilen 2 gün yerine 7 gün Pro dener. "
            "Davet eden, davet edilen ilk kez Pro aboneliği satın aldığında 14 gün ücretsiz Pro alır. "
            "Bu günler biriktirilebilir ve istendiğinde kullanılabilir – aktif abonelik hâlâ Pro ise sonlandırılarak. "
            "Hak ediş, davet edilenin aboneliği başladıktan 30 gün sonra yapılır."
        ),
        "dj_quickstart_h1_permissions": "İzinler",
        "dj_quickstart_p_permissions": (
            "Kararlı tanıma ve uyarılar için: mikrofon erişimine izin verin. "
            "Sistem ayarlarında uygulama için pil optimizasyonunu gevşetin veya uygulamayı hariç tutun."
        ),
    },
    "ar": {
        "dj_quickstart_p_vibesbox": (
            "في VibesBox تتعامل مع جميع الطلبات الواردة. الطلبات العادية في «مفتوحة». الأمنيات المسبقة – إن فُعلت – قد تكون في تبويب رابع.\n\n"
            "يمكن وضع علامة مُشغَّل أو رفض أو حذف؛ الحذف يزيلها كلياً من قاعدة البيانات. الأهم بالقلب كمفضلة.\n\n"
            "يمكن إعادة ترتيب جميع الطلبات بالسحب. يمكن تثبيت حتى ثلاث أغانٍ – تبقى دائماً في بداية القائمة.\n\n"
            "يمكن حظر ضيف ببصمة رقمية للجهاز – ليست فريدة 100%؛ نادراً قد يُحظر أكثر من ضيف معاً."
        ),
        "dj_quickstart_h1_prewishes": "أمنيات مسبقة",
        "dj_quickstart_p_prewishes": (
            "عند إنشاء الحفلة أو تعديلها يمكنك تفعيل الأمنيات المسبقة إذا كان البدء بعد أكثر من 6 ساعات. "
            "يمكن للضيوف اقتراح أغانٍ قبل البداية. أنت تحدد ما إذا كانت غير محدودة أو محدودة لكل ضيف."
        ),
        "dj_quickstart_h1_grace": "فترة إضافية",
        "dj_quickstart_p_grace": (
            "إذا انتهت الحفلة رسمياً لكنها ما زالت مستمرة في المكان، يمكنك ضبط فترة إضافية في الإعدادات – من 0 إلى 120 دقيقة. "
            "طوالها تبقى VibesBox مفتوحة لك كـ DJ – بما في ذلك المحظورون والسجل."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "إذا دعا DJ آخر DJ إلى VibesBox، يحصل المدعو على 7 أيام Pro للتجربة – بدلاً من يومين. "
            "يحصل الداعي على 14 يوماً Pro مجاناً عندما يشترك المدعو لأول مرة في Pro. "
            "يمكن تجميع الأيام واستخدامها عند الرغبة بإنهاء الاشتراك النشط إن كان Pro. "
            "يُضاف الرصيد بعد 30 يوماً من بداية اشتراك المدعو."
        ),
        "dj_quickstart_h1_permissions": "الأذونات",
        "dj_quickstart_p_permissions": (
            "لتعرف وإشعارات مستقرة: اسمح بالوصول إلى الميكروفون. "
            "في إعدادات النظام، خفّف تحسين البطارية للتطبيق أو استثنه."
        ),
    },
    "zh": {
        "dj_quickstart_p_vibesbox": (
            "在 VibesBox 中处理所有收到的请求。常规请求在「待处理」。若启用预许愿，可能在第四栏「预许愿」中。\n\n"
            "可标记为已播放、拒绝或删除；删除会从数据库完全移除。用爱心将重要待处理请求标为收藏。\n\n"
            "所有请求可通过拖拽调整顺序。最多可锚定三首歌曲——它们始终位于列表顶部。\n\n"
            "可封锁客人，基于设备数字指纹，并非 100% 唯一；极少数情况下可能多人同时被封锁。"
        ),
        "dj_quickstart_h1_prewishes": "预许愿",
        "dj_quickstart_p_prewishes": (
            "创建或编辑派对时，若开始时间仍在 6 小时之后，可启用预许愿。 "
            "客人可在派对开始前推荐曲目。你可设定为不限数量或按每位客人限制数量。"
        ),
        "dj_quickstart_h1_grace": "延长时间",
        "dj_quickstart_p_grace": (
            "若派对已正式结束但现场仍在进行，可在设置中设定 0 至 120 分钟的延长时间。 "
            "期间 VibesBox 仍对你作为 DJ 保持开放——包括已封锁客人和历史记录。"
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "若一位 DJ 推荐另一位 DJ 使用 VibesBox，被推荐者可试用 7 天 Pro——而非通常的 2 天。 "
            "当被推荐者首次购买 Pro 订阅时，推荐者可获得 14 天免费 Pro。 "
            "天数可累积并在需要时兑换——若当前订阅仍为 Pro，需先结束。 "
            "奖励在被推荐者订阅开始 30 天后发放。"
        ),
        "dj_quickstart_h1_permissions": "权限",
        "dj_quickstart_p_permissions": (
            "为获得稳定的识别与提醒：请允许麦克风访问。 "
            "在系统设置中放宽对本应用的电池优化或将其排除，以确保后台活动与通知可靠。"
        ),
    },
    "ja": {
        "dj_quickstart_p_vibesbox": (
            "VibesBoxでは届いたリクエストをすべて処理します。通常のリクエストは「未処理」に入ります。事前リクエストが有効な場合は4番目のタブに表示されることがあります。\n\n"
            "再生済み・拒否・削除が可能で、削除はデータベースから完全に消えます。重要な未処理はハートでお気に入りにできます。\n\n"
            "すべてのリクエストはドラッグで並べ替え可能です。最大3曲を固定でき、常にリストの先頭に残ります。\n\n"
            "ゲストは端末のデジタル指紋でブロックできます。100%一意ではなく、ごく稀に複数人が同時にブロック表示されることがあります。"
        ),
        "dj_quickstart_h1_prewishes": "事前リクエスト",
        "dj_quickstart_p_prewishes": (
            "パーティの作成・編集時、開始まで6時間以上ある場合に事前リクエストを有効にできます。 "
            "ゲストは開始前に曲を提案できます。無制限か、ゲストごとの上限かを選べます。"
        ),
        "dj_quickstart_h1_grace": "延長時間",
        "dj_quickstart_p_grace": (
            "パーティが公式に終了しても現場が続く場合、設定で0〜120分の延長時間を指定できます。 "
            "その間、DJとしてVibesBoxは開いたままです——ブロック済みゲストと履歴を含みます。"
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "DJが別のDJをVibesBoxに紹介すると、紹介された側は通常2日の代わりに7日間Proを試せます。 "
            "紹介した側は、紹介された人が初めてProを購入したとき14日間の無料Proを受け取ります。 "
            "日数は貯めて好きなときに使えます。まだProの場合は有効なサブスクを終了します。 "
            "付与は紹介された人のサブスク開始から30日後です。"
        ),
        "dj_quickstart_h1_permissions": "権限",
        "dj_quickstart_p_permissions": (
            "安定した認識と通知のため：マイクへのアクセスを許可してください。 "
            "システム設定でアプリのバッテリー最適化を緩和するか除外してください。"
        ),
    },
    "hi": {
        "dj_quickstart_p_vibesbox": (
            "VibesBox में सभी आने वाले अनुरोध संभालें। सामान्य अनुरोध «खुले» में। पूर्व-अनुरोध – यदि सक्षम – चौथे टैब में हो सकते हैं।\n\n"
            "बजाया, अस्वीकृत या हटाया जा सकता है; हटाने पर डेटाबेस से पूरी तरह हट जाता है। महत्वपूर्ण खुले अनुरोध दिल से पसंदीदा बनाएँ।\n\n"
            "सभी अनुरोध खींचकर क्रम बदल सकते हैं। अधिकतम तीन गाने एंकर कर सकते हैं – वे हमेशा सूची के शीर्ष पर रहते हैं।\n\n"
            "अतिथि को डिवाइस फिंगरप्रिंट से ब्लॉक किया जा सकता है – 100% अद्वितीय नहीं; कभी-कभी कई अतिथि एक साथ ब्लॉक दिख सकते हैं।"
        ),
        "dj_quickstart_h1_prewishes": "पूर्व-अनुरोध",
        "dj_quickstart_p_prewishes": (
            "पार्टी बनाते या संपादित करते समय, यदि शुरुआत अभी भी 6 घंटे से अधिक भविष्य में है तो पूर्व-अनुरोध सक्षम कर सकते हैं। "
            "अतिथि शुरू होने से पहले गाने सुझा सकते हैं। असीमित या प्रति अतिथि सीमा आप तय करते हैं।"
        ),
        "dj_quickstart_h1_grace": "अतिरिक्त समय",
        "dj_quickstart_p_grace": (
            "यदि पार्टी आधिकारिक रूप से समाप्त हो गई लेकिन स्थल पर जारी है, तो सेटिंग में 0–120 मिनट का अतिरिक्त समय सेट कर सकते हैं। "
            "तब तक VibesBox DJ के रूप में आपके लिए खुली रहती है – ब्लॉक किए गए और इतिहास सहित।"
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "जब एक DJ दूसरे DJ को VibesBox के लिए आमंत्रित करता है, आमंत्रित को 2 दिनों के बजाय 7 दिन Pro मिलता है। "
            "जब आमंत्रित पहली बार Pro खरीदता है, आमंत्रक को 14 दिन मुफ्त Pro मिलता है। "
            "दिन जमा करके जब चाहें उपयोग कर सकते हैं – सक्रिय Pro सदस्यता समाप्त करके। "
            "क्रेडिट आमंत्रित की सदस्यता शुरू होने के 30 दिन बाद मिलता है।"
        ),
        "dj_quickstart_h1_permissions": "अनुमतियाँ",
        "dj_quickstart_p_permissions": (
            "स्थिर पहचान और अलर्ट के लिए: माइक्रोफ़ोन एक्सेस की अनुमति दें। "
            "सिस्टम सेटिंग में ऐप की बैटरी अनुकूलन को कम करें या ऐप को छूट दें।"
        ),
    },
    "vi": {
        "dj_quickstart_p_vibesbox": (
            "Trong VibesBox bạn xử lý mọi yêu cầu đến. Yêu cầu thường ở mục Mở. Yêu cầu trước – nếu bật – có thể ở tab thứ tư.\n\n"
            "Có thể đánh dấu đã phát, từ chối hoặc xóa; xóa sẽ gỡ hoàn toàn khỏi cơ sở dữ liệu. Đánh dấu quan trọng bằng trái tim.\n\n"
            "Mọi yêu cầu có thể sắp xếp lại bằng kéo thả. Có thể neo tối đa ba bài – luôn ở đầu danh sách.\n\n"
            "Có thể chặn khách bằng dấu vân tay thiết bị – không độc nhất 100%; hiếm khi nhiều khách có thể bị chặn cùng lúc."
        ),
        "dj_quickstart_h1_prewishes": "Yêu cầu trước",
        "dj_quickstart_p_prewishes": (
            "Khi tạo hoặc sửa tiệc, bạn có thể bật yêu cầu trước nếu giờ bắt đầu còn hơn 6 giờ nữa. "
            "Khách có thể đề xuất bài trước khi tiệc bắt đầu. Bạn chọn không giới hạn hoặc giới hạn theo khách."
        ),
        "dj_quickstart_h1_grace": "Thời gian gia hạn",
        "dj_quickstart_p_grace": (
            "Nếu tiệc đã kết thúc chính thức nhưng vẫn tiếp tục tại chỗ, bạn có thể đặt thời gian gia hạn trong Cài đặt – từ 0 đến 120 phút. "
            "Trong thời gian đó VibesBox vẫn mở cho bạn là DJ – gồm Khách bị chặn và Lịch sử."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Khi một DJ giới thiệu DJ khác dùng VibesBox, người được giới thiệu nhận 7 ngày Pro dùng thử – thay vì 2 ngày. "
            "Người giới thiệu nhận 14 ngày Pro miễn phí khi người được giới thiệu mua Pro lần đầu. "
            "Có thể tích lũy và đổi khi muốn bằng cách kết thúc gói Pro đang hoạt động. "
            "Tín dụng được cấp sau 30 ngày kể từ khi gói của người được giới thiệu bắt đầu."
        ),
        "dj_quickstart_h1_permissions": "Quyền truy cập",
        "dj_quickstart_p_permissions": (
            "Để nhận diện và cảnh báo ổn định: cho phép truy cập micro. "
            "Trong cài đặt hệ thống, nới lỏng tối ưu pin cho ứng dụng hoặc loại trừ ứng dụng."
        ),
    },
    "sq": {
        "dj_quickstart_p_vibesbox": (
            "Në VibesBox menaxhon të gjitha kërkesat hyrëse. Ato të rregullta shkojnë te Hapur. Parakërkesat – nëse aktivizohen – mund të jenë në skedën e katërt.\n\n"
            "Mund t'i shënosh si luajtur, refuzuar ose fshirë; fshirja i heq plotësisht nga baza. Të rëndësishmet me zemër si të preferuara.\n\n"
            "Të gjitha kërkesat mund të rirenditen duke zvarritur. Mund të ankorosh deri në tre këngë – mbeten gjithmonë në krye të listës.\n\n"
            "Mund të bllokosh mysafir me gjurmë dixhitale të pajisjes – jo 100% unike; rrallë mund të duken bllokuar disa së bashku."
        ),
        "dj_quickstart_h1_prewishes": "Parakërkesa",
        "dj_quickstart_p_prewishes": (
            "Kur krijon ose redakton një festë, mund të aktivizosh parakërkesat nëse fillimi është ende më shumë se 6 orë në të ardhmen. "
            "Mysafirët mund të sugjerojnë këngë para fillimit. Ti vendos nëse janë të pakufizuara ose të kufizuara për mysafir."
        ),
        "dj_quickstart_h1_grace": "Kohë shtesë",
        "dj_quickstart_p_grace": (
            "Nëse festa ka përfunduar zyrtarisht por vazhdon në vend, mund të caktosh kohë shtesë te Cilësimet – 0 deri në 120 minuta. "
            "Gjatë kësaj kohe VibesBox mbetet e hapur për ty si DJ – përfshirë të bllokuarit dhe Historinë."
        ),
        "dj_quickstart_h1_b2b": "DJ B2B",
        "dj_quickstart_p_b2b": (
            "Kur një DJ fton një DJ tjetër në VibesBox, i ftuari merr 7 ditë Pro për provë – në vend të 2 ditëve. "
            "Ftesësi merr 14 ditë Pro falas kur i ftuari blen për herë të parë abonimin Pro. "
            "Ditët mund të grumbullohen dhe të përdoren kur të dojë, duke përfunduar abonimin aktiv nëse është ende Pro. "
            "Kreditimi bëhet 30 ditë pas fillimit të abonimit të të ftuarit."
        ),
        "dj_quickstart_h1_permissions": "Lejet",
        "dj_quickstart_p_permissions": (
            "Për njohje dhe njoftime të qëndrueshme: lejo aksesin në mikrofon. "
            "Në cilësimet e sistemit, zbut optimizimin e baterisë për aplikacionin ose përjashtoje."
        ),
    },
}


def patch_arb(path: Path, updates: dict) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    for k in REMOVE_KEYS:
        data.pop(k, None)
    for k, v in updates.items():
        data[k] = v
    path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def main() -> None:
    patch_arb(L10N / "app_de.arb", DE)
    print("updated app_de.arb")

    en = TRANSLATIONS["en"]
    for arb in sorted(L10N.glob("app_*.arb")):
        code = arb.stem.replace("app_", "")
        if code == "de":
            continue
        updates = TRANSLATIONS.get(code, en).copy()
        # fallback: English for any missing key in partial locales
        for k, v in en.items():
            updates.setdefault(k, v)
        patch_arb(arb, updates)
        print(f"updated {arb.name}")


if __name__ == "__main__":
    main()
