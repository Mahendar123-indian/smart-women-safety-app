<<<<<<< HEAD
# 🛡️ SafeHer — Smart Women Safety Prediction System

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?style=for-the-badge&logo=fastapi)
![Firebase](https://img.shields.io/badge/Firebase-Integrated-FFCA28?style=for-the-badge&logo=firebase)
![Google Cloud](https://img.shields.io/badge/Google_Cloud_Run-Deployed-4285F4?style=for-the-badge&logo=google-cloud)

**SafeHer** is not just another "panic button" app. It is a proactive, autonomous **AI Sentinel** designed to predict, detect, and respond to physical danger without requiring the user to unlock their phone or open the app.

By fusing continuous background sensor data with an advanced 7-Factor Machine Learning engine, SafeHer transforms a standard smartphone into an unbreakable safety device.

---

## ✨ Core Features

### 🧠 1. Autonomous AI Sentinel (Background Isolate)
SafeHer runs a continuous, battery-optimized background isolate that samples the device's Accelerometer, Gyroscope, and GPS at 50Hz. Every 3 seconds, a telemetry payload is silently dispatched to the cloud for real-time threat analysis.

### 🚨 2. The 7-Factor Danger Fusion Engine (ML Backend)
Deployed on Google Cloud Run, the Python/FastAPI backend calculates a real-time Danger Score (0-100%) using:
1. **Kinematic Movement:** Detects running, falling, or physical struggles using a 28-feature extraction model.
2. **Acoustic Analysis:** Analyzes ambient audio for high-stress frequencies or screams.
3. **Behavioral Baseline:** Utilizes **Welford's Online Algorithm** to learn the user's normal routine, instantly flagging temporal or spatial anomalies.
4. **Context & Time:** Increases sensitivity during high-risk hours or in known danger zones.
5. **Location Risk:** Evaluates the safety index of the current GPS coordinates.
6. **Phone Behavior:** Detects chaotic device handling (e.g., phone being thrown or face-down impact).
7. **Route Deviation:** Calculates severe departures from historical transit paths.

### ⚡ 3. Zero-Click Triggers
If the phone is out of reach, SafeHer provides multiple hardware-level bypasses:
* **Hardware Trigger:** Native listener that triggers SOS when volume buttons are held.
* **Kinematic Trigger:** Rapid 3x shake detection.
* **Voice Sentinel:** Background acoustic trigger.

### 📸 4. Unbreakable Evidence Vault
Upon an SOS trigger, the `EvidenceOrchestrator` launches a stealth capture sequence:
* **Audio:** 60-second hidden mic recording.
* **Photos:** Rapid 6-photo burst (utilizing both front and rear cameras).
* **Video:** 30s clips from both cameras.
* **GPS Trail:** Live location pinging every 5 seconds.
* **Court-Ready PDF:** Automatically compiles all media links, timestamps, and GPS logs into an encrypted PDF report uploaded to Firebase Storage.

### 🎨 5. Indestructible UI/UX
* **Overflow-Free SOS Dashboard:** A highly resilient, CustomPainter-driven UI that scales perfectly across devices and gracefully handles keyboard intrusions (e.g., when entering the Safe PIN).
* **Live Google Maps Integration:** Real-time tracking overlay during an active SOS.
* **Temporal Escalation Memory:** The UI reflects danger escalation over a 30-second rolling window to prevent false alarms from single drops/jolts.

---

## 🏗️ System Architecture

### Frontend (Flutter)
* **State Management:** `Provider` architecture for decoupled logic (`SosProvider`, `LocationProvider`, `AuthProvider`).
* **Routing:** Autonomous background routing via global `NavigatorKey` (allows the background AI to force the app to the SOS screen).
* **Local Storage:** `SharedPreferences` for JWT tokens, baseline cache, and user preferences.
* **Crashlytics:** Global error trapping for layout and platform dispatcher exceptions.

### Backend (Python / FastAPI)
* **API Gateway:** Thread-safe Asyncio implementation capable of handling concurrent SOS telemetry streams.
* **Dynamic Padding Matrix:** Auto-pads incomplete sensor arrays to prevent shape mismatches and `500 Internal Server Errors`.
* **Deployment:** Containerized via Docker and deployed to **Google Cloud Run** (`asia-south1`).

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.x+)
* Python 3.11+
* Firebase CLI & active Firebase Project
* Google Cloud SDK (`gcloud`)

### Installation (App)

1. Clone the repository:
   ```bash
   git clone [https://github.com/Mahendar123-indian/smart_safety_app.git](https://github.com/Mahendar123-indian/smart_safety_app.git)
   cd smart_safety_app
=======
# smart-women-safety-app
A Flutter and Firebase based Women Safety Application that provides SOS emergency alerts, real-time location tracking, emergency contact notifications, Google Maps integration, and secure user authentication to enhance women's safety and emergency response.
>>>>>>> 3f85105a8bd9dc110251ae369e2691c4282df689
