# 🚀 คู่มือการตั้งค่า Supabase สำหรับ SmartBrain Care

## ภาพรวมระบบ

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SmartBrain Care Architecture                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────┐           ┌─────────────────────────────┐   │
│  │  Flutter Mobile App │           │    Supabase Platform        │   │
│  │                     │           │                             │   │
│  │  ┌───────────────┐  │  SDK Auth │  ┌─────────────────────┐    │   │
│  │  │ User Interface│  │◄─────────►│  │   Supabase Auth     │    │   │
│  │  └───────────────┘  │           │  │  (Login/Register)   │    │   │
│  │                     │           │  └─────────────────────┘    │   │
│  │  ┌───────────────┐  │           │                             │   │
│  │  │ MuseService   │  │           │  ┌─────────────────────┐    │   │
│  │  │ (Bluetooth)   │  │  Direct   │  │  PostgreSQL DB      │    │   │
│  │  └───────────────┘  │  Insert   │  │  • users            │    │   │
│  │         │           │◄─────────►│  │  • brainwave_data   │    │   │
│  │         ▼           │           │  │  • schedules        │    │   │
│  │  ┌───────────────┐  │           │  │  • activities       │    │   │
│  │  │ FFTCalculator │  │           │  │  • test_results     │    │   │
│  │  └───────────────┘  │           │  └─────────────────────┘    │   │
│  │         │           │           │                             │   │
│  │         ▼           │           │  ┌─────────────────────┐    │   │
│  │  ┌───────────────┐  │  Invoke   │  │   Edge Functions    │────┼───┐
│  │  │SupabaseService│  │  Function │  │  (ChatGPT API)      │    │   │
│  │  └───────────────┘  │◄─────────►│  └─────────────────────┘    │   │
│  │                     │           │                             │   │
│  │  ┌───────────────┐  │           └─────────────────────────────┘   │
│  │  │  TTSService   │  │                                             │
│  │  └───────────────┘  │                        ▼                    │
│  │                     │           ┌─────────────────────────────┐   │
│  └─────────────────────┘           │      OpenAI API (GPT-4o)    │   │
│                                    └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📋 ขั้นตอนการตั้งค่า

### ขั้นตอนที่ 1: สร้าง Supabase Project

