const STRINGS = {
  ru: {
    tagline:'БОЛЬШОЙ ЧЕЛОВЕК. БОЛЬШИЕ ПРОБЛЕМЫ.', chapter:'ГЛАВА', titleSub:'СУДНЫЙ ДЕНЬ', start:'Начать кампанию', continue:'Продолжить', showroom:'Персонажи', help:'Управление', settings:'Настройки', menu:'Главное меню', back:'Назад', close:'Закрыть', restart:'Начать заново', retry:'Повторить главу', next:'Следующая глава', paused:'Пауза', pausedSub:'Дай миру немного подождать.', defeat:'Ещё один раунд?', defeatSub:'Натан упал. Но это ещё не конец.', victory:'Судный день окончен', victorySub:'Город пройден. Лес позади. Оз повержен.', levelcomplete:'Путь открыт', levelcompleteSub:'Переведи дыхание. Дальше будет жарче.', city:'Город', forest:'Лес', factory:'Завод', cityDesc:'Ночь начинается на улицах.', forestDesc:'Короткий путь редко бывает лёгким.', factoryDesc:'Последняя смена Оза.', campaign:'КАМПАНИЯ / 3 ГЛАВЫ', fists:'ТЯЖЁЛЫЕ УДАРЫ', parkourTag:'СВОБОДНОЕ ДВИЖЕНИЕ', allIn:'ОКРУЖЕНИЕ В ДЕЛЕ', nathan:'Натан', oz:'Оз', nathanDescription:'195 см · 140 кг · непростой характер', ozDescription:'Один на один. Без лишних слов.', modelNote:'Стилизованные 3D-модели · обзор со всех сторон', rotate:'Потяни для вращения', pose:'Сменить анимацию', health:'Здоровье', rage:'Ярость', enemies:'Противники', kills:'Побеждено', combo:'СЕРИЯ', objective:'ЗАДАЧА', clear:'Разберись с противниками', route:'Пройди маршрут паркура', exit:'Доберись до выхода', boss:'Победи Оза', explore:'Осмотрись и найди путь вперёд', punch:'Рука', kick:'Нога', throw:'Бросок', dodge:'Рывок', crouch:'Присесть', jump:'Прыгнуть', parkour:'Паркур', vault:'Перелезть', climb:'Подняться', hang:'Схватиться', shimmy:'Вдоль края', drop:'Отпустить', interact:'Предмет', pick:'Поднять', push:'Толкнуть', smash:'Разбить', bag:'Сумка', bagTitle:'В карманах', v20:'Виванс 20', v30:'Виванс 30', weed:'Шмаль', ozempic:'Оземпик', shawarma:'Шаурма', v20Desc:'+20 к силе · 120 с', v30Desc:'+30 к силе · 120 с', weedDesc:'Враги ×0,42 · урон ×1,25 · 120 с', ozempicDesc:'Скорость ×1,7 · 120 с', shawarmaDesc:'До +45 здоровья', fictional:'Предметы и их эффекты — вымышленные аркадные механики.', empty:'Нет в сумке', used:'Предмет использован', fullHealth:'Здоровье уже полное', rageReady:'Ярость готова', rageNeed:'Накопи ярость в бою', noTarget:'Подойди ближе к противнику', noItem:'Рядом нет предмета', blocked:'Здесь нет свободного места', levelLocked:'Сначала закончи бой и маршрут', objectiveJump:'Прыгни через отметку', objectiveVault:'Перелезь через низкую преграду', objectiveHang:'Повисни на краю и подтянись', objectiveClimb:'Поднимись на площадку', routeComplete:'Маршрут пройден', checkpoint:'Контрольная точка', fight:'В БОЙ', move:'Движение', look:'Обзор', useItem:'Предметы 1–5', pause:'Пауза', desktop:'КЛАВИАТУРА И МЫШЬ', mobile:'НА ТЕЛЕФОНЕ', movementHelp:'WASD / стрелки — движение относительно камеры. Потяни мышью по сцене — обзор.', combatHelp:'J — рука · K — нога · L — захват и бросок. Shift — рывок, C — присесть, R — ярость.', parkourHelp:'Пробел — прыжок или доступное действие паркура. На краю: влево/вправо — перемещение; вперёд + Пробел — подъём; назад + Пробел — отпускание.', itemsHelp:'E — взаимодействие с окружением. B — сумка, 1–5 — предметы. Esc — пауза.', touchHelp:'Слева — плавающий джойстик. Справа — удары и рывок. Потяни по свободной правой области, чтобы осмотреться. Движение и атака работают одновременно.', tacticsHelp:'Читай замахи, уходи рывком и отвечай в паузах. Бросай врагов друг в друга и в предметы. Светящиеся отметки ведут к следующей опоре.', sound:'Звук', reducedMotion:'Меньше движения', touchControls:'Сенсорные кнопки', auto:'Авто', on:'Вкл.', off:'Выкл.', quality:'Качество', qualityAuto:'Адаптивное', qualityHigh:'Высокое', qualityLow:'Экономное', language:'Язык', install:'Установить игру', installIOS:'iPhone: «Поделиться» → «На экран Домой». Запускай с иконки для игры без панелей браузера.', installOther:'Установи игру через меню браузера, чтобы запускать её с домашнего экрана.', offline:'Офлайн-версия готова', loading:'Загрузка сцены…', rotateTitle:'Поверни телефон', rotateSub:'Натану нужно больше места.', rotateHint:'Игра продолжится после поворота.', seconds:'с', available:'ДОСТУПНО', model:'МОДЕЛЬ', metrics:'Производительность', newGame:'НОВАЯ ИГРА', chapterReady:'ГЛАВА ЗАВЕРШЕНА', campaignComplete:'КАМПАНИЯ ЗАВЕРШЕНА', retryHint:'Начать текущую главу снова', fullScreen:'Полный экран', offlinePending:'Для офлайн-игры дождись первой полной загрузки.', pauseBlur:'Игра на паузе после смены окна.', version:'NATHAN 2 · 3D ACTION', exitShowroom:'В главное меню', previewIdle:'Стойка', previewRun:'Бег', previewPunch:'Удар рукой', previewKick:'Удар ногой', previewHang:'Вис', previewVictory:'Победа'
  },
  en: {
    tagline:'BIG MAN. BIGGER PROBLEMS.', chapter:'CHAPTER', titleSub:'JUDGMENT DAY', start:'Start campaign', continue:'Continue', showroom:'Characters', help:'Controls', settings:'Settings', menu:'Main menu', back:'Back', close:'Close', restart:'Start over', retry:'Retry chapter', next:'Next chapter', paused:'Paused', pausedSub:'Let the world wait a little.', defeat:'One more round?', defeatSub:'Nathan is down. This is not the end.', victory:'Judgment delivered', victorySub:'The city is clear. The forest is behind you. Oz is defeated.', levelcomplete:'The way is clear', levelcompleteSub:'Catch your breath. It gets hotter from here.', city:'City', forest:'Forest', factory:'Factory', cityDesc:'The night begins in the streets.', forestDesc:'A shortcut is rarely an easy road.', factoryDesc:'Oz’s final shift.', campaign:'CAMPAIGN / 3 CHAPTERS', fists:'HEAVY HITS', parkourTag:'FREE MOVEMENT', allIn:'USE THE WORLD', nathan:'Nathan', oz:'Oz', nathanDescription:'195 cm · 140 kg · a difficult character', ozDescription:'Face to face. No more words.', modelNote:'Stylized 3D models · a view from every side', rotate:'Drag to rotate', pose:'Change animation', health:'Health', rage:'Rage', enemies:'Enemies', kills:'Defeated', combo:'COMBO', objective:'OBJECTIVE', clear:'Defeat the enemies', route:'Complete the parkour route', exit:'Reach the exit', boss:'Defeat Oz', explore:'Look around and find your way forward', punch:'Punch', kick:'Kick', throw:'Throw', dodge:'Dash', crouch:'Crouch', jump:'Jump', parkour:'Parkour', vault:'Vault', climb:'Climb', hang:'Grab ledge', shimmy:'Shimmy', drop:'Let go', interact:'Object', pick:'Pick up', push:'Push', smash:'Break', bag:'Bag', bagTitle:'In your pockets', v20:'Vyvanse 20', v30:'Vyvanse 30', weed:'Weed', ozempic:'Ozempic', shawarma:'Shawarma', v20Desc:'+20 power · 120 s', v30Desc:'+30 power · 120 s', weedDesc:'Enemies ×0.42 · damage ×1.25 · 120 s', ozempicDesc:'Speed ×1.7 · 120 s', shawarmaDesc:'Up to +45 health', fictional:'Items and their effects are fictional arcade mechanics.', empty:'Not in your bag', used:'Item used', fullHealth:'Health is already full', rageReady:'Rage is ready', rageNeed:'Build rage in combat', noTarget:'Move closer to an enemy', noItem:'No object in reach', blocked:'There is no room here', levelLocked:'Finish the fight and route first', objectiveJump:'Jump across the marker', objectiveVault:'Vault the low barrier', objectiveHang:'Hang from the edge and pull up', objectiveClimb:'Climb onto the platform', routeComplete:'Route complete', checkpoint:'Checkpoint', fight:'FIGHT', move:'Move', look:'Look', useItem:'Items 1–5', pause:'Pause', desktop:'KEYBOARD & MOUSE', mobile:'ON YOUR PHONE', movementHelp:'WASD / arrows — move relative to the camera. Drag on the scene with the mouse to look around.', combatHelp:'J — punch · K — kick · L — grab and throw. Shift — dash, C — crouch, R — rage.', parkourHelp:'Space — jump or the available parkour move. On a ledge: left/right to shimmy; forward + Space to climb; back + Space to let go.', itemsHelp:'E — interact with the environment. B — bag, 1–5 — items. Esc — pause.', touchHelp:'Floating stick on the left. Attacks and dash on the right. Drag in the free right-hand area to look around. Move and attack at the same time.', tacticsHelp:'Read windups, dash away, and strike during recovery. Throw enemies into each other and objects. Glowing markers lead to the next hold.', sound:'Sound', reducedMotion:'Reduced motion', touchControls:'Touch controls', auto:'Auto', on:'On', off:'Off', quality:'Quality', qualityAuto:'Adaptive', qualityHigh:'High', qualityLow:'Low', language:'Language', install:'Install game', installIOS:'iPhone: Share → Add to Home Screen. Launch from the icon to play without browser bars.', installOther:'Install the game from your browser menu to launch it from your home screen.', offline:'Offline version ready', loading:'Loading scene…', rotateTitle:'Turn your phone', rotateSub:'Nathan needs a little more room.', rotateHint:'The game will resume after rotation.', seconds:'s', available:'AVAILABLE', model:'MODEL', metrics:'Performance', newGame:'NEW GAME', chapterReady:'CHAPTER COMPLETE', campaignComplete:'CAMPAIGN COMPLETE', retryHint:'Restart the current chapter', fullScreen:'Full screen', offlinePending:'For offline play, let the first full download finish.', pauseBlur:'Paused after switching windows.', version:'NATHAN 2 · 3D ACTION', exitShowroom:'Back to menu', previewIdle:'Idle', previewRun:'Run', previewPunch:'Punch', previewKick:'Kick', previewHang:'Hang', previewVictory:'Victory'
  },
  he: {
    tagline:'איש גדול. צרות גדולות יותר.', chapter:'פרק', titleSub:'יום הדין', start:'התחלת מסע', continue:'להמשיך', showroom:'דמויות', help:'שליטה', settings:'הגדרות', menu:'תפריט ראשי', back:'חזרה', close:'סגירה', restart:'להתחיל מחדש', retry:'ניסיון נוסף', next:'לפרק הבא', paused:'הפסקה', pausedSub:'העולם יכול לחכות קצת.', defeat:'עוד סיבוב?', defeatSub:'נתן נפל. זה עוד לא הסוף.', victory:'יום הדין הסתיים', victorySub:'העיר מאחוריך. היער מאחוריך. עוז הובס.', levelcomplete:'הדרך פתוחה', levelcompleteSub:'קח נשימה. מכאן רק מתחמם.', city:'עיר', forest:'יער', factory:'מפעל', cityDesc:'הלילה מתחיל ברחובות.', forestDesc:'קיצור דרך הוא לא תמיד דרך קלה.', factoryDesc:'המשמרת האחרונה של עוז.', campaign:'מסע / 3 פרקים', fists:'מכות כבדות', parkourTag:'תנועה חופשית', allIn:'הסביבה נלחמת איתך', nathan:'נתן', oz:'עוז', nathanDescription:'195 ס״מ · 140 ק״ג · אופי לא פשוט', ozDescription:'פנים מול פנים. בלי מילים מיותרות.', modelNote:'דגמי תלת־ממד מסוגננים · מבט מכל צד', rotate:'גרירה לסיבוב', pose:'החלפת הנפשה', health:'בריאות', rage:'זעם', enemies:'אויבים', kills:'הובסו', combo:'רצף', objective:'משימה', clear:'הבס את האויבים', route:'השלם את מסלול הפארקור', exit:'הגע ליציאה', boss:'הבס את עוז', explore:'הבט סביב ומצא את הדרך קדימה', punch:'אגרוף', kick:'בעיטה', throw:'הטלה', dodge:'זינוק', crouch:'כריעה', jump:'קפיצה', parkour:'פארקור', vault:'דילוג', climb:'טיפוס', hang:'אחיזה', shimmy:'לאורך הקצה', drop:'שחרור', interact:'חפץ', pick:'הרמה', push:'דחיפה', smash:'שבירה', bag:'תיק', bagTitle:'בכיסים', v20:'ויואנס 20', v30:'ויואנס 30', weed:'גראס', ozempic:'אוזמפיק', shawarma:'שווארמה', v20Desc:'+20 כוח · 120 שנ׳', v30Desc:'+30 כוח · 120 שנ׳', weedDesc:'אויבים ×0.42 · נזק ×1.25 · 120 שנ׳', ozempicDesc:'מהירות ×1.7 · 120 שנ׳', shawarmaDesc:'עד +45 בריאות', fictional:'הפריטים וההשפעות שלהם הם מכניקות ארקייד בדיוניות.', empty:'אין בתיק', used:'הפריט הופעל', fullHealth:'הבריאות כבר מלאה', rageReady:'הזעם מוכן', rageNeed:'צבור זעם בקרב', noTarget:'התקרב לאויב', noItem:'אין חפץ בטווח', blocked:'אין כאן מספיק מקום', levelLocked:'סיים קודם את הקרב ואת המסלול', objectiveJump:'קפוץ מעל הסימון', objectiveVault:'דלג מעל המחסום הנמוך', objectiveHang:'היתלה בקצה ומשוך את עצמך למעלה', objectiveClimb:'טפס אל המשטח', routeComplete:'המסלול הושלם', checkpoint:'נקודת ביקורת', fight:'לקרב', move:'תנועה', look:'מבט', useItem:'פריטים 1–5', pause:'הפסקה', desktop:'מקלדת ועכבר', mobile:'בטלפון', movementHelp:'WASD / חצים — תנועה ביחס למצלמה. גרור את העכבר על הסצנה כדי להביט סביב.', combatHelp:'J — אגרוף · K — בעיטה · L — אחיזה והטלה. Shift — זינוק, C — כריעה, R — זעם.', parkourHelp:'רווח — קפיצה או פעולת הפארקור הזמינה. בקצה: שמאלה/ימינה — תנועה; קדימה + רווח — טיפוס; אחורה + רווח — שחרור.', itemsHelp:'E — פעולה עם חפץ בסביבה. B — תיק, 1–5 — פריטים. Esc — הפסקה.', touchHelp:'ג׳ויסטיק צף משמאל. התקפות וזינוק מימין. גרור באזור הימני הפנוי כדי להביט סביב. אפשר לנוע ולהתקיף יחד.', tacticsHelp:'קרא את ההכנה למכה, התחמק והשב בזמן ההתאוששות. הטל אויבים זה על זה ועל חפצים. סימונים זוהרים מובילים לאחיזה הבאה.', sound:'צליל', reducedMotion:'תנועה מופחתת', touchControls:'כפתורי מגע', auto:'אוטומטי', on:'פעיל', off:'כבוי', quality:'איכות', qualityAuto:'מסתגלת', qualityHigh:'גבוהה', qualityLow:'חסכונית', language:'שפה', install:'התקנת המשחק', installIOS:'iPhone: שיתוף ← הוספה למסך הבית. הפעל מהסמל כדי לשחק ללא סרגלי הדפדפן.', installOther:'התקן את המשחק מתפריט הדפדפן כדי להפעיל אותו ממסך הבית.', offline:'הגרסה הלא מקוונת מוכנה', loading:'טוען סצנה…', rotateTitle:'סובב את הטלפון', rotateSub:'נתן צריך קצת יותר מקום.', rotateHint:'המשחק ימשיך אחרי הסיבוב.', seconds:'שנ׳', available:'זמין', model:'דגם', metrics:'ביצועים', newGame:'משחק חדש', chapterReady:'הפרק הושלם', campaignComplete:'המסע הושלם', retryHint:'התחלת הפרק הנוכחי מחדש', fullScreen:'מסך מלא', offlinePending:'למשחק ללא רשת, המתן לסיום ההורדה המלאה הראשונה.', pauseBlur:'המשחק הושהה לאחר מעבר חלון.', version:'NATHAN 2 · אקשן בתלת־ממד', exitShowroom:'חזרה לתפריט', previewIdle:'עמידה', previewRun:'ריצה', previewPunch:'אגרוף', previewKick:'בעיטה', previewHang:'תלייה', previewVictory:'ניצחון'
  }
};

