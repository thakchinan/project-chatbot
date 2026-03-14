"""
Emotion Detection API Server
ใช้ Emotion_TSception.h5 model + K-Means scaler/encoder
สำหรับตรวจจับอารมณ์จากข้อมูล EEG brainwave

Run: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

import os
import numpy as np
import joblib
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Emotion Detection API",
    description="API สำหรับตรวจจับอารมณ์จากข้อมูล EEG brainwave ด้วย TSception model",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global model variables
model = None
scaler = None
label_encoder = None

# Model paths (relative to this file)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, "..", "assets", "models")

MODEL_PATH = os.path.join(MODELS_DIR, "Emotion_TSception.h5")
SCALER_PATH = os.path.join(MODELS_DIR, "scaler_kmeans.pkl")
LABEL_ENCODER_PATH = os.path.join(MODELS_DIR, "label_encoder_kmeans.pkl")

# Emotion labels mapping (fallback if label_encoder fails)
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


class EEGData(BaseModel):
    """ข้อมูล EEG สำหรับ predict อารมณ์"""
    alpha: float
    beta: float
    theta: float
    delta: float
    gamma: float
    attention: Optional[float] = 0.0
    meditation: Optional[float] = 0.0


class EEGBatchData(BaseModel):
    """ข้อมูล EEG หลายจุดเวลา (time-series)"""
    data: List[EEGData]


class EmotionResponse(BaseModel):
    """ผลลัพธ์การตรวจจับอารมณ์"""
    success: bool
    emotion_type: str
    emotion_label_th: str
    emoji: str
    confidence: float
    all_scores: Dict[str, float]
    method: str


class HealthResponse(BaseModel):
    """สถานะเซิร์ฟเวอร์"""
    status: str
    model_loaded: bool
    scaler_loaded: bool
    label_encoder_loaded: bool


def load_models():
    """โหลด model ทั้งหมด"""
    global model, scaler, label_encoder

    # Load TensorFlow model
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

    # Load scaler
    try:
        if os.path.exists(SCALER_PATH):
            scaler = joblib.load(SCALER_PATH)
            logger.info(f"✅ Loaded scaler from {SCALER_PATH}")
        else:
            logger.warning(f"⚠️ Scaler file not found: {SCALER_PATH}")
    except Exception as e:
        logger.error(f"❌ Failed to load scaler: {e}")

    # Load label encoder
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


@app.on_event("startup")
async def startup_event():
    """โหลด models ตอนเริ่มเซิร์ฟเวอร์"""
    logger.info("🚀 Starting Emotion Detection API...")
    load_models()
    logger.info("✅ API ready!")


@app.get("/", response_model=HealthResponse)
async def health_check():
    """ตรวจสอบสถานะเซิร์ฟเวอร์"""
    return HealthResponse(
        status="running",
        model_loaded=model is not None,
        scaler_loaded=scaler is not None,
        label_encoder_loaded=label_encoder is not None,
    )


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint"""
    return await health_check()


def predict_with_model(eeg_features: np.ndarray) -> dict:
    """
    ใช้ TSception model ในการ predict อารมณ์
    """
    global model, scaler, label_encoder

    try:
        # Scale features if scaler is available
        if scaler is not None:
            scaled_features = scaler.transform(eeg_features.reshape(1, -1))
        else:
            scaled_features = eeg_features.reshape(1, -1)

        # Reshape for model input (depends on model architecture)
        # TSception typically expects: (batch, channels, time_steps)
        # We need to inspect the model input shape and adapt
        if model is not None:
            input_shape = model.input_shape

            # Adapt input to match model's expected shape
            if len(input_shape) == 3:
                # (batch, time_steps, features) or (batch, channels, time_steps)
                time_steps = input_shape[1] if input_shape[1] is not None else 1
                features = input_shape[2] if input_shape[2] is not None else scaled_features.shape[1]
                model_input = np.zeros((1, time_steps, features))
                # Fill with our features, repeat if needed
                for t in range(time_steps):
                    model_input[0, t, :min(features, scaled_features.shape[1])] = \
                        scaled_features[0, :min(features, scaled_features.shape[1])]
            elif len(input_shape) == 4:
                # (batch, channels, time_steps, 1) or similar
                ch = input_shape[1] if input_shape[1] is not None else 1
                ts = input_shape[2] if input_shape[2] is not None else scaled_features.shape[1]
                feat = input_shape[3] if input_shape[3] is not None else 1
                model_input = np.zeros((1, ch, ts, feat))
                for c in range(ch):
                    for t in range(min(ts, scaled_features.shape[1])):
                        model_input[0, c, t, 0] = scaled_features[0, t]
            else:
                model_input = scaled_features

            predictions = model.predict(model_input, verbose=0)

            # Get prediction results
            if predictions.ndim > 1 and predictions.shape[1] > 1:
                # Multi-class output
                predicted_class = int(np.argmax(predictions[0]))
                confidence = float(np.max(predictions[0]))
                all_scores = {}

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
                # Single output (regression-like or binary)
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


