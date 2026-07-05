import os
import numpy as np
import joblib
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict
import logging

# ตั้งค่า Logging สำหรับการแสดงผลสถานะการทำงานของเซิร์ฟเวอร์
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# เริ่มต้นระบบ FastAPI App พร้อมระบุหัวข้อ คำอธิบาย และเวอร์ชัน
app = FastAPI(
    title="Emotion Detection API",
    description="API สำหรับตรวจจับอารมณ์จากข้อมูล EEG brainwave ด้วย TSception model",
    version="1.0.0",
)

# เปิดใช้งาน CORS Middleware เพื่ออนุญาตการเชื่อมต่อ API จากต้นทาง (Origin) ต่างๆ เช่น หน้าเว็บหรือแอป Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ประกาศตัวแปร Global เพื่อใช้เก็บโมเดล, ตัวแปลงสเกลข้อมูล และตัวถอดรหัส Label
model = None
scaler = None
label_encoder = None

# ตั้งค่าตำแหน่งที่อยู่ของโมเดล (ใช้ร่วมกับโปรเจกต์ Flutter)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, "..", "assets", "models")

MODEL_PATH = os.path.join(MODELS_DIR, "Emotion_TSception.h5")
SCALER_PATH = os.path.join(MODELS_DIR, "scaler_kmeans.pkl")
LABEL_ENCODER_PATH = os.path.join(MODELS_DIR, "label_encoder_kmeans.pkl")

# รายการอารมณ์ทั้งหมดที่แยกตามคลาส index (อารมณ์ภาษาอังกฤษ)
EMOTION_LABELS = {
    0: "neutral",
    1: "happy",
    2: "sad",
    3: "angry",
    4: "fearful",
    5: "calm",
    6: "stressed",
    7: "anxious",
    8: "surprised",
    9: "disgusted",
}

# พจนานุกรมแปลภาษาอารมณ์จากอังกฤษเป็นภาษาไทย
EMOTION_LABELS_TH = {
    "neutral": "ปกติ",
    "happy": "มีความสุข",
    "sad": "เศร้า",
    "angry": "โกรธ",
    "fearful": "กลัว",
    "calm": "สงบ",
    "stressed": "เครียด",
    "anxious": "วิตกกังวล",
    "surprised": "ประหลาดใจ",
    "disgusted": "รังเกียจ",
}

# ไอคอน Emoji ที่สอดคล้องกับแต่ละอารมณ์
EMOTION_EMOJIS = {
    "neutral": "😐",
    "happy": "😊",
    "sad": "😢",
    "angry": "😠",
    "fearful": "😨",
    "calm": "😌",
    "stressed": "😰",
    "anxious": "😟",
    "surprised": "😲",
    "disgusted": "🤢",
}

# โมเดลข้อมูลนำเข้าสำหรับคลื่นสมอง EEG แต่ละช่วงความถี่
class EEGData(BaseModel):
    alpha: float
    beta: float
    theta: float
    delta: float
    gamma: float
    attention: Optional[float] = 0.0
    meditation: Optional[float] = 0.0

# โมเดลข้อมูลนำเข้าในรูปแบบกลุ่ม (Batch) เพื่อใช้วิเคราะห์ข้อมูลพร้อมๆ กันหลายวินาที
class EEGBatchData(BaseModel):
    data: List[EEGData]

# โครงสร้างผลลัพธ์ข้อมูลส่งกลับของการทำนายอารมณ์
class EmotionResponse(BaseModel):
    success: bool
    emotion_type: str
    emotion_label_th: str
    emoji: str
    confidence: float
    all_scores: Dict[str, float]
    method: str

# โครงสร้างผลลัพธ์การตรวจสอบสถานะระบบ (Health Check)
class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    scaler_loaded: bool
    label_encoder_loaded: bool

