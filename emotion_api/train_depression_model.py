#!/usr/bin/env python3
"""
=============================================================================
🧠 Depression Detection Model Training Script
=============================================================================
สคริปต์สำหรับเทรนโมเดลตรวจจับโรคซึมเศร้าจากข้อมูลคลื่นสมอง EEG
ผลลัพธ์: โมเดล TFLite ที่คืนค่า Probability (0.0 - 1.0)
         นำไปคูณ 100 ในแอป Flutter = คะแนนความเสี่ยง 0-100

วิธีใช้:
  1. เตรียม Dataset CSV ที่มีคอลัมน์: delta, theta, alpha, beta, gamma, label
     (label: 0 = ปกติ, 1 = ซึมเศร้า)
  2. รันสคริปต์:
     python train_depression_model.py --csv path/to/your_dataset.csv
  3. ไฟล์ output จะอยู่ใน ../assets/models/:
     - depression_model.tflite     (โมเดลสำหรับใช้ในแอป)
     - depression_scaler.json      (Scaler parameters)
     - depression_labels.json      (Label mapping)
=============================================================================
"""

import os
import sys
import json
import argparse
import numpy as np
import pandas as pd
from pathlib import Path

# ===========================================================================
# Configuration
# ===========================================================================
MODELS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "models")
OUTPUT_TFLITE = os.path.join(MODELS_DIR, "depression_model.tflite")
OUTPUT_KERAS = os.path.join(MODELS_DIR, "depression_model.keras")
OUTPUT_SCALER = os.path.join(MODELS_DIR, "depression_scaler.json")
OUTPUT_LABELS = os.path.join(MODELS_DIR, "depression_labels.json")

# Feature columns ที่โมเดลต้องการ (5 ย่านความถี่หลักของ EEG)
FEATURE_COLUMNS = ["delta", "theta", "alpha", "beta", "gamma"]

# Optional: ฟีเจอร์เสริม (ถ้ามีใน dataset)
OPTIONAL_FEATURES = ["attention", "meditation"]

# Label column
LABEL_COLUMN = "label"  # 0 = Normal, 1 = Depression (MDD)


def load_and_prepare_data(csv_path: str):
    """โหลด CSV และเตรียมข้อมูลสำหรับเทรน"""
    print("=" * 60)
    print("📂 โหลดข้อมูลจาก:", csv_path)
    print("=" * 60)

    df = pd.read_csv(csv_path)
    print(f"   จำนวนแถว: {len(df)}")
    print(f"   คอลัมน์ทั้งหมด: {list(df.columns)}")

    # ตรวจสอบคอลัมน์ที่จำเป็น
    missing_cols = [c for c in FEATURE_COLUMNS if c not in df.columns]
    if missing_cols:
        # ลองหาชื่อคอลัมน์ที่คล้ายกัน (case-insensitive)
        col_map = {c.lower(): c for c in df.columns}
        for mc in missing_cols:
            if mc.lower() in col_map:
                df.rename(columns={col_map[mc.lower()]: mc}, inplace=True)
            else:
                print(f"❌ ไม่พบคอลัมน์ '{mc}' ใน Dataset!")
                print(f"   คอลัมน์ที่มี: {list(df.columns)}")
                sys.exit(1)

    # ตรวจสอบ label column
    if LABEL_COLUMN not in df.columns:
        # ลองหาชื่ออื่นที่อาจเป็น label
        label_candidates = ["label", "target", "class", "emotion", "state",
                            "depression", "mdd", "diagnosis", "Label", "Target"]
        found = False
        for lc in label_candidates:
            if lc in df.columns:
                df.rename(columns={lc: LABEL_COLUMN}, inplace=True)
                found = True
                break
        if not found:
            print(f"❌ ไม่พบคอลัมน์ label ใน Dataset!")
            print(f"   คอลัมน์ที่มี: {list(df.columns)}")
            print(f"   กรุณาตั้งชื่อคอลัมน์ label เป็น '{LABEL_COLUMN}'")
            sys.exit(1)

    # เลือกฟีเจอร์ที่จะใช้
    use_features = FEATURE_COLUMNS.copy()
    for opt in OPTIONAL_FEATURES:
        if opt in df.columns:
            use_features.append(opt)
            print(f"   ✅ พบฟีเจอร์เสริม: {opt}")

    X = df[use_features].values.astype(np.float32)
    y = df[LABEL_COLUMN].values.astype(np.float32)

    # ถ้า label มีมากกว่า 2 ค่า ให้แปลงเป็น binary
    unique_labels = np.unique(y)
    print(f"   Labels: {unique_labels}")
    if len(unique_labels) > 2:
        print("   ⚠️ พบ label มากกว่า 2 ค่า → แปลงเป็น binary (0=ปกติ, 1=ซึมเศร้า)")
        # สมมติว่าค่าที่สูงกว่ากลาง = ซึมเศร้า
        threshold = np.median(unique_labels)
        y = (y > threshold).astype(np.float32)

    n_normal = int(np.sum(y == 0))
    n_depression = int(np.sum(y == 1))
    print(f"\n📊 สัดส่วนข้อมูล:")
    print(f"   ปกติ (0):      {n_normal} ราย ({n_normal / len(y) * 100:.1f}%)")
    print(f"   ซึมเศร้า (1):  {n_depression} ราย ({n_depression / len(y) * 100:.1f}%)")

    return X, y, use_features