def predict_with_rules(eeg_data: EEGData) -> dict:
    """
    Rule-based fallback: วิเคราะห์อารมณ์จาก brainwave patterns
    ใช้เมื่อ model ไม่พร้อม
    """
    alpha = eeg_data.alpha
    beta = eeg_data.beta
    theta = eeg_data.theta
    delta = eeg_data.delta
    gamma = eeg_data.gamma

    total = alpha + beta + theta + delta + gamma
    if total == 0:
        total = 1

    # Normalize to percentages
    a_pct = alpha / total
    b_pct = beta / total
    t_pct = theta / total
    d_pct = delta / total
    g_pct = gamma / total

    scores = {}

    # Rule-based emotion detection from EEG patterns
    # High Alpha + Low Beta = Calm/Relaxed
    scores["calm"] = min(1.0, a_pct * 1.5 + (1 - b_pct) * 0.5)

    # High Beta + High Gamma = Stressed/Anxious
    scores["stressed"] = min(1.0, b_pct * 1.2 + g_pct * 0.8)

    # High Alpha + moderate Theta = Happy
    scores["happy"] = min(1.0, a_pct * 1.2 + t_pct * 0.5 + (1 - b_pct) * 0.3)

    # High Theta + High Delta = Sad
    scores["sad"] = min(1.0, t_pct * 1.0 + d_pct * 0.8 + (1 - a_pct) * 0.2)

    # High Beta + High Gamma + Low Alpha = Angry
    scores["angry"] = min(1.0, b_pct * 1.0 + g_pct * 1.0 + (1 - a_pct) * 0.5)

    # High Gamma + sudden changes = Fearful
    scores["fearful"] = min(1.0, g_pct * 1.3 + b_pct * 0.5 + (1 - a_pct) * 0.3)

    # Balanced waves = Neutral
    balance = 1 - abs(a_pct - 0.2) - abs(b_pct - 0.2) - abs(t_pct - 0.2)
    scores["neutral"] = max(0, min(1.0, balance))

    # High Theta = Anxious
    scores["anxious"] = min(1.0, t_pct * 0.8 + b_pct * 0.7 + g_pct * 0.3)

    # Normalize scores
    max_score = max(scores.values()) if scores else 1
    if max_score > 0:
        scores = {k: round(v / max_score, 4) for k, v in scores.items()}

    # Get dominant emotion
    emotion_type = max(scores, key=scores.get)
    confidence = scores[emotion_type]

    return {
        "emotion_type": emotion_type,
        "confidence": confidence,
        "all_scores": scores,
        "method": "rule_based",
    }


@app.post("/predict", response_model=EmotionResponse)
async def predict_emotion(eeg_data: EEGData):
    """
    ตรวจจับอารมณ์จากข้อมูล EEG เดี่ยว
    
    ส่งค่า alpha, beta, theta, delta, gamma brainwave
    จะได้ผลลัพธ์อารมณ์ + ระดับความมั่นใจ
    """
    try:
        # Try model-based prediction first
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
            # Fallback to rule-based
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
        # Fallback to rule-based on any error
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


@app.post("/predict/batch", response_model=EmotionResponse)
async def predict_emotion_batch(batch: EEGBatchData):
    """
    ตรวจจับอารมณ์จากข้อมูล EEG หลายจุดเวลา (time-series)
    เฉลี่ยผลลัพธ์จากทุกจุดเวลา
    """
    if not batch.data:
        raise HTTPException(status_code=400, detail="No EEG data provided")

    all_results = []
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

    # Average all scores
    combined_scores: Dict[str, float] = {}
    for r in all_results:
        for k, v in r["all_scores"].items():
            combined_scores[k] = combined_scores.get(k, 0) + v

    n = len(all_results)
    combined_scores = {k: round(v / n, 4) for k, v in combined_scores.items()}

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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