# ฟังก์ชันโหลดไฟล์โมเดล, Scaler และ Label Encoder เข้ามาในหน่วยความจำตอนเริ่มต้นระบบ
def load_models():
    global model, scaler, label_encoder

    # 1. พยายามโหลดโมเดลปัญญาประดิษฐ์ TSception (Deep Learning - TensorFlow)
    try:
        import tensorflow as tf
        if os.path.exists(MODEL_PATH):
            model = tf.keras.models.load_model(MODEL_PATH, compile=False)
            logger.info(f"✅ Loaded TSception model from {MODEL_PATH}")
            logger.info(f"   Model input shape: {model.input_shape}")
            logger.info(f"   Model output shape: {model.output_shape}")
        else:
            logger.warning(f"⚠️ Model file not found: {MODEL_PATH}")
    except Exception as e:
        logger.error(f"❌ Failed to load model: {e}")

    # 2. โหลด MinMaxScaler เพื่อแปลงขนาดข้อมูลฟีเจอร์คลื่นสมองให้เข้าคู่กับชุดที่โมเดลใช้เรียนรู้
    try:
        if os.path.exists(SCALER_PATH):
            scaler = joblib.load(SCALER_PATH)
            logger.info(f"✅ Loaded scaler from {SCALER_PATH}")
        else:
            logger.warning(f"⚠️ Scaler file not found: {SCALER_PATH}")
    except Exception as e:
        logger.error(f"❌ Failed to load scaler: {e}")

    # 3. โหลด Label Encoder เพื่อใช้แปลงชื่อประเภทอารมณ์ (เช่น happy, calm) จากตัวเลขทำนาย
    try:
        if os.path.exists(LABEL_ENCODER_PATH):
            label_encoder = joblib.load(LABEL_ENCODER_PATH)
            logger.info(f"✅ Loaded label encoder from {LABEL_ENCODER_PATH}")
            if hasattr(label_encoder, 'classes_'):
                logger.info(f"   Classes: {label_encoder.classes_}")
        else:
            logger.warning(f"⚠️ Label encoder file not found: {LABEL_ENCODER_PATH}")
    except Exception as e:
        logger.error(f"❌ Failed to load label encoder: {e}")

# ดักจับอีเวนต์เมื่อระบบ API เริ่มสตาร์ทขึ้นมาเพื่อเริ่มโหลดโมเดลทันที
@app.on_event("startup")
async def startup_event():
    logger.info("🚀 Starting Emotion Detection API...")
    load_models()
    logger.info("✅ API ready!")

# Endpoint ตรวจสอบสถานะการเชื่อมต่อและการทำงานของเซิร์ฟเวอร์
@app.get("/", response_model=HealthResponse)
async def health_check():
    return HealthResponse(
        status="running",
        model_loaded=model is not None,
        scaler_loaded=scaler is not None,
        label_encoder_loaded=label_encoder is not None,
    )

# Alias ของหน้าหลัก เพื่อตรวจสอบสถานะความพร้อมของเซิร์ฟเวอร์
@app.get("/health", response_model=HealthResponse)
async def health():
    return await health_check()

# ฟังก์ชันทำนายอารมณ์โดยใช้ Deep Learning Model (TSception) ที่โหลดไว้
def predict_with_model(eeg_features: np.ndarray) -> dict:
    global model, scaler, label_encoder

    try:
        # ปรับสเกลข้อมูล EEG Feature ให้อยู่ในช่วงที่เหมาะสมกับโมเดล
        if scaler is not None:
            scaled_features = scaler.transform(eeg_features.reshape(1, -1))
        else:
            scaled_features = eeg_features.reshape(1, -1)

        if model is not None:
            input_shape = model.input_shape

            # แปลงโครงสร้างข้อมูล (Reshape) ให้ตรงกับ input shape ของโมเดลเครือข่ายประสาท
            if len(input_shape) == 3:
                time_steps = input_shape[1] if input_shape[1] is not None else 1
                features = input_shape[2] if input_shape[2] is not None else scaled_features.shape[1]
                model_input = np.zeros((1, time_steps, features))
                for t in range(time_steps):
                    model_input[0, t, :min(features, scaled_features.shape[1])] = \
                        scaled_features[0, :min(features, scaled_features.shape[1])]
            elif len(input_shape) == 4:
                ch = input_shape[1] if input_shape[1] is not None else 1
                ts = input_shape[2] if input_shape[2] is not None else scaled_features.shape[1]
                feat = input_shape[3] if input_shape[3] is not None else 1
                model_input = np.zeros((1, ch, ts, feat))
                for c in range(ch):
                    for t in range(min(ts, scaled_features.shape[1])):
                        model_input[0, c, t, 0] = scaled_features[0, t]
            else:
                model_input = scaled_features

            # ทำนายผลโดยใช้ TSception Model
            predictions = model.predict(model_input, verbose=0)

            # ตรวจสอบและดึงผลลัพธ์ความน่าจะเป็นของอารมณ์ประเภทต่างๆ (Multi-class)
            if predictions.ndim > 1 and predictions.shape[1] > 1:
                predicted_class = int(np.argmax(predictions[0]))
                confidence = float(np.max(predictions[0]))
                all_scores = {}

                # ดึงคะแนนผลตอบรับของแต่ละอารมณ์
                if label_encoder is not None and hasattr(label_encoder, 'classes_'):
                    for i, cls in enumerate(label_encoder.classes_):
                        if i < len(predictions[0]):
                            all_scores[str(cls)] = float(predictions[0][i])
                    emotion_type = str(label_encoder.classes_[predicted_class]) if predicted_class < len(label_encoder.classes_) else "neutral"
                else:
                    for i in range(len(predictions[0])):
                        emotion_name = EMOTION_LABELS.get(i, f"class_{i}")
                        all_scores[emotion_name] = float(predictions[0][i])
                    emotion_type = EMOTION_LABELS.get(predicted_class, "neutral")
            else:
                # กรณีผลลัพธ์เป็นแบบ Binary classification หรือสัญกรณ์มิติเดียว
                predicted_class = int(round(float(predictions[0][0])))
                confidence = float(predictions[0][0])
                if label_encoder is not None and hasattr(label_encoder, 'classes_'):
                    emotion_type = str(label_encoder.classes_[min(predicted_class, len(label_encoder.classes_) - 1)])
                else:
                    emotion_type = EMOTION_LABELS.get(predicted_class, "neutral")
                all_scores = {emotion_type: confidence}

            return {
                "emotion_type": emotion_type,
                "confidence": confidence,
                "all_scores": all_scores,
                "method": "tsception_model",
            }
        else:
            raise Exception("Model not loaded")

    except Exception as e:
        logger.error(f"Model prediction error: {e}")
        raise

