from flask import Flask, request, jsonify
import os
import requests
import cloudinary
import cloudinary.uploader
import firebase_admin
from firebase_admin import credentials, firestore
import uuid
import json
from datetime import datetime, timezone
from dotenv import load_dotenv
import google.generativeai as genai

# Load env safely
load_dotenv(dotenv_path='../../.env')

app = Flask(__name__)

# Envs
TELEGRAM_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
CLOUDINARY_CLOUD_NAME = os.getenv('CLOUDINARY_CLOUD_NAME')
CLOUDINARY_API_KEY = os.getenv('CLOUDINARY_API_KEY')
CLOUDINARY_API_SECRET = os.getenv('CLOUDINARY_API_SECRET')
CLOUDINARY_UPLOAD_PRESET = os.getenv('CLOUDINARY_UPLOAD_PRESET')
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')

# Fallback specifically to the key the user verified exists locally!
FIREBASE_CREDS_PATH = os.getenv('FIREBASE_CREDENTIALS', '../../sahaya-7df6d-firebase-adminsdk-fbsvc-8301c19701.json')

cloudinary.config(
  cloud_name = CLOUDINARY_CLOUD_NAME,
  api_key = CLOUDINARY_API_KEY,
  api_secret = CLOUDINARY_API_SECRET
)

# Initialize Firebase Admin SDK
firebase_creds_json = os.getenv('FIREBASE_CREDENTIALS_JSON')

if FIREBASE_CREDS_PATH and os.path.exists(FIREBASE_CREDS_PATH):
    cred = credentials.Certificate(FIREBASE_CREDS_PATH)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("Firebase Admin SDK loaded securely via Local Service Account JSON!")
elif firebase_creds_json:
    print("Azure Explicit Environment Structure caught natively! Instantiating Firebase off string JSON...")
    try:
        cred_dict = json.loads(firebase_creds_json)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase Admin explicitly mounted securely off Azure environment variable!")
    except Exception as e:
        print(f"CRITICAL: Azure JSON structural injection completely failed natively! {e}")
        db = None
else:
    print("Physical service account JSON skipped. Falling back inherently to Cloud Run ADC (Application Default Credentials)...")
    try:
        firebase_admin.initialize_app()
        db = firestore.client()
        print("ADC Native Database mapping explicitly verified.")
    except Exception as e:
        print(f"CRITICAL: ADC completely failed to bind natively! Error: {e}")
        db = None

def send_telegram_message(chat_id, text):
    """Concrete Helper mapping replies instantly to Telegram Chat context."""
    url = f'https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage'
    payload = {'chat_id': chat_id, 'text': text}
    requests.post(url, json=payload)

def register_user(chat_id, ngo_id):
    """Links a physical Telegram chat directly to a structural NGO identity"""
    try:
        db.collection('telegram_links').document(str(chat_id)).set({
            'ngoId': ngo_id,
            'registeredAt': firestore.SERVER_TIMESTAMP
        })
        send_telegram_message(chat_id, f"Success! You are now physically bound to NGO: {ngo_id}. Send photos or CSVs at any time to inject them directly to Cloudinary and Firestore!")
    except Exception as e:
        send_telegram_message(chat_id, f"Database link failed! Error: {e}")