const ITEM_IDS = ['v20', 'v30', 'weed', 'ozempic', 'shawarma'];
const ALIASES = {objective_jump:'objectiveJump',objective_vault:'objectiveVault',objective_climb:'objectiveClimb',objective_hang:'objectiveHang',objective_fight:'clear',objective_exit:'exit',needCloser:'noTarget',needRage:'rageNeed',itemEmpty:'empty',routeDone:'routeComplete',pullUp:'climb',throwItem:'throw',hit:'punch',throw:'throw'};
Object.assign(STRINGS.ru,{alreadyStrong:'Усиление уже действует',break:'Предмет разбит',environment:'Приём с окружением',fryer:'Окружение в деле!',environmentHelp:'E рядом с противником у ларька — приём с окружением; без противника — поднять предмет. △ / L — бросить противника или предмет.'});
Object.assign(STRINGS.en,{alreadyStrong:'The stronger boost is already active',break:'Object broken',environment:'Environmental slam',fryer:'Use the world!',environmentHelp:'E near an enemy at the stall — an environmental slam; without an enemy — pick up an object. △ / L — throw an enemy or held object.'});
Object.assign(STRINGS.he,{alreadyStrong:'החיזוק החזק כבר פעיל',break:'החפץ נשבר',environment:'מהלך סביבתי',fryer:'הסביבה נלחמת איתך!',environmentHelp:'E ליד אויב בדוכן — הטלה על הסביבה; בלי אויב — הרמת חפץ. △ / L — הטלת אויב או חפץ מוחזק.'});
STRINGS.ru.parkourHelp='Пробел — прыжок или доступное действие паркура. На краю: влево/вправо — перемещение, Пробел — подтянуться, E или C — отпустить. На телефоне используй отдельные контекстные кнопки.';
STRINGS.en.parkourHelp='Space — jump or the available parkour move. On a ledge: left/right to shimmy, Space to pull up, E or C to let go. On your phone, use the separate context buttons.';
STRINGS.he.parkourHelp='רווח — קפיצה או פעולת הפארקור הזמינה. בקצה: שמאלה/ימינה — תנועה, רווח — טיפוס, E או C — שחרור. בטלפון השתמש בכפתורי הפעולה הנפרדים.';
Object.assign(STRINGS.ru,{face:'Лицо',fullBody:'В полный рост',updateReady:'Новая версия готова. Обнови игру после боя.'});
Object.assign(STRINGS.en,{face:'Face',fullBody:'Full body',updateReady:'An update is ready. Reload after the fight.'});
Object.assign(STRINGS.he,{face:'פנים',fullBody:'גוף מלא',updateReady:'גרסה חדשה מוכנה. רענן אחרי הקרב.'});
const COMBAT = {punch:'□',kick:'○',throw:'△',dodge:'×'};
const MOVEMENT = new Set(['KeyW','KeyA','KeyS','KeyD','ArrowUp','ArrowLeft','ArrowDown','ArrowRight']);
const readPreference = (key, fallback) => { try { return localStorage.getItem(`nathan2:${key}`) ?? fallback; } catch { return fallback; } };
const savePreference = (key, value) => { try { localStorage.setItem(`nathan2:${key}`,value); } catch {} };

