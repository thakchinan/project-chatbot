# Emotion Detection API Server

## ภาพรวม
Python FastAPI backend สำหรับตรวจจับอารมณ์จากข้อมูล EEG brainwave  
ใช้ **Emotion_TSception.h5** model + **K-Means** scaler/encoder

## ไฟล์ Model ที่ใช้
| ไฟล์ | คำอธิบาย |
|------|----------|
| `Emotion_TSception.h5` | โมเดล Deep Learning (TSception) สำหรับจำแนกอารมณ์ |
| `scaler_kmeans.pkl` | Standard Scaler สำหรับ normalize ข้อมูล EEG |
| `label_encoder_kmeans.pkl` | Label Encoder สำหรับแปลง class number → ชื่ออารมณ์ |

## วิธีติดตั้ง

```bash
# 1. เข้าไปที่โฟลเดอร์
cd emotion_api

# 2. สร้าง virtual environment
python3 -m venv venv
source venv/bin/activate  # macOS/Linux

# 3. ติดตั้ง dependencies
pip install -r requirements.txt

# 4. รันเซิร์ฟเวอร์
python main.py
# หรือ
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## API Endpoints

### `GET /health`
ตรวจสอบสถานะเซิร์ฟเวอร์

### `POST /predict`
ตรวจจับอารมณ์จากข้อมูล EEG เดี่ยว

```json
{
  "alpha": 65.0,
  "beta": 45.0,
  "theta": 55.0,
  "delta": 20.0,
  "gamma": 10.0,
  "attention": 50.0,
  "meditation": 50.0
}
```

**Response:**
```json
{
  "success": true,
  "emotion_type": "calm",
  "emotion_label_th": "สงบ",
  "emoji": "😌",
  "confidence": 0.85,
  "all_scores": {
    "calm": 0.85,
    "happy": 0.65,
    "neutral": 0.45,
    ...
  },
  "method": "tsception_model"
}
```

### `POST /predict/batch`
ตรวจจับอารมณ์จากข้อมูล EEG หลายจุดเวลา

## หมายเหตุ
- ถ้า model โหลดไม่ได้ จะใช้ **Rule-based fallback** อัตโนมัติ
- Flutter app จะเรียก API นี้ทุก 5 วินาที เมื่อเชื่อมต่อ Muse S
- API รันที่ `http://localhost:8000` โดยค่าเริ่มต้น
