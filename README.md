🛡️ AmneziaWG Admin GUI

A Windows GUI application built with PowerShell and Windows Forms to manage AmneziaWG servers installed via the amneziawg-installer script.

Приложение с графическим интерфейсом для Windows, написанное на PowerShell и Windows Forms, предназначенное для управления серверами AmneziaWG, установленными через скрипт amneziawg-installer.

https://github.com/bivlked/amneziawg-installer

<img width="875" height="506" alt="Снимок" src="https://github.com/user-attachments/assets/fcfc28c6-c49e-4da7-a2dc-7061e89f308b" />
<img width="876" height="509" alt="Снимок2" src="https://github.com/user-attachments/assets/f50d2d07-9ce5-494f-82a9-0824cf81b282" />

English

✨ Features

Persistent SSH Connection: Uses the SSH.NET library for high-speed, persistent SSH connections. No external ssh.exe or plink.exe required. Auto-downloads dependencies on the first run.

Profile Management: Create, edit, and delete server profiles. Passwords are securely encrypted using Windows DPAPI. Supports both SSH Key and Password authentication.

Client Management: Add, edit, regenerate, and delete clients. Supports --psk (PresharedKey) and --expires (time limits: hours, days, weeks) flags.

Config & QR Codes: View .conf files directly in the app. Generate and view/download QR codes (both WireGuard-compatible .png and Amnezia VPN app .vpnuri.png).

Traffic Statistics: View real-time traffic stats (Received, Sent, Total) and last handshake times for all clients.

Server Maintenance: Restart the AWG service and create full server backups (configs, keys, expiry data) with one click. Backups are downloaded locally.

Dynamic Localization: Automatically detects system language. Supports dynamic language switching. Users can easily add their own translations by creating a strings.??.json file.


⚙️ Requirements

Windows OS (Windows 10/11 or Windows Server 2019+)

PowerShell 7.5 or higher (Get it from Microsoft Store or GitHub)

AmneziaWG Server: Must be installed via the amneziawg-installer script.

🚀 Getting Started

Ensure PowerShell 7.5+ is installed.

Clone this repository or download the main.ps1 script along with the modules and localization folders.

Right-click main.ps1 and select "Run with PowerShell" (or run it from a PS7 terminal).

On the first launch, the app will automatically download the required SSH.NET and BouncyCastle DLLs into the script folder.

Русский

✨ Возможности

Постоянное SSH-соединение: Использует библиотеку SSH.NET для быстрого и постоянного SSH-соединения. Не требует внешних ssh.exe или plink.exe. Зависимости скачиваются автоматически при первом запуске.

Управление профилями: Создание, редактирование и удаление профилей серверов. Пароли шифруются с помощью Windows DPAPI. Поддерживается авторизация как по SSH-ключу, так и по паролю.

Управление клиентами: Добавление, редактирование, перегенерация и удаление клиентов. Поддерживаются флаги --psk (PresharedKey) и --expires (ограничение срока действия: часы, дни, недели).

Конфиги и QR-коды: Просмотр файлов .conf прямо в приложении. Генерация, просмотр и скачивание QR-кодов (как WireGuard-совместимых .png, так и для приложения Amnezia VPN .vpnuri.png).

Статистика трафика: Просмотр статистики трафика в реальном времени (Принято, Отправлено, Всего) и времени последнего рукопожатия (handshake) для всех клиентов.

Обслуживание сервера: Перезапуск службы AWG и создание полных бэкапов сервера (конфиги, ключи, данные сроков) в один клик. Архивы скачиваются на локальный компьютер.

Динамическая локализация: Автоматическое определение языка системы. Поддержка динамического переключения языков. Пользователи могут легко добавить свой перевод, создав файл strings.??.json.

⚙️ Требования

ОС Windows (Windows 10/11 или Windows Server 2019+)

PowerShell 7.5 или выше (Установить из Microsoft Store или с GitHub)

Сервер AmneziaWG: Должен быть установлен через скрипт amneziawg-installer.


📦 Restoring from Backup / Восстановление из бэкапа

EN: To restore a server from a downloaded backup, upload the .tar.gz archive to the new server and run:


sudo bash /root/awg/manage_amneziawg.sh restore /path/to/awg_backup_*.tar.gz

RU: Чтобы восстановить сервер из скачанного бэкапа, загрузите архив .tar.gz на новый сервер и выполните:

bash

sudo bash /root/awg/manage_amneziawg.sh restore /путь/к/awg_backup_*.tar.gz

⚠️ Disclaimer / Отказ от ответственности

This software is provided "as is". Manage cryptographic keys and backups with care. The authors are not responsible for any data loss or server misconfiguration.
Данное программное обеспечение предоставляется "как есть". Обращайтесь с криптографическими ключами и резервными копиями с осторожностью. Авторы не несут ответственности за потерю данных или некорректную настройку сервера.