export function createUI(callbacks = {}) {
  const host = document.getElementById('ui-root');
  let lang = readPreference('lang', 'ru'); if (!STRINGS[lang]) lang = 'ru';
  let mode = 'menu', modal = null, data = {}, context = {action:'parkour',label:'jump'}, toastTimer, orientationTimer, orientationPaused = false, manualPause = false, wasPortrait = false, showroomCharacter = 'nathan';
  let deferredInstall = null, modalResume = false, buffSignature='',showroomFace=false;
  const listeners = [], keys = new Set(), pointers = new Map();
  const input = {x:0,y:0,lookX:0,lookY:0,sprint:false};
  const prefs = {sound:readPreference('sound','on'), reducedMotion:readPreference('reducedMotion',matchMedia('(prefers-reduced-motion: reduce)').matches?'on':'off'),touchControls:readPreference('touchControls','auto'),quality:readPreference('quality','auto')};
  const t = key => STRINGS[lang][ALIASES[key]||key] ?? STRINGS.en[ALIASES[key]||key] ?? key;
  const el = id => host.querySelector(`#${id}`);
  const on = (target,event,fn,options) => { target.addEventListener(event,fn,options); listeners.push(()=>target.removeEventListener(event,fn,options)); };
  const call = (name,...args) => callbacks[name]?.(...args);
  const capturePointer=(node,id)=>{try{node.setPointerCapture(id);}catch{/* A cancelled pointer still gets cleaned up by the window listeners. */}};
  const isTouch = () => prefs.touchControls === 'on' || (prefs.touchControls === 'auto' && (matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 0));
  const button = (action,label,extra='') => `<button type="button" data-ui="${action}" ${extra}>${t(label)}</button>`;
  const languages = () => `<div class="language-switch" aria-label="${t('language')}">${[['ru','RU'],['en','EN'],['he','עב']].map(([code,label])=>`<button type="button" data-lang="${code}" class="${lang===code?'active':''}" aria-pressed="${lang===code}">${label}</button>`).join('')}</div>`;
  function render() {
    buffSignature='';
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'he' ? 'rtl' : 'ltr';
    host.className = `mode-${mode}${isTouch()?' touch-enabled':''}${prefs.reducedMotion==='on'?' reduced-motion':''}`;
    host.innerHTML = `
      <div class="cinema-shade" aria-hidden="true"></div>
      <section id="menu-screen" class="screen menu-screen" ${mode==='menu'?'':'hidden'}>
        <header class="menu-header"><span class="studio-mark">N<span>2</span><i></i></span>${languages()}</header>
        <div class="menu-content"><p class="eyebrow"><span></span>${t('tagline')}</p><h1 dir="ltr">NATHAN<span class="title-two">2</span><small>JUDGMENT DAY</small></h1>
          <div class="menu-rule"></div><p class="campaign-label">${t('campaign')}</p>
          <div class="chapter-line"><span>01 <b>${t('city')}</b></span><i></i><span>02 <b>${t('forest')}</b></span><i></i><span>03 <b>${t('factory')}</b></span></div>
          <div class="menu-actions">${button('start','start','class="primary"')}<div class="menu-secondary">${button('showroom','showroom')}${button('help','help')}${button('settings','settings')}</div></div>
        </div><footer class="menu-footer"><span>${t('fists')} <i>•</i> ${t('parkourTag')} <i>•</i> ${t('allIn')}</span><button data-ui="install" class="quiet-button">↗ ${t('install')}</button></footer>
      </section>
      <section id="hud" class="hud" ${mode==='playing'?'':'hidden'} aria-label="${t('health')}">
        <div class="hud-left"><div class="player-line"><b>${t('nathan')}</b><span id="health-value" dir="ltr">100 / 100</span></div><div class="health-track"><div id="health-fill"></div></div><div class="rage-line"><span>${t('rage')}</span><div class="rage-track"><div id="rage-fill"></div></div><b id="rage-number" dir="ltr">0%</b></div><div id="buffs" class="buffs"></div></div>
        <div class="objective-block"><small id="chapter-label"></small><b id="objective-text"></b><span id="enemy-count"></span></div>
        <div class="hud-right"><button type="button" data-ui="bag" class="hud-button" aria-label="${t('bag')}">▣<span>${t('bag')}</span></button><button type="button" data-ui="pause" class="hud-button" aria-label="${t('pause')}">Ⅱ</button></div>
        <div id="boss-bar" class="boss-bar" hidden><div><b>${t('oz')}</b><span id="boss-number" dir="ltr"></span></div><div class="boss-track"><div id="boss-fill"></div></div></div>
        <div id="combo-display" class="combo-display" hidden><b id="combo-number"></b><span>${t('combo')}</span></div>
        <div class="keyboard-help" id="keyboard-help"><span><kbd>WASD</kbd> ${t('move')}</span><span><kbd>J K L</kbd> ${t('punch')} / ${t('kick')} / ${t('throw')}</span><span><kbd>SPACE</kbd> ${t('parkour')}</span><span><kbd>E</kbd> ${t('interact')}</span></div>
        <div id="context-desktop" class="context-desktop"><kbd>SPACE</kbd><span>${t('jump')}</span></div>
      </section>
      <section id="touch-layer" class="touch-layer" ${mode==='playing'&&isTouch()?'':'hidden'} aria-label="${t('mobile')}">
        <div id="joystick-zone" class="joystick-zone" aria-label="${t('move')}"><div id="joystick" class="joystick"><span></span><div id="joystick-knob"></div></div></div>
        <div class="combat-diamond">${Object.entries(COMBAT).map(([action,symbol])=>`<button type="button" class="combat-button combat-${action}" data-action="${action}" aria-label="${t(action)}"><b>${symbol}</b><small>${t(action)}</small></button>`).join('')}</div>
        <div class="aux-controls"><button type="button" data-action="crouch"><b>⌄</b><small>${t('crouch')}</small></button><button type="button" class="rage-button" data-action="rage"><b>ϟ</b><small>${t('rage')}</small></button></div>
        <div class="context-controls"><button type="button" id="parkour-button" data-action="parkour"><b>↟</b><small>${t('jump')}</small></button><button type="button" id="interact-button" data-action="interact" hidden><b>✦</b><small>${t('interact')}</small></button></div>
      </section>
      <section id="state-screen" class="screen state-screen" ${['paused','defeat','victory','levelcomplete'].includes(mode)?'':'hidden'}>
        <div class="state-card"><p class="eyebrow">${t(mode==='victory'?'campaignComplete':mode==='levelcomplete'?'chapterReady':'version')}</p><h2>${t(mode)}</h2><p class="state-sub">${t(`${mode}Sub`)}</p><div id="state-stats" class="state-stats"></div><div class="state-actions">${mode==='paused'?button('resume','continue','class="primary"')+button('help','help')+button('settings','settings')+button('restart','restart'):mode==='defeat'?button('restart','retry','class="primary"'):mode==='levelcomplete'?button('next','next','class="primary"'):button('start','start','class="primary"')}${button('menu','menu','class="quiet-button"')}</div></div>
      </section>
      <section id="showroom-screen" class="showroom-screen" ${mode==='showroom'?'':'hidden'}><header>${button('showroom:back','exitShowroom','class="back-button"')}${languages()}</header><div class="showroom-caption"><p class="eyebrow">${t('model')} / <span id="model-index">${showroomCharacter==='oz'?'02':'01'}</span></p><h2 id="model-name">${t(showroomCharacter)}</h2><p id="model-description">${t(showroomCharacter+'Description')}</p><small>${t('modelNote')}</small></div><div class="showroom-controls"><div class="model-switch"><button type="button" data-ui="showroom:nathan" class="${showroomCharacter==='nathan'?'active':''}">${t('nathan')}</button><button type="button" data-ui="showroom:oz" class="${showroomCharacter==='oz'?'active':''}">${t('oz')}</button></div><button type="button" data-ui="showroom:pose">↻ ${t('pose')}</button><button type="button" data-ui="showroom:face" aria-pressed="${showroomFace}">${t(showroomFace?'fullBody':'face')}</button><span>${t('rotate')}</span></div></section>
      <div id="modal-backdrop" class="modal-backdrop" hidden><section id="modal" class="modal" role="dialog" aria-modal="true"></section></div>
      <div id="toast" class="toast" role="status" hidden></div>
      <div id="rotation-screen" class="rotation-screen" hidden><div class="phone-outline"><span>↻</span></div><h2>${t('rotateTitle')}</h2><p>${t('rotateSub')}</p><small>${t('rotateHint')}</small></div>
      <div id="countdown" class="countdown" hidden aria-live="assertive"></div>
      <div id="perf" class="perf" hidden></div>`;
    attachPointerControls();
    update(data);
    if (modal) renderModal();
    checkOrientation();
  }
  function update(next = {}) {
    data = {...data,...next};
    const max = Math.max(1,Number(data.maxHealth)||100), hp = Math.max(0,Number(data.health ?? max));
    el('health-fill').style.width = `${Math.min(100,hp/max*100)}%`;
    el('health-value').textContent = `${Math.ceil(hp)} / ${max}`;
    const rage = Math.max(0,Math.min(100,Number(data.rage)||0));
    el('rage-fill').style.width = `${rage}%`; el('rage-number').textContent = `${Math.round(rage)}%`;
    host.classList.toggle('rage-ready',rage>=100); host.classList.toggle('low-health',hp<max*.25);
    const level = Math.max(0,Math.min(2,Number(data.level)||0)), levelKey = ['city','forest','factory'][level];
    el('chapter-label').textContent = `${t('chapter')} 0${level+1} / ${t(levelKey)}`;
    const objective = data.objective || 'clear'; el('objective-text').textContent = t(objective);
    el('enemy-count').textContent = `${t('enemies')}: ${Math.max(0,Number(data.enemies)||0)}`;
    const hasBoss = Number(data.bossMax)>0 && Number(data.bossHealth)>0;
    el('boss-bar').hidden = !hasBoss;
    if(hasBoss){el('boss-fill').style.width=`${Math.max(0,Math.min(100,data.bossHealth/data.bossMax*100))}%`;el('boss-number').textContent=`${Math.ceil(data.bossHealth)} / ${data.bossMax}`;}
    el('combo-display').hidden = !(data.combo>1); el('combo-number').textContent=`${data.combo||0}×`;
    const buffs = data.buffs || {};
    const buffEntries = [['power',Number(buffs.powerTime??buffs.power?.remaining??buffs.power?.time??buffs.power)||0],['weed',Number(buffs.weed?.remaining??buffs.weed?.time??buffs.weed)||0],['slim',Number(buffs.slim?.remaining??buffs.slim?.time??buffs.slim)||0]].filter(([,v])=>v>0);
    const nextBuffSignature=lang+JSON.stringify(buffEntries.map(([key,time])=>[key,Math.ceil(time)]))+buffs.power;
    if(nextBuffSignature!==buffSignature){buffSignature=nextBuffSignature;el('buffs').innerHTML = buffEntries.map(([key,seconds])=>`<span class="buff-${key}">${t(key==='power'?(Number(buffs.power)===20?'v20':'v30'):key==='slim'?'ozempic':'weed')} <b dir="ltr">${Math.ceil(seconds)}${t('seconds')}</b></span>`).join('');}
    el('state-stats').textContent = data.kills!=null?`${t('kills')}: ${data.kills} · ${t('chapter')} ${level+1}/3`:'';
    if (data.showFps) {el('perf').hidden=false;el('perf').textContent=`${Math.round(data.fps||0)} FPS`;}
    if (modal==='bag') updateBagCounts();
    if(data.context){
      if('parkour' in data.context){
        setContext(data.context.interact?'interact':'parkour',data.context.interact||data.context.parkour);
        el('parkour-button').querySelector('small').textContent=t(data.context.parkour||'jump');
      } else setContext(data.context.action,data.context.label||data.context.labelKey);
    }
  }
  function setContext(action,labelKey) {
    context = {action,label:labelKey||'jump'};
    const interaction = action==='interact';
    const ib=el('interact-button'), pb=el('parkour-button');
    ib.hidden=!interaction;
    ib.querySelector('small').textContent=t(interaction?context.label:'interact');
    pb.querySelector('small').textContent=t(interaction?'jump':context.label);
    el('context-desktop').querySelector('kbd').textContent=interaction?'E':'SPACE';
    el('context-desktop').querySelector('span').textContent=t(context.label);
    el('context-desktop').classList.toggle('available',context.label!=='jump');
  }
  function setMode(next) {
    if (next===mode) {update(data);return;}
    mode=next; modal=null; resetInput(); render();
  }
  function resetInput() {
    keys.clear(); pointers.clear(); input.x=0;input.y=0;input.lookX=0;input.lookY=0;input.sprint=false;
    host.querySelectorAll('.pressed').forEach(node=>node.classList.remove('pressed'));
    el('joystick')?.classList.remove('engaged');
    if(el('joystick-knob'))el('joystick-knob').style.transform='translate(-50%,-50%)';
  }
  function showToast(key,ms=2200) {
    clearTimeout(toastTimer); const node=el('toast');node.textContent=t(key);node.hidden=false;toastTimer=setTimeout(()=>{el('toast').hidden=true;},ms);
  }
  function pause(reason='manual') {
    if(mode!=='playing')return;
    if(reason!=='orientation') {manualPause=true;orientationPaused=false;clearTimeout(orientationTimer);}
    resetInput(); call('onPause',reason); if(mode==='playing')setMode('paused');
  }
  function resume() {
    manualPause=false;orientationPaused=false;clearTimeout(orientationTimer);modal=null;resetInput();call('onResume');if(mode==='paused')setMode('playing');
  }
  function action(actionName) {
    if(mode!=='playing'||modal)return;
    call('onAction',actionName);
  }
  function renderModal() {
    const titles={bag:'bagTitle',help:'help',settings:'settings',install:'install'};
    el('modal-backdrop').hidden=false;
    el('modal').className=`modal modal-${modal}`;
    let contents='';
    if(modal==='bag')contents=`<div class="inventory">${ITEM_IDS.map((id,i)=>`<button type="button" data-ui="use:${id}" class="item-card"><span class="item-icon item-${id}" aria-hidden="true">${['20','30','❧','↗','◒'][i]}</span><span class="item-info"><b>${t(id)}</b><small>${t(id+'Desc')}</small></span><span class="item-quantity" data-quantity="${id}" dir="ltr">×0</span><kbd>${i+1}</kbd></button>`).join('')}</div><p class="fine-print">${t('fictional')}</p>`;
    if(modal==='help')contents=`<div class="help-layout"><article><h3>${t('desktop')}</h3><p>${t('movementHelp')}</p><p>${t('combatHelp')}</p><p>${t('parkourHelp')}</p><p>${t('itemsHelp')}</p></article><article><h3>${t('mobile')}</h3><p>${t('touchHelp')}</p><h3>${t('objective')}</h3><p>${t('tacticsHelp')}</p><p>${t('environmentHelp')}</p></article></div>`;
    if(modal==='settings')contents=`<div class="settings-list"><label><span>${t('sound')}</span><select data-setting="sound"><option value="on" ${prefs.sound==='on'?'selected':''}>${t('on')}</option><option value="off" ${prefs.sound==='off'?'selected':''}>${t('off')}</option></select></label><label><span>${t('reducedMotion')}</span><select data-setting="reducedMotion"><option value="off" ${prefs.reducedMotion==='off'?'selected':''}>${t('off')}</option><option value="on" ${prefs.reducedMotion==='on'?'selected':''}>${t('on')}</option></select></label><label><span>${t('touchControls')}</span><select data-setting="touchControls">${['auto','on','off'].map(value=>`<option value="${value}" ${prefs.touchControls===value?'selected':''}>${t(value)}</option>`).join('')}</select></label><label><span>${t('quality')}</span><select data-setting="quality">${['auto','high','low'].map(value=>`<option value="${value}" ${prefs.quality===value?'selected':''}>${t('quality'+value[0].toUpperCase()+value.slice(1))}</option>`).join('')}</select></label><div class="language-setting"><span>${t('language')}</span>${languages()}</div></div><div class="settings-buttons">${button('fullscreen','fullScreen')}${button('install','install')}</div>`;
    if(modal==='install')contents=`<div class="install-symbol">↗</div><p class="install-copy">${t(/iPad|iPhone|iPod/.test(navigator.userAgent)?'installIOS':'installOther')}</p><p class="fine-print">${t('offlinePending')}</p>${deferredInstall?button('install-now','install','class="primary"'):''}`;
    el('modal').innerHTML=`<header><h2>${t(titles[modal])}</h2><button type="button" data-ui="close" class="close-button" aria-label="${t('close')}">×</button></header>${contents}`;
    if(modal==='bag')updateBagCounts();
    el('modal').querySelector('button')?.focus({preventScroll:true});
  }
  function updateBagCounts() {
    for(const id of ITEM_IDS){const n=host.querySelector(`[data-quantity="${id}"]`);if(n){const count=Number(data.inventory?.[id]??0);n.textContent=`×${count}`;n.closest('button').disabled=count<=0;}}
  }
  function openModal(which) {
    resetInput();
    if(mode==='playing'){
      modalResume=true;manualPause=false;
      call('onPause','modal');
      if(mode==='playing')setMode('paused');
    }
    modal=which;renderModal();
  }
  function closeModal(){
    modal=null;el('modal-backdrop').hidden=true;resetInput();
    const shouldResume=modalResume&&!manualPause&&!document.hidden&&!wasPortrait;
    modalResume=false;
    if(shouldResume)resume();
  }
  function handleUI(name) {
    if(name==='start'){manualPause=false;orientationPaused=false;resetInput();call('onStart');if(mode==='menu'||mode==='victory')setMode('playing');}
    else if(name==='resume')resume();
    else if(name==='pause')pause();
    else if(name==='restart'){manualPause=false;orientationPaused=false;resetInput();call('onRestart');if(mode!=='playing')setMode('playing');}
    else if(name==='showroom'){showroomFace=false;showroomCharacter='nathan';call('onShowroom');if(mode!=='showroom')setMode('showroom');}
    else if(name==='menu'||name==='showroom:back'){manualPause=false;orientationPaused=false;call('onAction','showroom:back');setMode('menu');}
    else if(name==='next'){call('onAction','next');}
    else if(name.startsWith('showroom:')){
      if(name==='showroom:nathan'||name==='showroom:oz'){showroomCharacter=name.split(':')[1];showroomFace=false;render();}
      else if(name==='showroom:face'){showroomFace=!showroomFace;const faceButton=host.querySelector('[data-ui="showroom:face"]');faceButton.textContent=t(showroomFace?'fullBody':'face');faceButton.setAttribute('aria-pressed',String(showroomFace));}
      call('onAction',name);
    }
    else if(name==='close')closeModal();
    else if(['bag','help','settings','install'].includes(name)){if(name==='bag'&&mode!=='playing')return;openModal(name);}
    else if(name.startsWith('use:')){closeModal();action(name);}
    else if(name==='fullscreen'){if(!document.fullscreenElement)document.documentElement.requestFullscreen?.().catch(()=>{});else document.exitFullscreen?.();}
    else if(name==='install-now'){deferredInstall?.prompt();deferredInstall=null;closeModal();}
  }
  on(host,'click',event=>{const language=event.target.closest('[data-lang]');if(language){lang=language.dataset.lang;savePreference('lang',lang);resetInput();call('onLanguage',lang);render();return;}const target=event.target.closest('[data-ui]');if(target&&!target.disabled)handleUI(target.dataset.ui);});
  on(host,'change',event=>{const key=event.target.dataset.setting;if(!key)return;prefs[key]=event.target.value;savePreference(key,prefs[key]);call('onSetting',key,key==='sound'||key==='reducedMotion'?prefs[key]==='on':prefs[key]);render();});
  function recomputeMovement(){
    const stick=[...pointers.values()].find(p=>p.type==='stick');
    if(stick){input.x=stick.x||0;input.y=stick.y||0;}
    else {input.x=(keys.has('KeyD')||keys.has('ArrowRight')?1:0)-(keys.has('KeyA')||keys.has('ArrowLeft')?1:0);input.y=(keys.has('KeyW')||keys.has('ArrowUp')?1:0)-(keys.has('KeyS')||keys.has('ArrowDown')?1:0);const n=Math.hypot(input.x,input.y);if(n>1){input.x/=n;input.y/=n;}}
    input.sprint=Math.hypot(input.x,input.y)>.8;
  }
  function attachPointerControls(){
    const zone=el('joystick-zone');
    zone.addEventListener('pointerdown',event=>{if(mode!=='playing'||modal||[...pointers.values()].some(p=>p.type==='stick'))return;event.preventDefault();capturePointer(zone,event.pointerId);const rect=zone.getBoundingClientRect();const cx=Math.max(rect.left+48,Math.min(rect.right-48,event.clientX)),cy=Math.max(rect.top+48,Math.min(rect.bottom-48,event.clientY));pointers.set(event.pointerId,{type:'stick',cx,cy,x:0,y:0});const joy=el('joystick');joy.style.left=`${cx-rect.left}px`;joy.style.top=`${cy-rect.top}px`;joy.classList.add('engaged');movePointer(event);});
    host.querySelectorAll('[data-action]').forEach(button=>button.addEventListener('pointerdown',event=>{if(mode!=='playing'||modal)return;event.preventDefault();capturePointer(button,event.pointerId);pointers.set(event.pointerId,{type:'action',button,action:button.dataset.action});button.classList.add('pressed');action(button.dataset.action);}));
  }
  function movePointer(event){
    const pointer=pointers.get(event.pointerId);if(!pointer)return;
    if(pointer.type==='stick'){const dx=event.clientX-pointer.cx,dy=event.clientY-pointer.cy,length=Math.hypot(dx,dy),limit=45,scaled=Math.min(1,length/limit),m=scaled<.13?0:(scaled-.13)/.87;pointer.x=length?dx/length*m:0;pointer.y=length?-dy/length*m:0;el('joystick-knob').style.transform=`translate(calc(-50% + ${length?dx/length*scaled*limit:0}px),calc(-50% + ${length?dy/length*scaled*limit:0}px))`;recomputeMovement();}
    else if(pointer.type==='look'){input.lookX+=event.clientX-pointer.x;input.lookY+=event.clientY-pointer.y;pointer.x=event.clientX;pointer.y=event.clientY;}
    else if(pointer.type==='action'){const under=document.elementFromPoint(event.clientX,event.clientY)?.closest('[data-action]');if(under&&under!==pointer.button){pointer.button.classList.remove('pressed');pointer.button=under;pointer.action=under.dataset.action;under.classList.add('pressed');action(pointer.action);}}
  }
  function endPointer(event){const pointer=pointers.get(event.pointerId);if(!pointer)return;if(pointer.type==='stick'){el('joystick')?.classList.remove('engaged');el('joystick-knob').style.transform='translate(-50%,-50%)';}if(pointer.type==='action')pointer.button.classList.remove('pressed');pointers.delete(event.pointerId);recomputeMovement();}
  on(window,'pointermove',movePointer,{passive:false});
  for(const type of ['pointerup','pointercancel','lostpointercapture'])on(window,type,endPointer);
  on(document.getElementById('game-canvas'),'pointerdown',event=>{if(!['playing','showroom'].includes(mode)||modal)return;if(event.pointerType==='touch'&&mode==='playing'&&event.clientX<innerWidth*.42)return;event.preventDefault();capturePointer(event.currentTarget,event.pointerId);pointers.set(event.pointerId,{type:'look',x:event.clientX,y:event.clientY});});
  const keyActions={KeyJ:'punch',KeyK:'kick',KeyL:'throw',ShiftLeft:'dodge',ShiftRight:'dodge',KeyC:'crouch',KeyR:'rage',Space:'parkour',KeyE:'interact',Digit1:'use:v20',Digit2:'use:v30',Digit3:'use:weed',Digit4:'use:ozempic',Digit5:'use:shawarma'};
  on(window,'keydown',event=>{
    if(event.target instanceof HTMLSelectElement||event.target instanceof HTMLInputElement)return;
    if(event.code==='Escape'){event.preventDefault();if(event.repeat)return;if(modal)closeModal();else if(mode==='playing')pause();else if(mode==='paused')resume();else if(mode==='showroom')handleUI('showroom:back');return;}
    if(mode!=='playing'||modal)return;
    if(MOVEMENT.has(event.code)){event.preventDefault();keys.add(event.code);recomputeMovement();}
    if(keyActions[event.code]){event.preventDefault();if(!event.repeat)action(keyActions[event.code]);}
    if(event.code==='KeyB'&&!event.repeat){event.preventDefault();openModal('bag');}
  });
  on(window,'keyup',event=>{keys.delete(event.code);recomputeMovement();});
  function suspendForBackground(){
    resetInput();modalResume=false;
    if(mode==='playing')pause('blur');
    else if(mode==='paused'){manualPause=true;orientationPaused=false;clearTimeout(orientationTimer);el('countdown').hidden=true;}
  }
  on(window,'blur',suspendForBackground);
  on(document,'visibilitychange',()=>{if(document.hidden)suspendForBackground();});
  on(window,'contextmenu',event=>{if(event.target.closest('#ui-root,#game-canvas'))event.preventDefault();});
  on(window,'beforeinstallprompt',event=>{event.preventDefault();deferredInstall=event;});
  on(window,'message',event=>{if(event.data?.type==='NATHAN_OFFLINE_READY')showToast('offline');});
  on(navigator.serviceWorker||window,'message',event=>{if(event.data?.type==='OFFLINE_READY'||event.data?.type==='NATHAN_OFFLINE_READY')showToast('offline');});
  function viewport(){const vp=window.visualViewport;document.documentElement.style.setProperty('--viewport-height',`${Math.round(vp?.height||innerHeight)}px`);checkOrientation();}
  function checkOrientation(){
    const portrait=isTouch()&&(window.visualViewport?.width||innerWidth)<(window.visualViewport?.height||innerHeight);
    const rotation=el('rotation-screen');if(!rotation)return;
    rotation.hidden=!portrait;
    if(portrait){clearTimeout(orientationTimer);el('countdown').hidden=true;if(!wasPortrait&&mode==='playing'&&!modal){orientationPaused=true;manualPause=false;pause('orientation');}resetInput();}
    else if(wasPortrait&&orientationPaused&&!manualPause&&mode==='paused'){
      let count=3;el('countdown').textContent=count;el('countdown').hidden=false;
      const tick=()=>{if(document.hidden||manualPause||!orientationPaused){el('countdown').hidden=true;return;}count--;if(count>0){el('countdown').textContent=count;orientationTimer=setTimeout(tick,1000);}else{el('countdown').hidden=true;resume();}};
      orientationTimer=setTimeout(tick,1000);
    }
    wasPortrait=portrait;
  }
  on(window,'resize',()=>{viewport();setTimeout(viewport,300);});
  on(window,'orientationchange',()=>{resetInput();viewport();setTimeout(viewport,300);});
  if(window.visualViewport)on(window.visualViewport,'resize',()=>{viewport();setTimeout(viewport,300);});
  render();viewport();
  call('onLanguage',lang);
  for(const [key,value] of Object.entries(prefs))call('onSetting',key,key==='sound'||key==='reducedMotion'?value==='on':value);
  return {input,get lang(){return lang;},get mode(){return mode;},t,setMode,update,setContext,resetInput,showToast,
    setParkourContext(labelKey){el('parkour-button').querySelector('small').textContent=t(labelKey);},
    setShowroomPose(key){const btn=host.querySelector('[data-ui="showroom:pose"]');if(btn)btn.textContent=`↻ ${t(key)}`;},
    dispose(){clearTimeout(toastTimer);clearTimeout(orientationTimer);listeners.forEach(remove=>remove());host.innerHTML='';}
  };
}

export {STRINGS};
