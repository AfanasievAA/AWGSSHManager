# 🛡️ AmneziaWG Admin GUI

**Графическое приложение для Windows** для управления серверами **AmneziaWG**, установленными через скрипт [amneziawg-installer](https://github.com/bivlked/amneziawg-installer). 

---
Как установить: Скачать все файлы (зелёная кнопка Code -> Download ZIP), распаковать в любой каталог, запустить AWGSSHManager.cmd.
## 📸 Скриншоты

| Главное окно | Управление клиентами |
|--------------|----------------------|
| ![Снимок](https://github.com/user-attachments/assets/fcfc28c6-c49e-4da7-a2dc-7061e89f308b) | ![Снимок2](https://github.com/user-attachments/assets/f50d2d07-9ce5-494f-82a9-0824cf81b282) |

---

## 🇷🇺 Русский

### ✨ Возможности

- **🔐 Постоянное SSH-соединение** – Использует библиотеку **SSH.NET** для быстрого и стабильного SSH-соединения. Не требует внешних `ssh.exe` или `plink.exe`. Зависимости скачиваются автоматически при первом запуске.

- **📁 Управление профилями** – Создание, редактирование и удаление профилей серверов. Пароли шифруются с помощью **Windows DPAPI**. Поддерживается авторизация как по **SSH-ключу**, так и по **паролю**.

- **👥 Управление клиентами** – Добавление, редактирование, перегенерация и удаление клиентов. Поддерживаются флаги `--psk` (PresharedKey) и `--expires` (ограничение срока действия: часы, дни, недели).

- **📄 Конфиги и QR-коды** – Просмотр `.conf` файлов прямо в приложении. Генерация, просмотр и скачивание QR-кодов – как **WireGuard-совместимых `.png`**, так и для **приложения Amnezia VPN (`.vpnuri.png`)**.

- **📊 Статистика трафика** – Просмотр статистики трафика в реальном времени (**Принято**, **Отправлено**, **Всего**) и времени последнего рукопожатия для всех клиентов.

- **🛠️ Обслуживание сервера** – Перезапуск службы AWG и создание/восстановление **полных бэкапов сервера** (конфиги, ключи, данные сроков) в один клик. Архивы скачиваются на локальный компьютер.

- **🌍 Динамическая локализация** – Автоматическое определение языка системы. Поддержка динамического переключения языков. Пользователи могут легко добавить свой перевод, создав файл `strings.??.json`.

---

### ⚙️ Требования

- 🖥️ **ОС Windows** (Windows 10/11 или Windows Server 2019+)
- ⚡ **PowerShell 7.5+** – [Установить из Microsoft Store](https://apps.microsoft.com/detail/9mz1snwt0n5d) или с [GitHub](https://github.com/PowerShell/PowerShell)
- 🌐 **Сервер AmneziaWG** – Должен быть установлен через скрипт [amneziawg-installer](https://github.com/bivlked/amneziawg-installer)

---

### 🚀 Начало работы

1. Убедитесь, что установлен **PowerShell 7.5+**.
2. Клонируйте этот репозиторий или скачайте скрипт `main.ps1` вместе с папками `modules/` и `localization/`.
3. Нажмите правой кнопкой мыши на `main.ps1` и выберите **"Run with PowerShell"** (или запустите из терминала PS7).
4. При первом запуске приложение автоматически загрузит необходимые библиотеки **SSH.NET** и **BouncyCastle** в папку со скриптом.

---

### ⚠️ Отказ от ответственности
Данное программное обеспечение предоставляется "как есть". Обращайтесь с криптографическими ключами и резервными копиями с осторожностью. Авторы не несут ответственности за потерю данных или некорректную настройку сервера.

---


# 🛡️ AmneziaWG Admin GUI

**Windows GUI application** for managing **AmneziaWG** servers installed via the [amneziawg-installer](https://github.com/bivlked/amneziawg-installer) script. 

---

## 📸 Screenshots

| Main Window | Client Management |
|-------------|-------------------|
| ![Screenshot](https://github.com/user-attachments/assets/fcfc28c6-c49e-4da7-a2dc-7061e89f308b) | ![Screenshot2](https://github.com/user-attachments/assets/f50d2d07-9ce5-494f-82a9-0824cf81b282) |

---

## 🇬🇧 English

### ✨ Features

- **🔐 Persistent SSH Connection** – Uses the **SSH.NET** library for fast, stable, and persistent SSH sessions. No external `ssh.exe` or `plink.exe` required. Dependencies are auto-downloaded on first run.

- **📁 Profile Management** – Create, edit, and delete server profiles. Passwords are securely encrypted using **Windows DPAPI**. Supports both **SSH Key** and **Password** authentication.

- **👥 Client Management** – Add, edit, regenerate, and delete clients. Supports `--psk` (PresharedKey) and `--expires` (time limits: hours, days, weeks) flags.

- **📄 Config & QR Codes** – View `.conf` files directly in the app. Generate and view/download QR codes – both **WireGuard-compatible `.png`** and **Amnezia VPN app `.vpnuri.png`**.

- **📊 Traffic Statistics** – View real-time traffic stats (**Received**, **Sent**, **Total**) and last handshake times for all clients.

- **🛠️ Server Maintenance** – Restart the AWG service and create/restore **full server backups** (configs, keys, expiry data) with one click. Backups are downloaded locally.

- **🌍 Dynamic Localization** – Automatically detects system language. Supports dynamic language switching. Users can easily add their own translations by creating a `strings.??.json` file.

---

### ⚙️ Requirements

- 🖥️ **Windows OS** (Windows 10/11 or Windows Server 2019+)
- ⚡ **PowerShell 7.5+** – [Download from Microsoft Store](https://apps.microsoft.com/detail/9mz1snwt0n5d) or [GitHub](https://github.com/PowerShell/PowerShell)
- 🌐 **AmneziaWG Server** – Must be installed via the [amneziawg-installer](https://github.com/bivlked/amneziawg-installer) script.

---

### 🚀 Getting Started

1. Ensure **PowerShell 7.5+** is installed.
2. Clone this repository or download the `main.ps1` script along with the `modules/` and `localization/` folders.
3. Right-click `main.ps1` and select **"Run with PowerShell"** (or run it from a PS7 terminal).
4. On the first launch, the app will automatically download the required **SSH.NET** and **BouncyCastle** DLLs into the script folder.

---

### ⚠️ Disclaimer

This software is provided "as is". Manage cryptographic keys and backups with care. The authors are not responsible for any data loss or server misconfiguration.

---

## 📜 License

This project is open-source and available under the [MIT License](LICENSE).
