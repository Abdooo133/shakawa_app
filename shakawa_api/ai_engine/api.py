import os
import re
import json
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import google.generativeai as genai

# ============================================================
# 🔑 المفاتيح
# ============================================================
def get_api_keys():
    return [
        os.getenv("GEMINI_KEY_1"),
        os.getenv("GEMINI_KEY_2"),
        os.getenv("GEMINI_KEY_3"),
        os.getenv("GEMINI_KEY_4"),
        os.getenv("GEMINI_KEY_5"),
    ]

# ============================================================
# 🧹 تنظيف النص العربي
# ============================================================
def clean_arabic_text(text):
    text = str(text)
    text = re.sub(r'[^\u0600-\u06FF\s]', '', text)
    text = re.sub(r'[أإآ]', 'ا', text)
    text = re.sub(r'ة', 'ه', text)
    text = re.sub(r'ى', 'ي', text)
    return text

# ============================================================
# 🤖 تحميل موديل التصنيف
# ============================================================
model = joblib.load('shakawa_model.pkl')

app = FastAPI()

# ============================================================
# 🌐 CORS
# ============================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================
# 📦 نموذج البيانات
# ============================================================
class Complaint(BaseModel):
    text: str
    customer_name: str = "يا غالي"
    lang: str = "ar"

# ============================================================
# 🚀 الـ Endpoint الرئيسي
# ============================================================
@app.post("/chatbot")
async def shakawa_bot(item: Complaint):
    API_KEYS = get_api_keys()
    text = item.text.strip()
    customer_name = item.customer_name.strip()

    # ----------------------------------------------------------
    # المسار الأول: متابعة شكوى
    # ----------------------------------------------------------
    track_keywords = ["اتابع", "متابعة", "اراجع", "مراجعة", "اعرف حالة", "اعرف عن", "اعرف عن شكوى", "اعرف عن الشكوى", "اعرف عن الشكوى رقم", "اعرف عن شكوى رقم"]
    if any(word in text for word in track_keywords):
        if any(char.isdigit() for char in text):
            comp_id = ''.join(filter(str.isdigit(), text))
            return {
                "reply": f"تمام يا {customer_name}، هحولك لصفحة المتابعة عشان نشوف حالة الشكوى رقم #{comp_id} 🔍",
                "type": "go_to_track",
                "id": comp_id,
                "category": "",
                "description": text
            }
        # return {
        #     "reply": f"تمام يا {customer_name}! 😊 معاك رقم الشكوى؟ بعتهولي وهشوفها على طول.",
        #     "type": "text",
        #     "id": "",
        #     "category": "",
        #     "description": text
        # }

    # ----------------------------------------------------------
    # المسار الثاني: تصنيف بالموديل
    # ----------------------------------------------------------
    cleaned_text = clean_arabic_text(text)
    prediction = model.predict([cleaned_text])[0]

    # ----------------------------------------------------------
    # المسار الثالث: Structured Output من جيمي
    # ----------------------------------------------------------
    prompt = f"""أنت 'جيمي'، مساعد ذكي ومصري جدع لخدمة عملاء تطبيق 'شكاوى' لشركات الاتصالات.
اسم العميل: '{customer_name}'
العميل يقول: '{text}'
التصنيف المبدئي للنظام: '{prediction}'

أهدافك:
1. رحّب بالعميل باسمه بأسلوب ودود.
2. تكلم بلهجة مصرية طبيعية ومحترفة.
3. لو مشكلة تقنية بسيطة، قدم نصيحة سريعة.
4. لو شكوى صريحة تحتاج تدخل، لخّصها وصنّفها.

قاعدة إجبارية: ردك يكون JSON صحيح فقط بدون أي نص خارجه، بالمفاتيح دي حصراً:
- 'reply': رسالتك للعميل.
- 'type': واحد من دول فقط:
    'text'       → دردشة عادية أو استفسار.
    'complaint'  → مشكلة تحتاج تسجيل شكوى (هيظهرله زر تسجيل).
    'go_to_form' → مشكلة معقدة جداً تحتاج نموذج الشكوى الكامل.
- 'category': فئة المشكلة لو type=complaint، وإلا "".
- 'description': تلخيص موجز لو type=complaint، وإلا "".
- 'id': "" دائماً.

أمثلة:
شكوى: {{"reply": "بعتذرلك يا {customer_name} عن عطل النت. تحب أسجلك شكوى دلوقتي؟", "type": "complaint", "category": "إنترنت", "description": "انقطاع متكرر في الإنترنت", "id": ""}}
دردشة: {{"reply": "أهلاً يا {customer_name}! كيف أقدر أساعدك؟ 😊", "type": "text", "category": "", "description": "", "id": ""}}
توجيه: {{"reply": "المشكلة دي محتاجة متابعة متخصصة يا {customer_name}، هوديك لنموذج الشكوى الكامل.", "type": "go_to_form", "category": "", "description": "", "id": ""}}"""

    dynamic_reply = ""
    reply_type = "text"
    category = prediction
    description = text

    for key in API_KEYS:
        if not key:
            continue
        try:
            genai.configure(api_key=key)
            llm = genai.GenerativeModel('gemini-2.5-flash')
            response = llm.generate_content(prompt)
            raw = response.text.strip()

            # تنظيف لو جاء مع markdown
            clean = re.sub(r'```json|```', '', raw).strip()

            # parse الـ JSON
            parsed = json.loads(clean)
            dynamic_reply = parsed.get('reply', '')
            reply_type    = parsed.get('type', 'text')
            category      = parsed.get('category', prediction)
            description   = parsed.get('description', text)

            # تأكد إن الـ type صحيح
            if reply_type not in ['text', 'complaint', 'go_to_form', 'go_to_track']:
                reply_type = 'text'

            break

        except json.JSONDecodeError:
            # جيمي مردش JSON صح — استخدم الرد كـ text
            dynamic_reply = raw
            reply_type = "text"
            break
        except Exception as e:
            print(f"❌ مفتاح فيه مشكلة: {e}")
            continue

    # لو كل المفاتيح فشلت
    if not dynamic_reply:
        dynamic_reply = f"معلش يا {customer_name}، السيرفر عليه ضغط دلوقتي. هحولك لصفحة تقديم الشكوى."
        reply_type = "go_to_form"

    return {
        "reply": dynamic_reply,
        "type": reply_type,
        "id": "",
        "category": category,
        "description": description
    }
