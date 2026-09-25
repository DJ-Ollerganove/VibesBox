#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""One-off patch: dj_quickstart_* keys in all l10n/app_*.arb files."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / "l10n"

TRANSLATIONS = {
    "en": {
        "dj_quickstart_p_music": "Guests send music requests via the wish box—in the app or on the website. Per party you decide whether pre-wishes are allowed: guests can suggest tracks before the party starts. You see these pre-wishes in party management for that party until it begins and can review them there.\n\nThe party control widget links party and wish box: start, pause, or end the wish box from one place.",
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_p_vibesbox": "In the VibesBox you handle all incoming requests. Regular guest requests appear under Open. Pre-wishes—if enabled for the party—may appear in a fourth tab, Pre-wishes.\n\nYou can mark tracks as played, reject them, or delete them; deleting removes them completely from the database. Mark especially important open requests with the heart as favorites.\n\nYou can block a guest. Blocking is based on a digital fingerprint of the guest device. It is not 100% unique—in very rare cases two or more guests may appear blocked together. You can unblock guests when needed.",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_p_free_pro": "As a Free DJ you can use VibesBox—with many limitations (e.g. limited features or locked Pro features). VibesBox Pro removes these limits and unlocks the full feature set—such as favorites, advanced controls, and more DJ tools without Free limits.",
        "dj_quickstart_p_checkin": "Check-in and QR codes guide guests into your party. Choose the language for QR codes and printed or shared guest copy separately—independent of your DJ app language.",
        "dj_quickstart_p_qr": "Once you create a party, a QR code is generated for the wish box. You can save it as an image, generate a PDF (to print, save, or share), or copy the direct wish-box link including the party code to the clipboard.\n\nWhen generating a PDF or image, you can choose what appears alongside the QR code: location (only if you entered one), your login email, an alternative email you can save in your profile, and a phone number you can add in your profile.",
        "dj_quickstart_p_recognition": "Music recognition uses the Shazam interface. Incorrectly recognized titles or artists are therefore not a VibesBox error.\n\nIn Settings you can enable automatic adjustment of recognition (e.g. sensitivity, threshold)—this is optional and must be turned on by the DJ. You can also enable automatic activation of music recognition there.\n\nRecognized songs are matched in the DJ app against your open list and—if present—the pre-wish list. On a match, the request is moved automatically to Played.\n\nThis builds a history of played songs that guests can view too. The wish box checks on its own whether a track was already played or is already on the open list—even if a guest submits the same request a second time.\n\nIndicators for active recognition (e.g. in the status bar) can be toggled separately.",
        "dj_quickstart_p_i18n": "Choose the DJ app UI language via the globe icon—like all users, not in the profile. The DJ app can run in the language you prefer.\n\nGuests use the website or app in their own language; the guest interface is multilingual too, and the list of languages is constantly growing.\n\nAutomatic translation of guest greetings when another language is detected can be turned on or off in Settings—separate from QR or display language for guests.",
        "dj_quickstart_h1_home": "Home screen",
        "dj_quickstart_p_home": "Your DJ home screen is flexible: choose which widgets and tiles you want to see—so you set up your overview to match your workflow.",
        "dj_quickstart_h1_multidevice": "Multiple devices",
        "dj_quickstart_p_multidevice": "You can sign in on multiple devices at the same time with the same DJ account. However, music recognition runs on only one device per party—so scanning does not run in parallel. To switch, release the active device or take over recognition on the new device as shown in the app.",
    },
    "fr": {
        "dj_quickstart_p_music": "Les invités envoient des demandes musicales via la wishbox – dans l'app ou sur le site. Par soirée, tu décides si les pré-demandes sont autorisées : les invités peuvent proposer des titres avant le début. Tu les vois dans la gestion de la soirée jusqu'au début et peux les vérifier.\n\nLe widget de contrôle de soirée relie soirée et wishbox : démarrage, pause et fin depuis un seul endroit.",
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_p_vibesbox": "Dans la VibesBox, tu traites toutes les demandes reçues. Les demandes classiques arrivent dans Ouvert. Les pré-demandes – si activées – peuvent apparaître dans un quatrième onglet Pré-demandes.\n\nTu peux marquer comme joué, refuser ou supprimer ; la suppression efface complètement la base de données. Marque les demandes importantes avec le cœur en favoris.\n\nTu peux bloquer un invité via une empreinte numérique de l'appareil. Elle n'est pas unique à 100 % – dans de très rares cas, plusieurs invités peuvent sembler bloqués ensemble. Tu peux les débloquer si besoin.",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_p_free_pro": "En DJ Free, tu peux utiliser VibesBox – avec de nombreuses limitations (fonctions limitées ou Pro verrouillées). VibesBox Pro lève ces limites et débloque l'ensemble des fonctions – favoris, contrôles avancés et autres outils DJ sans limites Free.",
        "dj_quickstart_p_checkin": "Check-in et codes QR guident les invités vers ta soirée. La langue des QR et textes invités imprimés ou partagés se choisit séparément – indépendamment de la langue de l'app DJ.",
        "dj_quickstart_p_qr": "Dès qu'une soirée est créée, un QR code est généré pour la wishbox. Tu peux l'enregistrer en image, créer un PDF (imprimer, enregistrer, partager) ou copier le lien direct avec le code soirée.\n\nPour PDF ou image, tu choisis ce qui s'affiche avec le QR : lieu (si renseigné), e-mail de connexion, e-mail alternatif et numéro de téléphone du profil.",
        "dj_quickstart_p_recognition": "La reconnaissance musicale utilise l'interface Shazam. Les titres ou artistes mal reconnus ne sont donc pas une erreur de VibesBox.\n\nDans les réglages, tu peux activer l'ajustement automatique (sensibilité, seuil) – optionnel, à activer par le DJ. Tu peux aussi activer le démarrage automatique de la reconnaissance.\n\nLes titres reconnus sont comparés à ta liste ouverte et, le cas échéant, aux pré-demandes ; en cas de correspondance, la demande passe automatiquement en Joué.\n\nCela crée un historique des titres joués, visible aussi par les invités. La wishbox vérifie elle-même si un titre a déjà été joué ou est déjà ouvert – même si un invité renvoie la même demande.\n\nL'indicateur de reconnaissance active (ex. barre d'état) est réglable séparément.",
        "dj_quickstart_p_i18n": "La langue de l'app DJ se choisit via l'icône globe – comme pour tous, pas dans le profil. L'app DJ peut être dans la langue de ton choix.\n\nLes invités utilisent site ou app dans leur langue ; l'interface invité est multilingue et la liste des langues s'agrandit continuellement.\n\nLa traduction automatique des salutations invitées se règle séparément dans les paramètres – indépendamment de la langue QR ou d'affichage invité.",
        "dj_quickstart_h1_home": "Page d'accueil",
        "dj_quickstart_p_home": "Ta page d'accueil DJ est personnalisable : choisis les widgets et tuiles à afficher – pour un aperçu adapté à ton flux de travail.",
        "dj_quickstart_h1_multidevice": "Plusieurs appareils",
        "dj_quickstart_p_multidevice": "Tu peux te connecter simultanément sur plusieurs appareils avec le même compte DJ. La reconnaissance musicale ne tourne cependant que sur un appareil par soirée. Pour changer, libère l'appareil actif ou reprends la reconnaissance sur le nouvel appareil comme indiqué.",
    },
    "es": {
        "dj_quickstart_p_music": "Los invitados envían peticiones musicales por la wishbox – en la app o en la web. Por fiesta decides si se permiten peticiones anticipadas: los invitados pueden sugerir temas antes del inicio. Las ves en la gestión de la fiesta hasta que empiece y puedes revisarlas allí.\n\nEl widget de control de fiesta une fiesta y wishbox: inicio, pausa y fin desde un solo lugar.",
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_p_vibesbox": "En la VibesBox gestionas todas las peticiones entrantes. Las peticiones normales van a Abierto. Las anticipadas – si están activadas – pueden verse en una cuarta pestaña Anticipadas.\n\nPuedes marcar como reproducido, rechazar o eliminar; al eliminar se borran por completo de la base de datos. Marca peticiones importantes con el corazón como favoritas.\n\nPuedes bloquear a un invitado mediante una huella digital del dispositivo. No es 100 % única – en casos muy raros varios invitados pueden quedar bloqueados juntos. Puedes desbloquearlos si hace falta.",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_p_free_pro": "Como DJ Free puedes usar VibesBox – con muchas limitaciones (funciones limitadas o Pro bloqueadas). VibesBox Pro elimina esos límites y desbloquea todas las funciones – favoritos, controles avanzados y más herramientas DJ sin límites Free.",
        "dj_quickstart_p_checkin": "Check-in y códigos QR guían a los invitados a tu fiesta. El idioma de QR y textos impresos o compartidos se elige por separado – independiente del idioma de la app DJ.",
        "dj_quickstart_p_qr": "Al crear una fiesta se genera un código QR para la wishbox. Puedes guardarlo como imagen, crear PDF (imprimir, guardar, compartir) o copiar el enlace directo con el código de fiesta.\n\nAl generar PDF o imagen eliges qué aparece junto al QR: ubicación (si la indicaste), email de acceso, email alternativo y teléfono del perfil.",
        "dj_quickstart_p_recognition": "El reconocimiento musical usa la interfaz Shazam. Títulos o artistas mal reconocidos no son un error de VibesBox.\n\nEn ajustes puedes activar el ajuste automático (sensibilidad, umbral) – opcional, el DJ debe activarlo. También puedes activar el inicio automático del reconocimiento.\n\nLas canciones reconocidas se comparan con tu lista abierta y, si existe, la de anticipadas; si coinciden, la petición pasa automáticamente a Reproducido.\n\nAsí se crea un historial de temas reproducidos que los invitados también ven. La wishbox comprueba por sí misma si un tema ya se reprodujo o está en la lista abierta – aunque el invitado envíe la misma petición otra vez.\n\nEl indicador de reconocimiento activo (p. ej. barra de estado) se puede activar por separado.",
        "dj_quickstart_p_i18n": "El idioma de la app DJ se elige con el icono del globo – como todos, no en el perfil. La app DJ puede estar en el idioma que prefieras.\n\nLos invitados usan web o app en su idioma; la interfaz de invitados es multilingüe y la lista de idiomas crece continuamente.\n\nLa traducción automática de saludos se configura aparte en ajustes – independiente del idioma QR o de visualización para invitados.",
        "dj_quickstart_h1_home": "Pantalla de inicio",
        "dj_quickstart_p_home": "Tu pantalla de inicio DJ es flexible: eliges qué widgets y mosaicos ver – para un resumen adaptado a tu flujo de trabajo.",
        "dj_quickstart_h1_multidevice": "Varios dispositivos",
        "dj_quickstart_p_multidevice": "Puedes iniciar sesión simultáneamente en varios dispositivos con la misma cuenta DJ. El reconocimiento musical solo funciona en un dispositivo por fiesta. Para cambiar, libera el dispositivo activo o toma el reconocimiento en el nuevo como se indica en la app.",
    },
    "it": {
        "dj_quickstart_p_music": "Gli ospiti inviano richieste musicali tramite la wishbox – nell'app o sul sito. Per ogni festa decidi se sono ammessi i pre-desideri: gli ospiti possono proporre brani prima dell'inizio. Li vedi nella gestione festa fino all'avvio e puoi controllarli lì.\n\nIl widget di controllo festa collega festa e wishbox: avvio, pausa e fine da un unico punto.",
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_p_vibesbox": "Nella VibesBox gestisci tutte le richieste in arrivo. Quelle regolari finiscono in Aperti. I pre-desideri – se attivati – possono comparire in una quarta scheda Pre-desideri.\n\nPuoi segnare come suonato, rifiutare o eliminare; l'eliminazione rimuove completamente dal database. Segna le richieste importanti con il cuore come preferiti.\n\nPuoi bloccare un ospite tramite impronta digitale del dispositivo. Non è unica al 100% – in casi rarissimi più ospiti possono risultare bloccati insieme. Puoi sbloccarli se serve.",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_p_free_pro": "Come DJ Free puoi usare VibesBox – con molte limitazioni (funzioni limitate o Pro bloccate). VibesBox Pro rimuove questi limiti e sblocca tutte le funzioni – preferiti, controlli avanzati e altri strumenti DJ senza limiti Free.",
        "dj_quickstart_p_checkin": "Check-in e codici QR guidano gli ospiti alla festa. La lingua per QR e testi stampati o condivisi si sceglie separatamente – indipendentemente dalla lingua dell'app DJ.",
        "dj_quickstart_p_qr": "Creata una festa, viene generato un QR per la wishbox. Puoi salvarlo come immagine, creare PDF (stampa, salvataggio, condivisione) o copiare il link diretto con codice festa.\n\nPer PDF o immagine scegli cosa mostrare oltre al QR: location (se indicata), email di accesso, email alternativa e telefono dal profilo.",
        "dj_quickstart_p_recognition": "Il riconoscimento musicale usa l'interfaccia Shazam. Titoli o artisti riconosciuti male non sono un errore di VibesBox.\n\nNelle impostazioni puoi attivare l'adattamento automatico (sensibilità, soglia) – opzionale, da attivare dal DJ. Puoi anche attivare l'avvio automatico del riconoscimento.\n\nI brani riconosciuti vengono confrontati con la lista aperta e, se presente, quella pre-desideri; in caso di corrispondenza la richiesta passa automaticamente a Suonato.\n\nSi crea una cronologia dei brani suonati visibile anche agli ospiti. La wishbox verifica da sola se un brano è già stato suonato o è già in lista aperta – anche se l'ospite invia di nuovo la stessa richiesta.\n\nL'indicatore di riconoscimento attivo (es. barra di stato) è attivabile separatamente.",
        "dj_quickstart_p_i18n": "La lingua dell'app DJ si sceglie con l'icona del globo – come tutti, non nel profilo. L'app DJ può essere nella lingua che preferisci.\n\nGli ospiti usano sito o app nella propria lingua; l'interfaccia ospiti è multilingue e l'elenco delle lingue cresce continuamente.\n\nLa traduzione automatica dei saluti si regola separatamente nelle impostazioni – indipendentemente dalla lingua QR o di visualizzazione per gli ospiti.",
        "dj_quickstart_h1_home": "Schermata iniziale",
        "dj_quickstart_p_home": "La schermata iniziale DJ è flessibile: scegli quali widget e riquadri vedere – per una panoramica adatta al tuo flusso di lavoro.",
        "dj_quickstart_h1_multidevice": "Più dispositivi",
        "dj_quickstart_p_multidevice": "Puoi accedere contemporaneamente su più dispositivi con lo stesso account DJ. Il riconoscimento musicale però gira su un solo dispositivo per festa. Per cambiare, libera il dispositivo attivo o riprendi il riconoscimento sul nuovo come indicato nell'app.",
    },
    "pt": {
        "dj_quickstart_p_music": "Os convidados enviam pedidos musicais pela wishbox – na app ou no site. Por festa defines se pedidos antecipados são permitidos: os convidados podem sugerir músicas antes do início. Vês-os na gestão da festa até começar e podes revê-los aí.\n\nO widget de controlo da festa liga festa e wishbox: início, pausa e fim num só lugar.",
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_p_vibesbox": "Na VibesBox tratas todos os pedidos recebidos. Os pedidos normais vão para Abertos. Pedidos antecipados – se ativados – podem aparecer num quarto separador Antecipados.\n\nPodes marcar como tocado, rejeitar ou apagar; ao apagar removem-se completamente da base de dados. Marca pedidos importantes com o coração como favoritos.\n\nPodes bloquear um convidado com impressão digital do dispositivo. Não é 100% única – em casos muito raros vários convidados podem ficar bloqueados juntos. Podes desbloquear se necessário.",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_p_free_pro": "Como DJ Free podes usar a VibesBox – com muitas limitações (funções limitadas ou Pro bloqueadas). A VibesBox Pro remove esses limites e desbloqueia todas as funções – favoritos, controlos avançados e mais ferramentas DJ sem limites Free.",
        "dj_quickstart_p_checkin": "Check-in e códigos QR guiam os convidados à tua festa. A língua dos QR e textos impressos ou partilhados escolhe-se separadamente – independente da língua da app DJ.",
        "dj_quickstart_p_qr": "Ao criar uma festa, gera-se um QR para a wishbox. Podes guardá-lo como imagem, criar PDF (imprimir, guardar, partilhar) ou copiar o link direto com código da festa.\n\nAo gerar PDF ou imagem escolhes o que aparece junto ao QR: local (se indicado), email de login, email alternativo e telefone do perfil.",
        "dj_quickstart_p_recognition": "O reconhecimento musical usa a interface Shazam. Títulos ou artistas mal reconhecidos não são um erro da VibesBox.\n\nNas definições podes ativar o ajuste automático (sensibilidade, limiar) – opcional, o DJ deve ativá-lo. Também podes ativar o arranque automático do reconhecimento.\n\nAs músicas reconhecidas são comparadas com a lista aberta e, se existir, a de antecipados; em caso de correspondência o pedido passa automaticamente para Tocado.\n\nCria-se um histórico de músicas tocadas que os convidados também veem. A wishbox verifica por si se uma música já foi tocada ou está na lista aberta – mesmo que o convidado envie o mesmo pedido outra vez.\n\nO indicador de reconhecimento ativo (ex. barra de estado) pode ser ligado separadamente.",
        "dj_quickstart_p_i18n": "A língua da app DJ escolhe-se pelo ícone do globo – como todos, não no perfil. A app DJ pode estar na língua que preferires.\n\nOs convidados usam site ou app na sua língua; a interface de convidados é multilingue e a lista de línguas cresce continuamente.\n\nA tradução automática de saudações regula-se separadamente nas definições – independente da língua QR ou de exibição para convidados.",
        "dj_quickstart_h1_home": "Página inicial",
        "dj_quickstart_p_home": "A tua página inicial DJ é flexível: escolhes que widgets e mosaicos ver – para uma visão geral adaptada ao teu fluxo de trabalho.",
        "dj_quickstart_h1_multidevice": "Vários dispositivos",
        "dj_quickstart_p_multidevice": "Podes iniciar sessão em vários dispositivos ao mesmo tempo com a mesma conta DJ. O reconhecimento musical só corre num dispositivo por festa. Para mudar, liberta o dispositivo ativo ou assume o reconhecimento no novo como indicado na app.",
    },
    "ru": {
        "dj_quickstart_p_music": "Гости отправляют музыкальные пожелания через вишбокс — в приложении или на сайте. Для каждой вечеринки вы решаете, разрешены ли предварительные пожелания: гости могут предлагать треки до начала. Вы видите их в управлении вечеринкой до старта и можете проверить там.\n\nВиджет управления вечеринкой связывает вечеринку и вишбокс: запуск, пауза и окончание в одном месте.",
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_p_vibesbox": "В VibesBox вы обрабатываете все входящие пожелания. Обычные попадают в «Открытые». Предварительные — при включении — могут быть во вкладке «Предварительные».\n\nМожно отметить как сыгранное, отклонить или удалить; при удалении запись полностью удаляется из базы. Важные открытые отмечайте сердцем как избранные.\n\nМожно заблокировать гостя по цифровому отпечатку устройства. Он не уникален на 100% — в редких случаях могут быть заблокированы несколько гостей. Их можно разблокировать.",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_p_free_pro": "Как DJ Free вы можете пользоваться VibesBox — с множеством ограничений (ограниченные функции или заблокированные Pro). VibesBox Pro снимает лимиты и открывает полный функционал — избранное, расширенное управление и другие инструменты DJ без ограничений Free.",
        "dj_quickstart_p_checkin": "Чек-ин и QR-коды ведут гостей на вечеринку. Язык QR и печатных или общих текстов выбирается отдельно — независимо от языка DJ-приложения.",
        "dj_quickstart_p_qr": "При создании вечеринки генерируется QR для вишбокса. Можно сохранить как изображение, создать PDF или скопировать прямую ссылку с кодом вечеринки.\n\nПри PDF или изображении выбираете, что показывать рядом с QR: локацию, email входа, альтернативный email и телефон из профиля.",
        "dj_quickstart_p_recognition": "Распознавание музыки использует интерфейс Shazam. Неверно распознанные треки или исполнители — не ошибка VibesBox.\n\nВ настройках можно включить автоматическую подстройку (чувствительность, порог) — опционально, DJ должен включить сам. Также можно включить автозапуск распознавания.\n\nРаспознанные песни сравниваются с открытым списком и при наличии — с предварительными; при совпадении пожелание автоматически переходит в «Сыграно».\n\nСоздаётся история сыгранных треков, видимая гостям. Вишбокс сам проверяет, был ли трек уже сыгран или есть в открытом списке — даже при повторной отправке.\n\nИндикатор активного распознавания (например, в строке состояния) настраивается отдельно.",
        "dj_quickstart_p_i18n": "Язык DJ-приложения выбирается через иконку глобуса — как у всех, не в профиле. Приложение может быть на выбранном вами языке.\n\nГости используют сайт или приложение на своём языке; интерфейс гостя многоязычен, список языков постоянно расширяется.\n\nАвтоперевод приветствий гостей настраивается отдельно — независимо от языка QR или отображения для гостей.",
        "dj_quickstart_h1_home": "Главный экран",
        "dj_quickstart_p_home": "Главный экран DJ настраивается: вы выбираете виджеты и плитки — обзор под ваш рабочий процесс.",
        "dj_quickstart_h1_multidevice": "Несколько устройств",
        "dj_quickstart_p_multidevice": "Можно войти одновременно на нескольких устройствах с одним DJ-аккаунтом. Распознавание музыки работает только на одном устройстве за вечеринку. Для смены освободите активное устройство или возьмите распознавание на новое, как показано в приложении.",
    },
    "uk": {
        "dj_quickstart_p_music": "Гості надсилають музичні побажання через вішбокс — у застосунку або на сайті. Для кожної вечірки ви вирішуєте, чи дозволені попередні побажання: гості можуть пропонувати треки до початку. Ви бачите їх у керуванні вечіркою до старту.\n\nВіджет керування вечіркою пов’язує вечірку та вішбокс: старт, пауза та завершення в одному місці.",
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_p_vibesbox": "У VibesBox ви обробляєте всі вхідні побажання. Звичайні — у «Відкриті». Попередні — за наявності — у вкладці «Попередні».\n\nМожна позначити як зігране, відхилити або видалити; видалення повністю прибирає з бази. Важливі відкриті позначайте серцем.\n\nМожна заблокувати гостя за цифровим відбитком пристрою — не на 100% унікальним; у рідкісних випадках кілька гостей можуть бути заблоковані разом. Можна розблокувати.",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_p_free_pro": "Як DJ Free ви можете користуватися VibesBox — з багатьма обмеженнями. VibesBox Pro знімає ліміти та відкриває повний функціонал — обране, розширене керування та інші інструменти DJ.",
        "dj_quickstart_p_checkin": "Чек-ін і QR-коди ведуть гостей на вечірку. Мову QR і друкованих текстів обирають окремо — незалежно від мови DJ-застосунку.",
        "dj_quickstart_p_qr": "Після створення вечірки генерується QR для вішбокса. Можна зберегти як зображення, PDF або скопіювати посилання з кодом.\n\nДля PDF або зображення обираєте, що показувати поруч із QR: локацію, email, альтернативний email і телефон з профілю.",
        "dj_quickstart_p_recognition": "Розпізнавання музики використовує інтерфейс Shazam. Помилково розпізнані треки — не помилка VibesBox.\n\nУ налаштуваннях можна увімкнути автопідлаштування — опціонально, DJ увімкне сам. Також автозапуск розпізнавання.\n\nРозпізнані пісні порівнюються з відкритим і попереднім списками; при збігу — автоматично в «Зіграно».\n\nСтворюється історія зіграних треків для гостей. Вішбокс сам перевіряє, чи трек уже зіграний або у відкритому списку — навіть при повторній відправці.\n\nІндикатор активного розпізнавання налаштовується окремо.",
        "dj_quickstart_p_i18n": "Мову DJ-застосунку обирають через іконку глобуса — не в профілі. Гості користуються сайтом або застосунком своєю мовою; список мов постійно розширюється.\n\nАвтопереклад привітань гостей — окремо в налаштуваннях.",
        "dj_quickstart_h1_home": "Головний екран",
        "dj_quickstart_p_home": "Головний екран DJ гнучкий: обираєте віджети та плитки під свій робочий процес.",
        "dj_quickstart_h1_multidevice": "Кілька пристроїв",
        "dj_quickstart_p_multidevice": "Можна увійти одночасно на кількох пристроях. Розпізнавання музики лише на одному пристрої за вечірку. Для зміни звільніть активний пристрій або перейміть розпізнавання на новий.",
    },
    "tr": {
        "dj_quickstart_p_music": "Misafirler müzik isteklerini wishbox üzerinden gönderir – uygulamada veya sitede. Parti başına ön isteklere izin verip vermeyeceğinize siz karar verirsiniz. Başlangıca kadar parti yönetiminde görür ve kontrol edersiniz.\n\nParti kontrol widget'ı parti ile wishbox'ı birleştirir: tek yerden başlatma, duraklatma ve bitirme.",
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_p_vibesbox": "VibesBox'ta tüm gelen istekleri yönetirsiniz. Normal istekler Açık'ta. Ön istekler – etkinse – dördüncü sekmede olabilir.\n\nÇalındı, reddedildi veya silindi işaretlenebilir; silme veritabanından tamamen kaldırır. Önemli açık istekleri kalp ile favori yapın.\n\nMisafiri cihaz parmak iziyle engelleyebilirsiniz – %100 benzersiz değildir; nadir durumlarda birden fazla misafir engellenmiş görünebilir. Gerekirse engeli kaldırabilirsiniz.",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_p_free_pro": "Free DJ olarak VibesBox kullanabilirsiniz – birçok kısıtlamayla. VibesBox Pro limitleri kaldırır ve tam özellik setini açar – favoriler, gelişmiş kontroller ve daha fazlası.",
        "dj_quickstart_p_checkin": "Check-in ve QR kodları misafirleri partiye yönlendirir. QR ve basılı metin dili DJ uygulama dilinden bağımsız seçilir.",
        "dj_quickstart_p_qr": "Parti oluşturulunca wishbox için QR üretilir. Görsel, PDF veya doğrudan bağlantı kopyalanabilir.\n\nPDF veya görselde QR yanında ne gösterileceğini seçersiniz: konum, giriş e-postası, alternatif e-posta ve profil telefonu.",
        "dj_quickstart_p_recognition": "Müzik tanıma Shazam arayüzünü kullanır. Yanlış tanınan parçalar VibesBox hatası değildir.\n\nAyarlarda otomatik uyarlama (hassasiyet, eşik) isteğe bağlı açılabilir – DJ etkinleştirmelidir. Otomatik başlatma da ayarlanabilir.\n\nTanınan şarkılar açık ve varsa ön istek listesiyle karşılaştırılır; eşleşmede otomatik Çalındı'ya gider.\n\nÇalınan şarkı geçmişi misafirlerce de görülür. Wishbox, parçanın çalınıp çalınmadığını veya açık listede olup olmadığını kendisi kontrol eder – misafir aynı isteği tekrar gönderse bile.\n\nAktif tanıma göstergesi ayrı açılıp kapatılabilir.",
        "dj_quickstart_p_i18n": "DJ uygulama dili küre simgesiyle seçilir – profilde değil. Misafirler site veya uygulamayı kendi dillerinde kullanır; dil listesi sürekli genişler.\n\nMisafir selamlarının otomatik çevirisi ayarlarda ayrı yapılır.",
        "dj_quickstart_h1_home": "Ana sayfa",
        "dj_quickstart_p_home": "DJ ana sayfanız esnektir: hangi widget ve kutucukları göreceğinizi seçersiniz.",
        "dj_quickstart_h1_multidevice": "Birden fazla cihaz",
        "dj_quickstart_p_multidevice": "Aynı DJ hesabıyla birden fazla cihazda aynı anda oturum açabilirsiniz. Müzik tanıma parti başına yalnızca bir cihazda çalışır. Değiştirmek için aktif cihazı serbest bırakın veya uygulamada gösterildiği gibi devralın.",
    },
    "ar": {
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_h1_free_pro": "VibesBox Free مقابل VibesBox Pro",
        "dj_quickstart_h1_home": "الشاشة الرئيسية",
        "dj_quickstart_h1_multidevice": "أجهزة متعددة",
    },
    "zh": {
        "dj_quickstart_p_music": "客人通过许愿箱发送点歌请求——在应用或网站上。每场派对你可决定是否允许预许愿：客人可在派对开始前推荐曲目。你在派对管理中看到并审核它们，直到派对开始。\n\n派对控制小组件将派对与许愿箱连接：在一处启动、暂停和结束许愿箱。",
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_p_vibesbox": "在 VibesBox 中处理所有收到的请求。常规请求在「待处理」。若启用预许愿，可能在第四栏「预许愿」中。\n\n可标记为已播放、拒绝或删除；删除会从数据库完全移除。用爱心将重要待处理请求标为收藏。\n\n可封锁客人，基于设备数字指纹，并非 100% 唯一；极少数情况下可能多人同时被封锁。可解除封锁。",
        "dj_quickstart_h1_free_pro": "VibesBox Free 与 VibesBox Pro",
        "dj_quickstart_p_free_pro": "作为 Free DJ 可使用 VibesBox，但有许多限制（功能受限或 Pro 功能锁定）。VibesBox Pro 解除限制并解锁完整功能——如收藏、高级控制等，无 Free 限制。",
        "dj_quickstart_p_checkin": "签到和二维码引导客人进入派对。二维码和印刷/分享文案的语言可单独选择——与 DJ 应用语言无关。",
        "dj_quickstart_p_qr": "创建派对后会生成许愿箱二维码。可保存为图片、生成 PDF 或复制含派对代码的直链。\n\n生成 PDF 或图片时可选择 QR 旁显示的内容：地点、登录邮箱、备用邮箱及资料中的电话。",
        "dj_quickstart_p_recognition": "音乐识别使用 Shazam 接口，识别错误并非 VibesBox 的过错。\n\n可在设置中启用自动调整（灵敏度、阈值）——可选，需 DJ 开启。也可启用自动启动识别。\n\n识别歌曲会与待处理列表及预许愿列表比对；匹配时自动移至「已播放」。\n\n形成已播放歌曲历史，客人也可查看。许愿箱自行检查曲目是否已播放或已在待处理列表——即使客人再次发送相同请求。\n\n活跃识别指示（如状态栏）可单独开关。",
        "dj_quickstart_p_i18n": "DJ 应用语言通过地球图标选择——与所有用户一样，不在个人资料中。客人以各自语言使用网站或应用；客人界面多语言，语言列表持续扩展。\n\n客人问候语自动翻译可在设置中单独开关——与客人 QR/显示语言无关。",
        "dj_quickstart_h1_home": "主屏幕",
        "dj_quickstart_p_home": "DJ 主屏幕可灵活定制：选择要显示的组件和磁贴，按工作流程安排概览。",
        "dj_quickstart_h1_multidevice": "多设备",
        "dj_quickstart_p_multidevice": "可用同一 DJ 账号同时在多台设备登录。音乐识别每场派对仅在一台设备运行。切换时请按应用提示释放当前设备或在新设备接管。",
    },
    "ja": {
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_h1_free_pro": "VibesBox Free と VibesBox Pro",
        "dj_quickstart_h1_home": "ホーム画面",
        "dj_quickstart_h1_multidevice": "複数デバイス",
    },
    "nl": {
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_h1_home": "Startscherm",
        "dj_quickstart_h1_multidevice": "Meerdere apparaten",
    },
    "pl": {
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_h1_home": "Ekran główny",
        "dj_quickstart_h1_multidevice": "Wiele urządzeń",
    },
    "cs": {
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_h1_home": "Domovská obrazovka",
        "dj_quickstart_h1_multidevice": "Více zařízení",
    },
    "el": {
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_h1_home": "Αρχική οθόνη",
        "dj_quickstart_h1_multidevice": "Πολλές συσκευές",
    },
    "hi": {
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_h1_free_pro": "VibesBox Free बनाम VibesBox Pro",
        "dj_quickstart_h1_home": "होम स्क्रीन",
        "dj_quickstart_h1_multidevice": "कई डिवाइस",
    },
    "vi": {
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_h1_home": "Màn hình chính",
        "dj_quickstart_h1_multidevice": "Nhiều thiết bị",
    },
    "sq": {
        "dj_quickstart_h1_vibesbox": "VibesBox",
        "dj_quickstart_h1_free_pro": "VibesBox Free vs. VibesBox Pro",
        "dj_quickstart_h1_home": "Faqja kryesore",
        "dj_quickstart_h1_multidevice": "Disa pajisje",
    },
}


def patch_file(path: Path, updates: dict):
    data = json.loads(path.read_text(encoding="utf-8"))
    for k, v in updates.items():
        data[k] = v
    path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")

def main():
    en = TRANSLATIONS.get("en", {})
    for arb in sorted(L10N.glob("app_*.arb")):
        code = arb.stem.replace("app_", "")
        if code == "de":
            continue
        updates = dict(TRANSLATIONS.get(code, {}))
        for k, v in en.items():
            updates.setdefault(k, v)
        if updates:
            patch_file(arb, updates)
            print(f"Patched {arb.name}")

if __name__ == "__main__":
    main()