def scale_features(X_train, X_test):
    """StandardScaler แบบ manual (ไม่ต้องพึ่ง sklearn)"""
    mean = X_train.mean(axis=0)
    std = X_train.std(axis=0)
    std[std == 0] = 1.0  # ป้องกันหาร 0

    X_train_scaled = (X_train - mean) / std
    X_test_scaled = (X_test - mean) / std

    return X_train_scaled, X_test_scaled, mean, std


def build_model(n_features: int):
    """สร้างโมเดล Neural Network สำหรับ Binary Classification"""
    import tensorflow as tf

    model = tf.keras.Sequential([
        tf.keras.layers.InputLayer(input_shape=(n_features,)),

        # Hidden layer 1
        tf.keras.layers.Dense(64, activation="relu"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),

        # Hidden layer 2
        tf.keras.layers.Dense(32, activation="relu"),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.2),

        # Hidden layer 3
        tf.keras.layers.Dense(16, activation="relu"),
        tf.keras.layers.Dropout(0.1),

        # ⭐ Output: 1 neuron + sigmoid → ค่า probability 0.0 - 1.0
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="binary_crossentropy",
        metrics=["accuracy"],
    )

    model.summary()
    return model


def train_model(X, y, use_features):
    """เทรนโมเดลและบันทึกผลลัพธ์"""
    import tensorflow as tf
    from sklearn.model_selection import train_test_split

    print("\n" + "=" * 60)
    print("🏋️ เริ่มเทรนโมเดล...")
    print("=" * 60)

    # แบ่งข้อมูล Train/Test (80/20)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"   Train: {len(X_train)} | Test: {len(X_test)}")

    # Scale features
    X_train_scaled, X_test_scaled, mean, std = scale_features(X_train, X_test)

    # สร้างและเทรนโมเดล
    model = build_model(n_features=X_train_scaled.shape[1])

    # Class weight เพื่อชดเชยกรณีข้อมูลไม่สมดุล
    n_normal = int(np.sum(y_train == 0))
    n_depression = int(np.sum(y_train == 1))
    total = n_normal + n_depression
    class_weight = {
        0: total / (2 * n_normal) if n_normal > 0 else 1.0,
        1: total / (2 * n_depression) if n_depression > 0 else 1.0,
    }
    print(f"   Class weights: {class_weight}")

    history = model.fit(
        X_train_scaled, y_train,
        epochs=100,
        batch_size=32,
        validation_split=0.15,
        class_weight=class_weight,
        callbacks=[
            tf.keras.callbacks.EarlyStopping(
                monitor="val_loss", patience=15, restore_best_weights=True
            ),
            tf.keras.callbacks.ReduceLROnPlateau(
                monitor="val_loss", factor=0.5, patience=5, min_lr=1e-6
            ),
        ],
        verbose=1,
    )

    # ประเมินผล
    print("\n" + "=" * 60)
    print("📊 ผลการประเมินบน Test Set:")
    print("=" * 60)

    test_loss, test_acc = model.evaluate(X_test_scaled, y_test, verbose=0)
    print(f"   Test Accuracy: {test_acc * 100:.2f}%")
    print(f"   Test Loss:     {test_loss:.4f}")

    # แสดงตัวอย่างค่า probability
    predictions = model.predict(X_test_scaled[:10], verbose=0)
    print(f"\n📋 ตัวอย่างค่า Probability (10 ตัวแรก):")
    print(f"   {'Probability':>12} | {'Score (×100)':>12} | {'Actual':>8} | {'Risk Level'}")
    print(f"   {'-' * 55}")
    for i, (pred, actual) in enumerate(zip(predictions[:10], y_test[:10])):
        prob = float(pred[0])
        score = prob * 100
        risk = "ต่ำ" if score <= 28 else ("ปานกลาง" if score <= 48 else "สูง")
        label = "ซึมเศร้า" if actual == 1 else "ปกติ"
        print(f"   {prob:>12.4f} | {score:>10.1f}  | {label:>8} | {risk}")

    return model, mean, std, use_features, test_acc