1. ไปที่ **[https://supabase.com](https://supabase.com)**
2. สร้างบัญชีหรือ Login ด้วย GitHub
3. กด **"New Project"**
4. ตั้งค่า:
   - **Name**: SmartBrain Care
   - **Database Password**: (จดไว้ให้ดี)
   - **Region**: Southeast Asia (Singapore)
5. รอประมาณ 2 นาทีจนสร้างเสร็จ

---

### ขั้นตอนที่ 2: รับ API Keys

1. ไปที่ **Settings** (ไอคอนเฟือง) > **API**
2. คัดลอกค่าต่อไปนี้:

| ค่า | ตำแหน่ง | ตัวอย่าง |
|-----|---------|----------|
| **Project URL** | Project URL | `https://xxxxx.supabase.co` |
| **anon/public key** | Project API keys > anon | `eyJhbGciOiJI...` |

---

### ขั้นตอนที่ 3: สร้างตารางใน Database

1. ไปที่ **SQL Editor** (ไอคอนฐานข้อมูล)
2. กด **"New query"**
3. คัดลอก SQL จากไฟล์ `supabase/migrations/001_initial_schema.sql`
4. กด **"Run"** (หรือ Cmd+Enter)
5. ตรวจสอบที่ **Table Editor** ว่ามีตารางครบ 7 ตาราง:
   - `users`
   - `user_settings`
   - `brainwave_data`
   - `test_results`
   - `activities`
   - `schedules`
   - `chat_messages`

---

### ขั้นตอนที่ 4: ตั้งค่าใน Flutter App

แก้ไขไฟล์ `lib/services/supabase_service.dart`:

```dart
// บรรทัด 8-9
static const String supabaseUrl = 'https://xxxxx.supabase.co';  // ← ใส่ Project URL
static const String supabaseAnonKey = 'eyJhbGciOiJI...';         // ← ใส่ anon key
```

**⚠️ สำคัญ**: 
- เปลี่ยน `YOUR_SUPABASE_URL` เป็น URL จริงจาก Supabase
- เปลี่ยน `YOUR_SUPABASE_ANON_KEY` เป็น anon key จริง

---

### ขั้นตอนที่ 5: ทดสอบการเชื่อมต่อ

1. Run app:
```bash
cd brain_wave_flutter
flutter run
```

2. ลองสมัครสมาชิกใหม่
3. ตรวจสอบที่ **Table Editor > users** ว่ามีข้อมูลเพิ่มขึ้น

---

## 📊 โครงสร้าง Database

### ตาราง `users`
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary Key |
| username | VARCHAR(100) | ชื่อผู้ใช้ (unique) |
| password | VARCHAR(255) | รหัสผ่าน |
| full_name | VARCHAR(255) | ชื่อ-นามสกุล |
| email | VARCHAR(255) | อีเมล |
| phone | VARCHAR(20) | เบอร์โทร |
| birth_date | DATE | วันเกิด |
| avatar_url | VARCHAR(500) | URL รูปโปรไฟล์ |

### ตาราง `brainwave_data`
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary Key |
| user_id | INTEGER | Foreign Key -> users |
| alpha_wave | REAL | Alpha (8-13 Hz) - Relaxation |
| beta_wave | REAL | Beta (13-30 Hz) - Focus |
| theta_wave | REAL | Theta (4-8 Hz) - Meditation |
| delta_wave | REAL | Delta (0.5-4 Hz) - Sleep |
| gamma_wave | REAL | Gamma (30-100 Hz) - Cognition |
| attention_score | REAL | คะแนนสมาธิ (0-100) |
| meditation_score | REAL | คะแนนสมาธิ (0-100) |
| device_name | VARCHAR(100) | ชื่ออุปกรณ์ (Muse S/Muse 2) |

### ตาราง `test_results`
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary Key |
| user_id | INTEGER | Foreign Key -> users |
| stress_score | INTEGER | คะแนนความเครียด |
| depression_score | INTEGER | คะแนนซึมเศร้า |
| stress_level | VARCHAR(50) | ระดับ: normal/mild/moderate/severe |

### ตาราง `schedules`
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary Key |
| user_id | INTEGER | Foreign Key -> users |
| title | VARCHAR(255) | ชื่อกิจกรรม |
| description | TEXT | รายละเอียด |
| time | VARCHAR(10) | เวลา (HH:mm) |
| icon_name | VARCHAR(50) | ชื่อ icon (Material Icons) |
| color | VARCHAR(50) | สี |
| is_completed | BOOLEAN | เสร็จแล้วหรือยัง |

### ตาราง `activities`
| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary Key |
| user_id | INTEGER | Foreign Key -> users |
| activity_type | VARCHAR(50) | ประเภท: meditation/breathing/game |
| activity_name | VARCHAR(255) | ชื่อกิจกรรม |
| score | INTEGER | คะแนนที่ได้ |
| duration_minutes | INTEGER | ระยะเวลา (นาที) |

---

## 🔧 การตั้งค่า Edge Function สำหรับ ChatGPT (Optional)

สำหรับใช้ ChatGPT AI Chatbot ต้องสร้าง Edge Function:

### 1. ติดตั้ง Supabase CLI
```bash
npm install -g supabase
```

### 2. Login และ Link Project
```bash
supabase login
supabase link --project-ref <your-project-ref>
```

### 3. สร้าง Edge Function
```bash
supabase functions new chatgpt
```

### 4. แก้ไขไฟล์ `supabase/functions/chatgpt/index.ts`:
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')

serve(async (req) => {
  const { message, chat_history } = await req.json()

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'คุณเป็นผู้เชี่ยวชาญด้านคลื่นสมองและสุขภาพจิต ให้คำปรึกษาเป็นภาษาไทย'
        },
        ...chat_history,
        { role: 'user', content: message }
      ],
    }),
  })

  const data = await response.json()
  
  return new Response(
    JSON.stringify({ 
      success: true, 
      ai_response: data.choices[0].message.content 
    }),
    { headers: { "Content-Type": "application/json" } },
  )
})
```

### 5. Deploy Function
```bash
supabase functions deploy chatgpt
```

### 6. ตั้งค่า Secret
```bash
supabase secrets set OPENAI_API_KEY=sk-xxxxx
```

---

## ❓ การแก้ไขปัญหา

### ปัญหา: "Supabase client not initialized"
**แก้ไข**: ตรวจสอบว่า `main.dart` มีการเรียก `await SupabaseService.initialize()` ก่อน `runApp()`

### ปัญหา: "PostgrestException: relation does not exist"
**แก้ไข**: ตรวจสอบว่าได้รัน SQL สร้างตารางแล้ว

### ปัญหา: "permission denied for table"
**แก้ไข**: ตรวจสอบว่าได้สร้าง RLS Policies แล้ว (อยู่ใน SQL ไฟล์)

### ปัญหา: Connection timeout
**แก้ไข**: 
- ตรวจสอบ URL และ API Key
- ตรวจสอบ internet connection
- ตรวจสอบว่า project ไม่ได้ paused (free tier จะ pause หลัง 1 สัปดาห์ไม่ใช้งาน)

---

## 🔔 การตั้งค่า Edge Function สำหรับ Caregiver Mode (FCM Push Notification)

เพื่อให้แอปส่งการแจ้งเตือนไปยังผู้ดูแล (Caregiver) ได้จริง ต้องตั้งค่าการส่งผ่าน Edge Function ด้วย Firebase Service Account:

### 1. รับไฟล์ Service Account JSON จาก Firebase
1. ไปที่ [Firebase Console](https://console.firebase.google.com/) ของโปรเจกต์คุณ (`smart-brain-care`)
2. ไปที่ **Project settings** (รูปเฟือง) > **Service accounts**
3. เลือก **Generate new private key** เพื่อดาวน์โหลดไฟล์ `.json`

### 2. นำข้อมูลจากไฟล์ JSON ไปใส่ในระบบ Environment (Vault) ของ Supabase
เนื่องจากการเรียกใช้งาน FCM v1 ต้องใช้การทำ OAuth2 Auth จาก Service Account เราขอแนะนำให้นำค่าจากไฟล์ JSON ไปตั้งเป็น Secret Variables (หรือใน Supabase Vault):

```bash
# ตั้งค่า FIREBASE_PROJECT_ID
supabase secrets set FIREBASE_PROJECT_ID="smart-brain-care"

