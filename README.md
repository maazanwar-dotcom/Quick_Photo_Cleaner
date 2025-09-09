# 📸 Quick Photo Cleaner - Flutter Stack

Welcome to **Quick Photo Cleaner**, a fast and intuitive mobile app built with Flutter to help you organize and declutter your photo gallery with ease!

![Flutter](https://img.shields.io/badge/flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)

---

## 🚀 Overview

**Quick Photo Cleaner** empowers you to swipe, sort, and clean your photo library in seconds. Whether you're overwhelmed with thousands of images or just want to keep your gallery tidy, this app provides a snappy, swipe-based experience for reviewing, keeping, and discarding photos. 

- **Swipe to Keep or Discard:** Quickly review photos and swipe to decide if you want to keep or delete them.
- **Undo Last Action:** Made a mistake? Instantly undo your last swipe.
- **Sort Modes:** 
  - **All Photos:** Sort through every photo in your gallery.
  - **By Date:** Focus on photos from a specific day.
  - **Cluster:** Sort photos taken around a certain time (±30 minutes of a chosen “seed” image).
- **Persistent Storage:** Your keep/discard decisions are stored locally, so you won't lose progress.
- **Trash Management:** Recover accidentally discarded images or permanently delete unwanted ones.
- **Statistics:** See total, kept, discarded, and remaining photos.
- **Multi-Platform:** Runs on Android, iOS, Windows, and Linux.

---

## ✨ Features

- **Intuitive Swipe Actions:** Swipe right to keep, left to discard.
- **Photo Recovery:** Restore photos from trash if needed.
- **Permanent Deletion:** Remove unwanted photos forever.
- **Thumbnail Preloading:** Fast browsing with preloaded thumbnails.
- **Permission Management:** Securely requests photo access.

---

## 🛠️ Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Compatible device/emulator (Android/iOS/Windows/Linux)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/maazanwar-dotcom/Quick_Photo_Cleaner--Flutter-Stack-.git
   cd Quick_Photo_Cleaner--Flutter-Stack-
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

---

## 📱 Permissions

The app requests storage and media access permissions on your device for photo management. On Android, it supports all relevant API levels (from Android 9 to Android 13+).

---

## 🧩 Project Structure

- `lib/services/photo_sorter_model.dart` — Core logic for photo sorting, persistence, and state management.
- `android/app/src/main/kotlin/...` — Native Android integration for permissions and photo deletion.
- `windows/`, `linux/` — Cross-platform build configurations.

---

## 💡 How It Works

1. **Load and Cache Photos:** App loads all gallery images and preloads thumbnails for fast navigation.
2. **Persistent Decisions:** Decisions to keep or discard are remembered across sessions.
3. **Cluster/Date Sorting:** Focus sorting by cluster (±30 minutes) or specific date.
4. **Trash Management:** Discarded images can be recovered or deleted permanently.
5. **Statistics:** View your cleaning progress anytime.

---

## 🔒 Privacy & Security

All data and decisions are stored locally on your device. The app only requests necessary permissions to access and manage your photos.

---

## 📚 Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Useful Flutter samples](https://docs.flutter.dev/cookbook)

---

## 🤝 Contributing

We welcome contributions! Please fork the repo and submit a pull request. For major changes, open an issue first to discuss what you’d like to change.

---

## 📜 License

This project is licensed under the MIT License.

---

## 🙏 Acknowledgements

Thanks to the Flutter community and all contributors!

---

> **Quick Photo Cleaner** — Your gallery, decluttered in a swipe!
