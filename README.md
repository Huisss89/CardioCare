
# 💓 CardioCare App

CardioCare is an Android-based mobile application designed to support preventive hypertension management using smartphone technology. By leveraging computer vision and photoplethysmography (PPG) via the smartphone camera and flash, the app enables users to monitor key cardiovascular indicators such as:

- Heart Rate (HR)
- Heart Rate Variability (HRV)
- Estimated Blood Pressure (BP)

The application integrates AI-driven analytics to provide personalized health insights and without requiring external devices like smartwatches.


## 💡 Features

- PPG-Based Cardiac Monitoring
Measures HR and HRV using fingertip detection via smartphone camera
- AI-Based Blood Pressure Estimation
Predicts BP
- Manual BP Logging and classify BP in normal, elevated and high category
- Smart Health Insights 
    - Trend analysis of HR, HRV, and BP
    - Personalized lifestyle recommendations
    - AI Assistant Chatbot for health-related queries



## 👨🏻‍💻Technical Components - Products and Platforms

- Flutter
- Android Studio 
- FastAPI (Python) 
- Render 
- Google AI Studio
- Firebase Authentication 
- Firestore Database (NoSQL) 



## 🔗Backend & Models
A FastAPI-based backend with machine learning models for cardiac monitoring and BP estimation using PPG signals.
1. Signal Quality Index (SQI) Model
- PPG Signal Quality Assessment
- https://github.com/Huisss89/Cardio_PPG_SQI

2. Heart Rate (HR) and Heart Rate Variability (HRV) Measurement Model
- PPG Signal Processing
- https://github.com/Huisss89/Cardio_PPG_HR

3. Blood Pressure Estimation (BP) Model
- PPG Signal Processing
- https://github.com/Huisss89/Cardio_BP_Estimation_PPG_Only



## 🧑🏻‍💻 Installation
Clone the repository 
```bash
git clone https://github.com/Huisss89/CardioCare.git
```
Go to the project directory
```bash
cd Huisss89
```
Flutter pub get and run
```bash
flutter pub get
flutter run
```


## ⚙️ Configuration
This project uses environment variables for sensitive data.

Before running the app, provide your API key using --dart-define:
```bash
flutter run --dart-define=GEMINI_API_KEY=your_api_key_here
```
For release build:
```bash
flutter build apk --dart-define=GEMINI_API_KEY=your_api_key_here
```


## 📲 How to use CardioCare
1. Launch the CardioCare app
2. Place your fingertip over the camera and flash
3. Wait for signal processing
4. _View your results:_
- Heart Rate (HR)
- Heart Rate Variability (HRV)
- Estimated Blood Pressure (BP)

  _Optional features:_
 - Log manual BP readings
 - Chat with AI assistant
 - Review trends and recommendations
 - Set reminders
 - Export health records



## ⚠️ Disclaimer
CardioCare is not a medical device and should not be used for clinical diagnosis. Always consult a healthcare professional for medical advice.


## 📄 License

Distributed under the MIT License. See [License](https://choosealicense.com/licenses/mit/) for more information.




