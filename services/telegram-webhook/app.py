from flask import Flask, request, jsonify
import os
import requests
import cloudinary
import cloudinary.uploader
import firebase_admin
from firebase_admin import credentials, firestore
import uuid
import json
import math
from datetime import datetime, timezone, timedelta
from dotenv import load_dotenv
import google.generativeai as genai
from firebase_admin import messaging
from apscheduler.schedulers.background import BackgroundScheduler

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

def haversine(lat1, lon1, lat2, lon2):
    """Calculates the great-circle mathematically between two literal GPS coordinates universally"""
    R = 6371.0 # Earth Radius in Kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2) + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * (math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

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
            'assignedVolunteerIds': [],
            'locationWard': pc.get('locationWard', 'Unknown Ward'),
            'locationGeoPoint': pc.get('locationGeoPoint')
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

    # 6. Chain Matching Engine directly for every created task
    for target_task_id in created_task_ids:
        try:
            with app.test_request_context('/run-matching', method='POST', json={'taskId': target_task_id}):
                match_res = run_matching()
                print(f"Matching Sweep Native Completion for {target_task_id}: {match_res.status_code}")
        except Exception as e:
            print(f"WARNING: Matching auto-chain cleanly halted for task {target_task_id}: {e}")

    return jsonify({
        'status': 'success',
        'taskIds': created_task_ids,
        'priorityScore': round(priority_score, 2)
    }), 200

@app.route('/run-matching', methods=['POST'])
def run_matching():
    """Generates explicit MatchRecords binding Volunteers to specific community Tasks."""
    if not db:
        return jsonify({'error': 'No Firestore connection natively.'}), 500

    payload = request.json
    task_id = payload.get('taskId') if payload else None
    if not task_id:
        return jsonify({'error': 'Missing taskId'}), 400

    try:
        # 1. Fetch Task and Parent ProblemCard
        task_doc = db.collection('tasks').document(task_id).get()
        if not task_doc.exists:
             return jsonify({'error': 'Task natively dead'}), 404
        task_data = task_doc.to_dict()
        task_skills = task_data.get('skillTags', [])

        pc_id = task_data.get('problemCardId')
        pc_doc = db.collection('problem_cards').document(pc_id).get()
        if not pc_doc.exists:
             return jsonify({'error': 'Orphaned task mapping'}), 404
        pc_data = pc_doc.to_dict()
        
        # Determine Problem GPS - default to Mock Chennai center if unparsed
        pc_geo = pc_data.get('locationGeoPoint')
        if pc_geo:
            pc_lat, pc_lon = pc_geo.latitude, pc_geo.longitude
        else:
            pc_lat, pc_lon = 13.0827, 80.2707
        
        # 2. Query Available Volunteers
        volunteers_query = db.collection('volunteer_profiles').where('availabilityWindowActive', '==', True).stream()
        
        matches = []
        for v_doc in volunteers_query:
             v_data = v_doc.to_dict()
             
             # 3. Location filtering
             v_geo = v_data.get('locationGeoPoint')
             radius_km = float(v_data.get('radiusKm', 10.0))
             if not v_geo:
                 continue
             
             dist_km = haversine(v_geo.latitude, v_geo.longitude, pc_lat, pc_lon)
             if dist_km > radius_km + 5.0: # Giving a slight 5km boundary buffer just mathematically
                 continue
                 
             # 4. Compute algorithm scores
             normalized_distance = min(dist_km / max(radius_km, 1.0), 1.0)
             
             v_skills = v_data.get('skillTags', [])
             overlap = len(set(v_skills).intersection(set(task_skills)))
             
             score = (overlap / max(len(task_skills), 1)) * 0.6 + (1.0 - normalized_distance) * 0.4
             
             matches.append({
                 'volunteerId': v_doc.id,  # uid of the volunteer technically
                 'score': score
             })

        # 5. Write Top 20 Matches
        matches.sort(key=lambda x: x['score'], reverse=True)
        top_matches = matches[:20]
        
        batch = db.batch()
        for m in top_matches:
             match_id = str(uuid.uuid4())
             ref = db.collection('match_records').document(match_id)
             batch.set(ref, {
                 'id': match_id,
                 'taskId': task_id,
                 'volunteerId': m['volunteerId'],
                 'matchScore': m['score'],
                 'status': 'open',
                 'createdAt': firestore.SERVER_TIMESTAMP
             })
             
        batch.commit()
        
        return jsonify({'status': 'success', 'matches_generated': len(top_matches)}), 200

    except Exception as e:
        print(f"Matching Engine Exploded: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'Sahaya Ingestion Pipeline v2'}), 200

@app.route('/send-availability-reminders', methods=['POST'])
def send_availability_reminders():
    """Queries all volunteer profiles and pings them if their availability window is closed or stale"""
    if not db:
       return jsonify({'error': 'Firestore disconnected'}), 500

    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
    notified_count = 0

    try:
        # Since OR queries require index/composite complexity in Firestore, 
        # we pull all active volunteers and evaluate in memory (since volunteer base is small for MVP)
        volunteers_ref = db.collection('volunteer_profiles').stream()
        
        for doc in volunteers_ref:
            v_data = doc.to_dict()
            fcm_token = v_data.get('fcmToken')
            if not fcm_token:
                continue

            # Need check-in if window is natively explicitly closed, or if the update is > 7 days old
            window_active = v_data.get('availabilityWindowActive', False)
            updated_at = v_data.get('availabilityUpdatedAt')
            is_stale = False

            if updated_at:
                 # Check if the timestamp is more than 7 days old
                 if hasattr(updated_at, 'timestamp'):
                     update_dt = updated_at
                 else:
                     update_dt = datetime.now(timezone.utc) # Fallback to avoid crash
                     
                 # Make offset-aware if needed
                 if update_dt.tzinfo is None:
                     update_dt = update_dt.replace(tzinfo=timezone.utc)
                 
                 if update_dt < seven_days_ago:
                     is_stale = True
            else:
                 is_stale = True

            if not window_active or is_stale:
                # Dispatch Push Notification via Firebase Admin SDK
                msg = messaging.Message(
                    notification=messaging.Notification(
                        title="Available this weekend?",
                        body="Tap to check-in and matched with nearby community needs!"
                    ),
                    token=fcm_token
                )
                try:
                    messaging.send(msg)
                    notified_count += 1
                except Exception as e:
                    print(f"Failed to push FCM to {doc.id}: {e}")

        return jsonify({'status': 'success', 'notified': notified_count}), 200
    except Exception as e:
        print(f"Availability sweep exploded natively: {e}")
        return jsonify({'error': str(e)}), 500

# Native Python Scheduler setup
def scheduled_weekly_reminder():
    """Triggered by APScheduler every Friday at 6:00 PM IST (which is 12:30 PM UTC)"""
    print("Initiating automated weekly availability sweep...")
    # Because we are inside the same process, we can just call the sweep directly without HTTP
    # To keep it isolated or if scaled linearly across multiple workers, HTTP POSTing locally is also fine.
    # We will just synthesize the request natively inline here.
    with app.test_request_context('/send-availability-reminders', method='POST'):
         res = send_availability_reminders()
         print(f"Sweep complete natively: {res}")

# Start the background scheduler
scheduler = BackgroundScheduler()
# 12:30 UTC = 18:00 IST (5 hrs 30 mins ahead) everyday on 'fri'
scheduler.add_job(func=scheduled_weekly_reminder, trigger="cron", day_of_week='fri', hour=12, minute=30)
scheduler.start()

if __name__ == '__main__':
    app.run(port=5000, host='0.0.0.0', debug=True)