def get_linked_ngo(chat_id):
    """Retrieves the physically resolved NGO matching the sender's device dynamically"""
    doc = db.collection('telegram_links').document(str(chat_id)).get()
    if doc.exists:
        return doc.to_dict().get('ngoId')
    return None

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    if not data or 'message' not in data:
        return jsonify({'status': 'ignored'}), 200
        
    message = data['message']
    chat_id = message.get('chat', {}).get('id')
    text = message.get('text', '').strip()

    if not chat_id:
        return jsonify({'status': 'error', 'reason': 'Unknown Chat Id'}), 400

    # Concrete Logic 1. Check for incoming text/registration commands natively explicitly
    if text.startswith('/register ') or text.startswith('/start '):
        cmd_prefix = '/register ' if text.startswith('/register ') else '/start '
        ngo_id = text.split(cmd_prefix)[1].strip()
        register_user(chat_id, ngo_id)
        return jsonify({'status': 'success', 'context': 'registered'}), 200
    
    # Concrete Logic 2. If it is NOT a command, ensure they have a linked NGO!
    ngo_id = get_linked_ngo(chat_id)
    if not ngo_id:
        send_telegram_message(chat_id, "Welcome to the Sahaya Field Bot!\n\nYou must securely map your phone to your organization first.\nPlease reply with: `/register <YOUR_NGO_ID>`")
        return jsonify({'status': 'ignored', 'reason': 'unregistered_device'}), 200

    # Concrete Logic 3. Proceed to Pipeline attachment processing
    file_id = None
    file_type = 'unknown'

    if 'photo' in message:
        photo = message['photo'][-1]
        file_id = photo['file_id']
        file_type = 'image'
    elif 'document' in message:
        doc = message['document']
        file_id = doc['file_id']
        mime_type = doc.get('mime_type', '')
        if mime_type.startswith('image/'):
            file_type = 'image'
        elif mime_type in ['text/csv', 'application/csv', 'application/vnd.ms-excel']:
            file_type = 'csv'
        else:
            file_type = 'document'
            
    if not file_id:
        # Ignore random texts if they are just chatting to the bot
        if not text.startswith('/'):
          send_telegram_message(chat_id, "I only process Photos or Data CSVs currently. Please attach a structural payload!")
        return jsonify({'status': 'ignored', 'reason': 'no attachments'}), 200

    # 4. Request internal File URI from Telegram servers
    get_file_url = f'https://api.telegram.org/bot{TELEGRAM_TOKEN}/getFile?file_id={file_id}'
    res = requests.get(get_file_url)
    if not res.ok:
        send_telegram_message(chat_id, "Failed to resolve file path from Telegram!")
        return jsonify({'status': 'error'}), 500
        
    file_path = res.json()['result']['file_path']
    download_url = f'https://api.telegram.org/file/bot{TELEGRAM_TOKEN}/{file_path}'

    # 5. Cloudinary Upload Phase
    send_telegram_message(chat_id, "Received payload! Transmitting to Cloudinary servers...")
    try:
        if CLOUDINARY_UPLOAD_PRESET:
            upload_result = cloudinary.uploader.unsigned_upload(
                download_url,
                CLOUDINARY_UPLOAD_PRESET,
                resource_type="auto"
            )
        else:
            print("WARNING: Unsigned preset not injected, attempting signed structural fallback.")
            upload_result = cloudinary.uploader.upload(
                download_url,
                resource_type="auto"
            )
        
        cloudinary_url = upload_result.get('secure_url')
        cloudinary_public_id = upload_result.get('public_id')
    except Exception as e:
        err = f"Cloudinary Upload pipeline broke natively: {e}"
        print(err)
        send_telegram_message(chat_id, err)
        return jsonify({'status': 'error', 'reason': str(e)}), 500

    # 6. Database Persist
    doc_id = str(uuid.uuid4())
    upload_doc = {
        'id': doc_id,
        'ngoId': ngo_id,
        'cloudinaryUrl': cloudinary_url,
        'cloudinaryPublicId': cloudinary_public_id,
        'fileType': file_type,
        'uploadedAt': firestore.SERVER_TIMESTAMP,
        'status': 'pending'
    }

    try:
        db.collection('raw_uploads').document(doc_id).set(upload_doc)
        print(f"Logged ID: {doc_id} mapped natively to {ngo_id}")
        send_telegram_message(chat_id, f"✅ Fully synchronized to Sahaya Cloud!\nDatabase ID: {doc_id}")
    except Exception as e:
        print(f"Firestore save rejected natively: {e}")
        send_telegram_message(chat_id, "Cloudinary upload succeeded, but Firestore registration crashed locally!")
        return jsonify({'status': 'error'}), 500
            
    return jsonify({'status': 'success', 'docId': doc_id, 'url': cloudinary_url}), 200