# ระบบตรรกะแบบ Rule-Based (สำรองกรณีไม่ได้โหลดไฟล์โมเดลปัญญาประดิษฐ์ไว้)
# ประเมินสถิติสัดส่วนความหนาแน่นของคลื่นสมองแต่ละช่วงความถี่ เพื่อคาดการณ์ความรู้สึกเบื้องต้น
def predict_with_rules(eeg_data: EEGData) -> dict:
    alpha = eeg_data.alpha
    beta = eeg_data.beta
    theta = eeg_data.theta
    delta = eeg_data.delta
    gamma = eeg_data.gamma

    # หาผลรวมของคลื่นสมองเพื่อนำมาคิดอัตราส่วนเปอร์เซ็นต์
    total = alpha + beta + theta + delta + gamma
    if total == 0:
        total = 1

    a_pct = alpha / total
    b_pct = beta / total
    t_pct = theta / total
    d_pct = delta / total
    g_pct = gamma / total

    scores = {}

    # Calm (สงบ): คลื่น Alpha สูง และ คลื่น Beta ต่ำ
    scores["calm"] = min(1.0, a_pct * 1.5 + (1 - b_pct) * 0.5)

    # Stressed (เครียด): คลื่น Beta และ Gamma ตอบสนองในปริมาณที่สูง
    scores["stressed"] = min(1.0, b_pct * 1.2 + g_pct * 0.8)

    # Happy (มีความสุข): คลื่น Alpha เด่นร่วมกับ Theta ปานกลาง
    scores["happy"] = min(1.0, a_pct * 1.2 + t_pct * 0.5 + (1 - b_pct) * 0.3)

    # Sad (เศร้า): คลื่น Theta และ Delta ทำงานเด่นในสภาวะซึมเศร้ากระตุ้นน้อย
    scores["sad"] = min(1.0, t_pct * 1.0 + d_pct * 0.8 + (1 - a_pct) * 0.2)

    # Angry (โกรธ): คลื่น Beta และ Gamma สูงมากร่วมกับ Alpha ที่ลดลงอย่างเห็นได้ชัด
    scores["angry"] = min(1.0, b_pct * 1.0 + g_pct * 1.0 + (1 - a_pct) * 0.5)

    # Fearful (กลัว): คลื่นความถี่สูงอย่าง Gamma ถูกกระตุ้นอย่างฉับพลัน
    scores["fearful"] = min(1.0, g_pct * 1.3 + b_pct * 0.5 + (1 - a_pct) * 0.3)

    # Neutral (ปกติ): สภาวะสมดุลของคลื่นสมองหลักทั้งสาม
    balance = 1 - abs(a_pct - 0.2) - abs(b_pct - 0.2) - abs(t_pct - 0.2)
    scores["neutral"] = max(0, min(1.0, balance))

    # Anxious (วิตกกังวล): คลื่น Theta และ Beta มีการเปลี่ยนแปลง
    scores["anxious"] = min(1.0, t_pct * 0.8 + b_pct * 0.7 + g_pct * 0.3)

    # ทำการแปลงคะแนนสัมพัทธ์ (Normalization) ให้สูงสุดเป็น 1.0
    max_score = max(scores.values()) if scores else 1
    if max_score > 0:
        scores = {k: round(v / max_score, 4) for k, v in scores.items()}

    emotion_type = max(scores, key=scores.get)
    confidence = scores[emotion_type]

    return {
        "emotion_type": emotion_type,
        "confidence": confidence,
        "all_scores": scores,
        "method": "rule_based",
    }

