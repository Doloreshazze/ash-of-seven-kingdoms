# Публикация проекта в GitHub

В среде подготовки удалось проверить подключение к GitHub аккаунта `Doloreshazze`, однако у доступного коннектора нет операции **создания нового GitHub-репозитория**. Публикация не выполнена автоматически.

## Создать пустой удалённый репозиторий

Открой https://github.com/new и укажи:
- Owner: `Doloreshazze`
- Repository name: `ash-of-seven-kingdoms`
- Description: `2D dark-fantasy action RPG — Пепел семи королевств`
- Visibility: **Private** на этапе разработки.
- Не ставь галочки «Add a README», «.gitignore», «License» — они уже присутствуют в подготовленном проекте.

## Залить готовую папку с компьютера

Распакуй ZIP и выполни внутри папки `ash-of-seven-kingdoms`:

```bash
git init
git add .
git commit -m "feat: first playable prologue"
git branch -M main
git remote add origin https://github.com/Doloreshazze/ash-of-seven-kingdoms.git
git push -u origin main
```

Для HTTPS GitHub может потребовать авторизацию через Git Credential Manager. Пароль аккаунта напрямую в git не вводи; используй штатную авторизацию браузером или GitHub Desktop.

После публикации открой `Actions` — первая сборка покажет результат headless smoke-test и, при успехе, предоставит Windows артефакт. Для Android нужна отдельная настройка SDK/экспорта и постоянного ключа подписи перед выпуском в Play Console.

## GitHub Actions: Android debug APK

После загрузки проекта в новый репозиторий:
1. Открой **Actions → Android debug APK**; push в `main` запускает workflow автоматически, либо нажми **Run workflow**.
2. Дождись зелёной отметки; открой запуск и секцию **Artifacts**.
3. Скачай `Ash-of-the-Seven-Kingdoms-Android-debug-APK`, распакуй `.zip` и установи `.apk` на телефон.
4. Если установка поверх предыдущей версии не проходит, удали прежний debug APK: ключ CI создаётся заново при каждой сборке. Публикационный ключ для Play Console должен быть постоянным.

Статус workflow до первого запуска не подтверждён.