def convert_to_tflite(model):
    """แปลงโมเดลเป็น TFLite"""
    import tensorflow as tf

    print("\n" + "=" * 60)
    print("📦 แปลงเป็น TFLite...")
    print("=" * 60)

    # บันทึก Keras model ก่อน
    model.save(OUTPUT_KERAS)
    print(f"   ✅ บันทึก Keras model: {OUTPUT_KERAS}")

    # แปลงเป็น TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    os.makedirs(os.path.dirname(OUTPUT_TFLITE), exist_ok=True)
    with open(OUTPUT_TFLITE, "wb") as f:
        f.write(tflite_model)

    size_kb = os.path.getsize(OUTPUT_TFLITE) / 1024
    print(f"   ✅ บันทึก TFLite model: {OUTPUT_TFLITE}")
    print(f"   ขนาด: {size_kb:.1f} KB")

    # ตรวจสอบ TFLite model
    interpreter = tf.lite.Interpreter(model_path=OUTPUT_TFLITE)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    print(f"\n📋 TFLite Model Details:")
    print(f"   Input:  shape={input_details[0]['shape']} dtype={input_details[0]['dtype']}")
    print(f"   Output: shape={output_details[0]['shape']} dtype={output_details[0]['dtype']}")
    print(f"   ⭐ Output จะเป็นค่า Probability (0.0-1.0) → คูณ 100 = คะแนน 0-100")


def save_scaler_params(mean, std, feature_names):
    """บันทึก Scaler parameters เป็น JSON สำหรับ Flutter"""
    scaler_data = {
        "type": "StandardScaler",
        "mean": mean.tolist(),
        "scale": std.tolist(),
        "n_features": len(feature_names),
        "feature_names": feature_names,
        "description": "Depression detection scaler - normalize EEG features before inference",
    }

    with open(OUTPUT_SCALER, "w", encoding="utf-8") as f:
        json.dump(scaler_data, f, indent=2, ensure_ascii=False)

    print(f"   ✅ บันทึก Scaler params: {OUTPUT_SCALER}")


def save_label_info():
    """บันทึก Label mapping เป็น JSON"""
    labels_data = {
        "task": "depression_detection",
        "model_type": "binary_classification_sigmoid",
        "output_range": "0.0 - 1.0 (multiply by 100 for 0-100 score)",
        "classes": ["Normal", "Depression"],
        "index_to_label": {
            "0": "Normal",
            "1": "Depression"
        },
        "risk_levels": {
            "low":      {"min": 0,  "max": 28, "label_th": "ความเสี่ยงต่ำ",   "color": "0xFF4CAF50"},
            "moderate": {"min": 29, "max": 48, "label_th": "ปานกลาง",        "color": "0xFFFF9800"},
            "high":     {"min": 49, "max": 100, "label_th": "ความเสี่ยงสูง",  "color": "0xFFF44336"},
        },
        "interpretation": {
            "0-28":   "สภาวะจิตใจปกติ / ความเสี่ยงต่ำ",
            "29-48":  "มีความเสี่ยงปานกลาง / ควรติดตามอาการ",
            "49-100": "มีความเสี่ยงสูง / ควรปรึกษาแพทย์",
        },
    }

    with open(OUTPUT_LABELS, "w", encoding="utf-8") as f:
        json.dump(labels_data, f, indent=2, ensure_ascii=False)

    print(f"   ✅ บันทึก Label info: {OUTPUT_LABELS}")


def create_sample_dataset():
    """สร้าง Dataset ตัวอย่างสำหรับทดสอบ (ถ้าไม่มี CSV จริง)"""
    sample_csv = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sample_depression_data.csv")

    print("\n" + "=" * 60)
    print("📝 สร้าง Sample Dataset สำหรับทดสอบ...")
    print("=" * 60)
    print("   ⚠️ นี่เป็นข้อมูลจำลอง ไม่ใช่ข้อมูลทางการแพทย์จริง!")
    print("   ⚠️ กรุณาใช้ Dataset จริงจาก MODMA / Kaggle สำหรับโมเดลจริง\n")

    np.random.seed(42)
    n_samples = 500

    # กลุ่มปกติ (Normal): Alpha สูง, Beta ต่ำ, Theta ต่ำ
    n_normal = n_samples // 2
    normal_data = {
        "delta": np.random.normal(22.5, 7.8, n_normal),
        "theta": np.random.normal(18.0, 6.5, n_normal),
        "alpha": np.random.normal(15.0, 6.5, n_normal),  # Alpha สูงกว่า = ผ่อนคลาย
        "beta":  np.random.normal(35.0, 12.0, n_normal),
        "gamma": np.random.normal(10.0, 5.0, n_normal),
        "label": np.zeros(n_normal),
    }

    # กลุ่มซึมเศร้า (MDD): Alpha ต่ำ, Theta สูง, FAA ผิดปกติ
    n_mdd = n_samples - n_normal
    mdd_data = {
        "delta": np.random.normal(28.0, 9.0, n_mdd),     # Delta สูงขึ้น (สมองล้า)
        "theta": np.random.normal(25.0, 7.0, n_mdd),     # Theta สูงขึ้น (rumination)
        "alpha": np.random.normal(9.0, 4.5, n_mdd),      # Alpha ต่ำลง (ขาดการผ่อนคลาย)
        "beta":  np.random.normal(42.0, 14.0, n_mdd),    # Beta สูงขึ้น (overthinking)
        "gamma": np.random.normal(14.0, 6.0, n_mdd),     # Gamma สูงขึ้นเล็กน้อย
        "label": np.ones(n_mdd),
    }

    df = pd.DataFrame({
        k: np.concatenate([normal_data[k], mdd_data[k]])
        for k in ["delta", "theta", "alpha", "beta", "gamma", "label"]
    })

    # Shuffle
    df = df.sample(frac=1, random_state=42).reset_index(drop=True)

    # Clip ค่าลบ
    for col in FEATURE_COLUMNS:
        df[col] = df[col].clip(lower=0)

    df.to_csv(sample_csv, index=False)
    print(f"   ✅ สร้าง sample dataset: {sample_csv}")
    print(f"   จำนวน: {len(df)} แถว (ปกติ {n_normal} / ซึมเศร้า {n_mdd})")

    return sample_csv