# (สำคัญ) ต้องมีการประยุกต์ใช้ Library (เช่น google-auth-library) เพื่อแปลง 
# Service Account เป็น OAuth Token ก่อนยิง FCM API ใน index.ts หรือ 
# ถ้าต้องการทดสอบ สามารถเจน Access Token ชั่วคราวมาใส่ตัวแปร FIREBASE_OAUTH_TOKEN ได้:
supabase secrets set FIREBASE_OAUTH_TOKEN="ya29.c.c0AY_VpZ..."
```

### 3. Deploy Edge Function ตัวใหม่
ระบบมี Edge Function `send_fcm_notification` ให้แล้ว สั่ง Deploy โดยใช้คำสั่ง:
```bash
supabase functions deploy send_fcm_notification
```

เมื่อเพื่อนของคุณรับช่วงต่อ ให้ศึกษาเรื่อง "FCM HTTP v1 API using Deno Edge Functions" ซึ่งสามารถอ่านไฟล์ JSON จาก Secret แล้วใช้สร้าง Bearer Token ได้โดยตรงใน `index.ts`

---

## 🎉 เสร็จสิ้น!

เมื่อตั้งค่าครบแล้ว app จะ:
- ✅ Connect กับ Supabase Database โดยตรง (ไม่ต้อง XAMPP)
- ✅ บันทึกข้อมูลผู้ใช้และ brainwave data
- ✅ ดึงข้อมูลแบบ real-time
- ✅ ทำงานได้จากทุกที่ทุกเวลา (Cloud-based)