# Endpoint หลักสำหรับการทำนายอารมณ์ด้วยข้อมูลคลื่นสมอง EEG แบบวินาทีเดียว
@app.post("/predict", response_model=EmotionResponse)
async def predict_emotion(eeg_data: EEGData):
    try:
        # หากโหลดโมเดลปัญญาประดิษฐ์สำเร็จ จะใช้วิธี Deep learning ในการทำนาย
        if model is not None:
            features = np.array([
                eeg_data.alpha,
                eeg_data.beta,
                eeg_data.theta,
                eeg_data.delta,
                eeg_data.gamma,
                eeg_data.attention or 0,
                eeg_data.meditation or 0,
            ])
            result = predict_with_model(features)
        else:
            # หากไม่มีไฟล์โมเดล จะประเมินด้วยตรรกะแบบเงื่อนไขคลื่นสมองเบื้องต้นแทน
            result = predict_with_rules(eeg_data)

        emotion_type = result["emotion_type"]

        return EmotionResponse(
            success=True,
            emotion_type=emotion_type,
            emotion_label_th=EMOTION_LABELS_TH.get(emotion_type, emotion_type),
            emoji=EMOTION_EMOJIS.get(emotion_type, "😐"),
            confidence=result["confidence"],
            all_scores=result["all_scores"],
            method=result["method"],
        )

    except Exception as e:
        logger.error(f"Prediction error: {e}")
        # กรณีเกิดความผิดพลาดใดๆ ให้รันระบบ Rule-Based เป็นตัวสำรองฉุกเฉิน (Fallback)
        try:
            result = predict_with_rules(eeg_data)
            emotion_type = result["emotion_type"]
            return EmotionResponse(
                success=True,
                emotion_type=emotion_type,
                emotion_label_th=EMOTION_LABELS_TH.get(emotion_type, emotion_type),
                emoji=EMOTION_EMOJIS.get(emotion_type, "😐"),
                confidence=result["confidence"],
                all_scores=result["all_scores"],
                method="rule_based_fallback",
            )
        except Exception as e2:
            raise HTTPException(status_code=500, detail=str(e2))

# Endpoint สำหรับวิเคราะห์ข้อมูลคลื่นสมองแบบกลุ่ม (Batch) เพื่อเฉลี่ยแนวโน้มอารมณ์จากช่วงเวลาที่กว้างขึ้น
@app.post("/predict/batch", response_model=EmotionResponse)
async def predict_emotion_batch(batch: EEGBatchData):
    if not batch.data:
        raise HTTPException(status_code=400, detail="No EEG data provided")

    all_results = []
    # ประมวลผลและทำนายข้อมูลคลื่นสมองของแต่ละวินาทีในชุดข้อมูล
    for eeg in batch.data:
        try:
            if model is not None:
                features = np.array([
                    eeg.alpha, eeg.beta, eeg.theta,
                    eeg.delta, eeg.gamma,
                    eeg.attention or 0, eeg.meditation or 0,
                ])
                result = predict_with_model(features)
            else:
                result = predict_with_rules(eeg)
            all_results.append(result)
        except Exception:
            all_results.append(predict_with_rules(eeg))

    # นำค่าคะแนนความน่าจะเป็นของอารมณ์ทั้งหมดมาเฉลี่ยรวม
    combined_scores: Dict[str, float] = {}
    for r in all_results:
        for k, v in r["all_scores"].items():
            combined_scores[k] = combined_scores.get(k, 0) + v

    n = len(all_results)
    combined_scores = {k: round(v / n, 4) for k, v in combined_scores.items()}

    # หาอารมณ์ที่มีคะแนนเฉลี่ยสูงสุดในกลุ่มข้อมูลทั้งหมด
    emotion_type = max(combined_scores, key=combined_scores.get)
    confidence = combined_scores[emotion_type]

    return EmotionResponse(
        success=True,
        emotion_type=emotion_type,
        emotion_label_th=EMOTION_LABELS_TH.get(emotion_type, emotion_type),
        emoji=EMOTION_EMOJIS.get(emotion_type, "😐"),
        confidence=confidence,
        all_scores=combined_scores,
        method=all_results[0]["method"] if all_results else "unknown",
    )

# สั่งให้รัน Uvicorn เซิร์ฟเวอร์เมื่อทำการสั่งรันไฟล์นี้โดยตรง (Port: 8000)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