def main():
    parser = argparse.ArgumentParser(
        description="🧠 เทรนโมเดลตรวจจับโรคซึมเศร้าจากคลื่นสมอง EEG"
    )
    parser.add_argument(
        "--csv", type=str, default=None,
        help="พาธไปยังไฟล์ CSV ของ Dataset (คอลัมน์: delta, theta, alpha, beta, gamma, label)"
    )
    parser.add_argument(
        "--sample", action="store_true",
        help="ใช้ dataset ตัวอย่าง (จำลอง) สำหรับทดสอบ pipeline"
    )
    parser.add_argument(
        "--epochs", type=int, default=100,
        help="จำนวน epochs สำหรับเทรน (default: 100)"
    )

    args = parser.parse_args()

    print("=" * 60)
    print("🧠 Depression Detection Model Training")
    print("   Output: Probability (0.0-1.0) → ×100 = คะแนน 0-100")
    print("=" * 60)

    # เลือก dataset
    if args.csv:
        csv_path = args.csv
    elif args.sample:
        csv_path = create_sample_dataset()
    else:
        print("\n⚠️ ไม่ได้ระบุ CSV file!")
        print("   ใช้ --csv path/to/data.csv  สำหรับ dataset จริง")
        print("   ใช้ --sample               สำหรับ dataset ตัวอย่าง (ทดสอบ)")
        print("\n📝 สร้าง sample dataset อัตโนมัติ...\n")
        csv_path = create_sample_dataset()

    # โหลดและเตรียมข้อมูล
    X, y, use_features = load_and_prepare_data(csv_path)

    # เทรนโมเดล
    model, mean, std, features, accuracy = train_model(X, y, use_features)

    # แปลงเป็น TFLite
    convert_to_tflite(model)

    # บันทึก metadata
    print("\n" + "=" * 60)
    print("💾 บันทึก metadata...")
    print("=" * 60)
    save_scaler_params(mean, std, features)
    save_label_info()

    # สรุปผล
    print("\n" + "=" * 60)
    print("🎉 เทรนเสร็จสมบูรณ์!")
    print("=" * 60)
    print(f"   📁 ไฟล์ output ทั้งหมดอยู่ใน: {MODELS_DIR}")
    print(f"   📄 depression_model.tflite   - โมเดลสำหรับ Flutter")
    print(f"   📄 depression_model.keras    - โมเดล Keras (backup)")
    print(f"   📄 depression_scaler.json    - Scaler parameters")
    print(f"   📄 depression_labels.json    - Label & risk level info")
    print(f"   🎯 Test Accuracy: {accuracy * 100:.2f}%")
    print(f"\n   📱 วิธีใช้ในแอป Flutter:")
    print(f"      1. คัดลอกไฟล์ .tflite ไปที่ assets/models/")
    print(f"      2. ส่งค่า EEG (delta, theta, alpha, beta, gamma) เข้าโมเดล")
    print(f"      3. โมเดลคืนค่า probability (0.0-1.0)")
    print(f"      4. นำค่ามาคูณ 100 = คะแนนความเสี่ยงซึมเศร้า 0-100")
    print(f"      5. 0-28 = เสี่ยงต่ำ (เขียว)")
    print(f"         29-48 = ปานกลาง (ส้ม)")
    print(f"         49-100 = เสี่ยงสูง (แดง)")


if __name__ == "__main__":
    main()