@app.route('/generate-tasks', methods=['POST'])
def generate_tasks():
    """Accepts an approved ProblemCard, decomposes it into volunteer tasks via Gemini,
    computes a priority score, and writes everything back to Firestore."""
    if not db:
        return jsonify({'status': 'error', 'reason': 'Firestore not initialized'}), 500

    payload = request.json
    if not payload:
        return jsonify({'status': 'error', 'reason': 'Missing JSON body'}), 400

    problem_card_id = payload.get('problemCardId')
    ngo_id = payload.get('ngoId')
    if not problem_card_id or not ngo_id:
        return jsonify({'status': 'error', 'reason': 'problemCardId and ngoId are required'}), 400

    # 1. Read the ProblemCard from Firestore
    try:
        pc_ref = db.collection('problem_cards').document(problem_card_id)
        pc_doc = pc_ref.get()
        if not pc_doc.exists:
            return jsonify({'status': 'error', 'reason': f'ProblemCard {problem_card_id} not found'}), 404
        pc = pc_doc.to_dict()
    except Exception as e:
        return jsonify({'status': 'error', 'reason': f'Firestore read failed: {e}'}), 500

    # 2. Call Gemini to decompose the problem into volunteer tasks
    description = pc.get('description', 'No description')
    issue_type = pc.get('issueType', 'other')
    severity_level = pc.get('severityLevel', 'low')
    affected_count = pc.get('affectedCount', 0)

    task_prompt = f"""Given this community problem: {description}, issue type: {issue_type}, severity: {severity_level}, affected count: {affected_count} — decompose into 1 to 3 concrete volunteer tasks. Return ONLY a JSON array. Each task object: taskType (one of: data_collection, community_outreach, logistics_coordination, technical_repair, awareness_session, other), description (max 100 chars), skillTags (array from: communication, data_entry, transport, technical, medical, education, physical_labor, community_outreach), estimatedVolunteers (integer 1-5), estimatedDurationHours (integer 1-8). No other text."""

    created_task_ids = []

    try:
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel('gemini-flash-lite-latest')
        response = model.generate_content(task_prompt)
        raw_text = response.text.strip()
        raw_text = raw_text.replace('```json', '').replace('```', '').strip()
        tasks_json = json.loads(raw_text)
    except Exception as e:
        print(f'Gemini task decomposition failed: {e}')
        # Fallback: generate a single generic task so the pipeline doesn't break
        tasks_json = [{
            'taskType': 'community_outreach',
            'description': f'Investigate and address: {description[:80]}',
            'skillTags': ['communication'],
            'estimatedVolunteers': 2,
            'estimatedDurationHours': 4
        }]

    # 3. Write each task to Firestore
    for task_data in tasks_json:
        task_id = str(uuid.uuid4())
        task_type_str = task_data.get('taskType', 'other')
        skill_tags = task_data.get('skillTags', [])
        est_volunteers = task_data.get('estimatedVolunteers', 1)
        est_duration = task_data.get('estimatedDurationHours', 1)
        task_desc = task_data.get('description', 'Volunteer task')

        task_doc = {
            'id': task_id,
            'problemCardId': problem_card_id,
            'taskType': task_type_str,
            'description': task_desc,
            'skillTags': skill_tags,
            'estimatedVolunteers': est_volunteers,
            'estimatedDurationHours': float(est_duration),
            'status': 'open',
            'assignedVolunteerIds': []
        }

        try:
            db.collection('tasks').document(task_id).set(task_doc)
            created_task_ids.append(task_id)
        except Exception as e:
            print(f'Failed to write task {task_id}: {e}')

    # 4. Compute priority score components
    severity_map = {'low': 25, 'medium': 50, 'high': 75, 'critical': 100}
    severity_score = severity_map.get(severity_level, 25)

    affected_normalized = min(affected_count / 100.0, 1.0) * 100

    # Recency: linear decay from 100 at 0 hours to 0 at 168 hours (7 days)
    created_at = pc.get('createdAt')
    if created_at is not None:
        if hasattr(created_at, 'timestamp'):
            created_dt = created_at
        else:
            created_dt = datetime.now(timezone.utc)
        hours_since = (datetime.now(timezone.utc) - created_dt).total_seconds() / 3600.0
    else:
        hours_since = 0
    recency_score = max(0, 100 - (hours_since / 168.0) * 100)

    # Volunteer gap: 100 if zero volunteers assigned, 0 otherwise
    volunteer_gap_score = 100  # Initially no volunteers assigned

    # Weighted composite
    severity_contrib = severity_score * 0.35
    scale_contrib = affected_normalized * 0.30
    recency_contrib = recency_score * 0.20
    gap_contrib = volunteer_gap_score * 0.15
    priority_score = severity_contrib + scale_contrib + recency_contrib + gap_contrib

    # 5. Write priority scores back to ProblemCard
    try:
        pc_ref.update({
            'priorityScore': round(priority_score, 2),
            'severityContrib': round(severity_contrib, 2),
            'scaleContrib': round(scale_contrib, 2),
            'recencyContrib': round(recency_contrib, 2),
            'gapContrib': round(gap_contrib, 2)
        })
    except Exception as e:
        print(f'Failed to update priority score: {e}')

    return jsonify({
        'status': 'success',
        'taskIds': created_task_ids,
        'priorityScore': round(priority_score, 2)
    }), 200


@app.route('/', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'Sahaya Ingestion Pipeline v2'}), 200

if __name__ == '__main__':
    app.run(port=5000, host='0.0.0.0', debug=True)
