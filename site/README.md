# Лісові сурми — сайт

Окремий сайт «Мисливські Сигнали» на HTML/CSS/JS без збірки. Повторює вигляд
і функції мобільного додатку (Flutter, `../lib`), читає ті самі дані з
Firestore проєкту `huntingsignals`, медіа бере з Firebase Storage.

## Структура

    index.html          каркас сторінки
    css/app.css         стилі (кольори з HuntingTheme)
    js/app.js           запуск, перемикання вкладок за хешем (#/signals, #/education, #/events, #/favorites)
    js/firebase.js      підключення Firebase (Firestore, Storage, Auth)
    js/access.js        вхід, пробний період, коди доступу (див. ../docs/ACCESS.md)
    js/data.js          сигнали, категорії, обране, плейлисти, завантаження у Storage
    js/audio.js         єдиний аудіоплеєр
    js/ui.js            побудова DOM, діалоги, тости, стек екранів
    js/views/           екрани: shell, signals, signal-detail, notation, video, gallery,
                        favorites, education, events, admin, admin-access,
                        access (вхід / підтвердження пошти / акаунт)
    assets/             банер, іконки

## Локальний запуск

    python -m http.server 8090

і відкрити http://127.0.0.1:8090 (потрібен саме http-сервер: ES-модулі не
працюють із file://).

## Деплой

Vercel, проєкт `lisovi-surmy`; корінь деплою — ця тека:

    vercel deploy --prod

## Паролі

Адмін-панель — той самий пароль, що в додатку (`AdminService.adminPassword`);
партитура — той самий, що в `signal_card.dart`. Обидва в коді сайту видно
будь-кому, як і в APK: це захист від випадкових натискань, а не безпека.

## Вхід

Сайт відкривається лише після входу (пошта + пароль, підтвердження пошти).
Корпоративна пошта коледжу — безкоштовно; інші — 30 днів, далі код доступу
від адміністратора (Адмін-панель → Коди доступу). Правила, дані й акаунти
спільні з додатком — див. `../docs/ACCESS.md`.
