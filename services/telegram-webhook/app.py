from flask import Flask, request, jsonify
import os
import requests
import cloudinary
import cloudinary.uploader
import base64
import firebase_admin
from firebase_admin import credentials, firestore, messaging
import uuid
import json
import math
from datetime import datetime, timezone, timedelta
from dotenv import load_dotenv
from google import genai
from apscheduler.schedulers.background import BackgroundScheduler
import re
import atexit

# Load .env — works locally; Azure uses env vars directly
load_dotenv()

# ── Env vars ──────────────────────────────────────────────────────────────────
TELEGRAM_TOKEN             = os.getenv('TELEGRAM_BOT_TOKEN')
CLOUDINARY_CLOUD_NAME      = os.getenv('CLOUDINARY_CLOUD_NAME')
CLOUDINARY_API_KEY         = os.getenv('CLOUDINARY_API_KEY')
CLOUDINARY_API_SECRET      = os.getenv('CLOUDINARY_API_SECRET')
CLOUDINARY_UPLOAD_PRESET   = os.getenv('CLOUDINARY_UPLOAD_PRESET')
GEMINI_API_KEY             = os.getenv('GEMINI_API_KEY')
AZURE_NOTIFICATION_WEBHOOK_URL = os.getenv('AZURE_NOTIFICATION_WEBHOOK_URL', '')
FIREBASE_CREDS_PATH        = os.getenv('FIREBASE_CREDENTIALS', '')
GEMINI_MODEL               = os.getenv('GEMINI_MODEL', 'gemini-flash-lite-latest')

# ── Cloudinary ────────────────────────────────────────────────────────────────
cloudinary.config(
    cloud_name=CLOUDINARY_CLOUD_NAME,
    api_key=CLOUDINARY_API_KEY,
    api_secret=CLOUDINARY_API_SECRET,
)

# ── Firebase ──────────────────────────────────────────────────────────────────
db = None
firebase_creds_json = os.getenv('FIREBASE_CREDENTIALS_JSON')

try:
    if FIREBASE_CREDS_PATH and os.path.exists(FIREBASE_CREDS_PATH):
        cred = credentials.Certificate(FIREBASE_CREDS_PATH)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase loaded from local JSON file.")
    elif firebase_creds_json:
        cred_dict = json.loads(firebase_creds_json)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase loaded from FIREBASE_CREDENTIALS_JSON env var.")
    else:
        firebase_admin.initialize_app()
        db = firestore.client()
        print("Firebase loaded via Application Default Credentials.")
except Exception as e:
    print(f"CRITICAL: Firebase init failed: {e}")
    db = None

# ── Gemini ────────────────────────────────────────────────────────────────────
genai_client = None
if GEMINI_API_KEY:
    genai_client = genai.Client(api_key=GEMINI_API_KEY)
    print(f"Gemini client ready with model={GEMINI_MODEL}.")
else:
    print("WARNING: GEMINI_API_KEY not set. AI features disabled.")

# ── Flask app ─────────────────────────────────────────────────────────────────
app = Flask(__name__)


# ── Helpers ───────────────────────────────────────────────────────────────────

def haversine(lat1, lon1, lat2, lon2):
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2) + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * (math.sin(dlon / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def send_telegram_message(chat_id, text):
    try:
        url = f'https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage'
        requests.post(url, json={'chat_id': chat_id, 'text': text}, timeout=10)
    except Exception as e:
        print(f"Telegram send failed: {e}")


def send_azure_notification(user_id, title, body, data=None):
    if not AZURE_NOTIFICATION_WEBHOOK_URL:
        return False
    try:
        resp = requests.post(
            AZURE_NOTIFICATION_WEBHOOK_URL,
            json={'userId': user_id, 'title': title, 'body': body, 'data': data or {}},
            timeout=10,
        )
        return 200 <= resp.status_code < 300
    except Exception as e:
        print(f"Azure notification failed: {e}")
        return False


def gemini_generate(prompt):
    """Calls Gemini. Returns text or None."""
    if not genai_client:
        return None
    try:
        resp = genai_client.models.generate_content(model=GEMINI_MODEL, contents=prompt)
        return (resp.text or '').strip() or None
    except Exception as e:
        print(f"Gemini call failed: {e}")
        return None


def generate_impact_statement(task_description, issue_type, affected_count, location_ward):
    fallback = (
        f"This task improved {issue_type.replace('_', ' ')} outcomes for "
        f"about {affected_count} people in {location_ward}."
    )
    prompt = (
        f"In one sentence, describe community impact of: {task_description}, "
        f"issue: {issue_type}, affected: {affected_count} people in {location_ward}."
    )
    return gemini_generate(prompt) or fallback


def register_user(chat_id, ngo_id):
    try:
        db.collection('telegram_links').document(str(chat_id)).set({
            'ngoId': ngo_id,
            'registeredAt': firestore.SERVER_TIMESTAMP,
        })
        send_telegram_message(chat_id, f"Linked to NGO: {ngo_id}. Send photos, voice, CSV, or text now.")
    except Exception as e:
        send_telegram_message(chat_id, f"Link failed: {e}")


def get_linked_ngo(chat_id):
    try:
        doc = db.collection('telegram_links').document(str(chat_id)).get()
        return doc.to_dict().get('ngoId') if doc.exists else None
    except Exception as e:
        print(f"get_linked_ngo failed: {e}")
        return None


def create_text_upload(text_content, ngo_id):
    if len(text_content) > 3000:
        text_content = text_content[:3000] + "\n...[TRUNCATED]"
    public_id = f"sahaya_text_{uuid.uuid4()}"
    data_uri = "data:text/plain;base64," + base64.b64encode(text_content.encode('utf-8')).decode('utf-8')

    if CLOUDINARY_UPLOAD_PRESET:
        upload_result = cloudinary.uploader.unsigned_upload(
            data_uri, CLOUDINARY_UPLOAD_PRESET, resource_type="raw",
            public_id=public_id, filename_override="survey_notes.txt",
        )
    else:
        upload_result = cloudinary.uploader.upload(
            data_uri, resource_type="raw",
            public_id=public_id, filename_override="survey_notes.txt",
        )

    doc_id = str(uuid.uuid4())
    db.collection('raw_uploads').document(doc_id).set({
        'id': doc_id, 'ngoId': ngo_id,
        'cloudinaryUrl': upload_result.get('secure_url'),
        'cloudinaryPublicId': upload_result.get('public_id'),
        'fileType': 'text',
        'uploadedAt': firestore.SERVER_TIMESTAMP,
        'status': 'pending',
    })
    return doc_id


def _run_matching_internal(task_id):
    """Core matching logic — callable without HTTP context."""
    if not db:
        return {'error': 'Firestore not connected'}, 500

    task_doc = db.collection('tasks').document(task_id).get()
    if not task_doc.exists:
        return {'error': 'Task not found'}, 404
    task_data = task_doc.to_dict()
    task_skills = task_data.get('skillTags', [])

    pc_id = task_data.get('problemCardId')
    pc_doc = db.collection('problem_cards').document(pc_id).get()
    if not pc_doc.exists:
        return {'error': 'Orphaned task'}, 404
    pc_data = pc_doc.to_dict()

    pc_geo = pc_data.get('locationGeoPoint')
    pc_lat, pc_lon = (pc_geo.latitude, pc_geo.longitude) if pc_geo else (13.0827, 80.2707)

    volunteers_query = db.collection('volunteer_profiles').where('availabilityWindowActive', '==', True).stream()
    matches = []
    for v_doc in volunteers_query:
        v_data = v_doc.to_dict()
        v_geo = v_data.get('locationGeoPoint')
        if not v_geo:
            continue
        radius_km = float(v_data.get('radiusKm', 10.0))
        dist_km = haversine(v_geo.latitude, v_geo.longitude, pc_lat, pc_lon)
        if dist_km > radius_km + 5.0:
            continue
        normalized_distance = min(dist_km / max(radius_km, 1.0), 1.0)
        v_skills = v_data.get('skillTags', [])
        overlap = len(set(v_skills).intersection(set(task_skills)))
        is_partial = bool(v_data.get('isPartialAvailability', False))
        window_active = bool(v_data.get('availabilityWindowActive', False))
        availability_bonus = 0.05 if is_partial else (0.10 if window_active else 0.0)
        score = (overlap / max(len(task_skills), 1)) * 0.55 + (1.0 - normalized_distance) * 0.35 + availability_bonus
        matches.append({
            'volunteerId': v_doc.id,
            'score': score,
            'distanceKm': round(dist_km, 2),
            'skillOverlap': overlap,
            'availabilityBonus': availability_bonus,
        })

    matches.sort(key=lambda x: x['score'], reverse=True)
    vol_req = int(task_data.get('estimatedVolunteers', 1))
    top_matches = matches[:min(20, max(3, vol_req * 3))]

    bring_prompt = (
        f"In one sentence, what should a volunteer bring for task type: "
        f"{task_data.get('taskType', 'other')}, skill tags: {task_skills}?"
    )
    what_to_bring_text = gemini_generate(bring_prompt) or "Standard volunteering gear."

    batch = db.batch()
    for m in top_matches:
        match_id = str(uuid.uuid4())
        ref = db.collection('match_records').document(match_id)
        batch.set(ref, {
            'id': match_id,
            'taskId': task_id,
            'volunteerId': m['volunteerId'],
            'matchScore': m['score'],
            'distanceKm': m['distanceKm'],
            'skillOverlap': m['skillOverlap'],
            'availabilityBonus': m['availabilityBonus'],
            'status': 'open',
            'missionBriefing': task_data.get('description', 'Mission Briefing'),
            'whatToBring': what_to_bring_text,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
    batch.commit()
    return {'status': 'success', 'matches_generated': len(top_matches)}, 200


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route('/', methods=['GET'])
def index():
    return "Sahaya Backend Live", 200


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'db': db is not None}), 200


@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    if not data or 'message' not in data:
        return jsonify({'status': 'ignored'}), 200

    message = data['message']
    chat_id = message.get('chat', {}).get('id')
    text = message.get('text', '').strip()

    if not chat_id:
        return jsonify({'status': 'error', 'reason': 'No chat id'}), 400

    if text.startswith('/register ') or text.startswith('/start '):
        prefix = '/register ' if text.startswith('/register ') else '/start '
        ngo_id = text.split(prefix, 1)[1].strip()
        register_user(chat_id, ngo_id)
        return jsonify({'status': 'registered'}), 200

    ngo_id = get_linked_ngo(chat_id)
    if not ngo_id:
        send_telegram_message(chat_id, "Send /register <YOUR_NGO_ID> first.")
        return jsonify({'status': 'ignored', 'reason': 'unregistered'}), 200

    file_id = None
    file_type = 'unknown'

    if 'photo' in message:
        file_id = message['photo'][-1]['file_id']
        file_type = 'image'
    elif 'voice' in message:
        file_id = message['voice']['file_id']
        file_type = 'audio'
    elif 'audio' in message:
        file_id = message['audio']['file_id']
        file_type = 'audio'
    elif 'video' in message:
        file_id = message['video']['file_id']
        file_type = 'video'
    elif 'document' in message:
        doc = message['document']
        file_id = doc['file_id']
        mime = doc.get('mime_type', '')
        if mime.startswith('image/'):
            file_type = 'image'
        elif mime in ('text/csv', 'application/csv', 'application/vnd.ms-excel'):
            file_type = 'csv'
        elif mime.startswith('audio/'):
            file_type = 'audio'
        elif mime == 'text/plain':
            file_type = 'text'
        else:
            file_type = 'document'

    if not file_id:
        if text and not text.startswith('/'):
            try:
                doc_id = create_text_upload(text, ngo_id)
                send_telegram_message(chat_id, f"Text queued. ID: {doc_id}")
                return jsonify({'status': 'success', 'docId': doc_id, 'mode': 'text'}), 200
            except Exception as e:
                send_telegram_message(chat_id, "Could not save text. Try again.")
                return jsonify({'status': 'error', 'reason': str(e)}), 500
        return jsonify({'status': 'ignored', 'reason': 'no attachment'}), 200

    res = requests.get(f'https://api.telegram.org/bot{TELEGRAM_TOKEN}/getFile?file_id={file_id}', timeout=10)
    if not res.ok:
        send_telegram_message(chat_id, "Could not fetch file from Telegram.")
        return jsonify({'status': 'error'}), 500

    file_path = res.json()['result']['file_path']
    download_url = f'https://api.telegram.org/file/bot{TELEGRAM_TOKEN}/{file_path}'

    send_telegram_message(chat_id, "Uploading to Cloudinary...")
    try:
        if CLOUDINARY_UPLOAD_PRESET:
            upload_result = cloudinary.uploader.unsigned_upload(download_url, CLOUDINARY_UPLOAD_PRESET, resource_type="auto")
        else:
            upload_result = cloudinary.uploader.upload(download_url, resource_type="auto")
        cloudinary_url = upload_result.get('secure_url')
        cloudinary_public_id = upload_result.get('public_id')
    except Exception as e:
        send_telegram_message(chat_id, f"Upload failed: {e}")
        return jsonify({'status': 'error', 'reason': str(e)}), 500

    doc_id = str(uuid.uuid4())
    try:
        db.collection('raw_uploads').document(doc_id).set({
            'id': doc_id, 'ngoId': ngo_id,
            'cloudinaryUrl': cloudinary_url,
            'cloudinaryPublicId': cloudinary_public_id,
            'fileType': file_type,
            'uploadedAt': firestore.SERVER_TIMESTAMP,
            'status': 'pending',
        })
        send_telegram_message(chat_id, f"Synced. ID: {doc_id}")
    except Exception as e:
        send_telegram_message(chat_id, "Upload OK but Firestore write failed.")
        return jsonify({'status': 'error'}), 500

    return jsonify({'status': 'success', 'docId': doc_id, 'url': cloudinary_url}), 200


@app.route('/generate-tasks', methods=['POST'])
def generate_tasks():
    if not db:
        return jsonify({'status': 'error', 'reason': 'Firestore not initialized'}), 500

    payload = request.json
    if not payload:
        return jsonify({'status': 'error', 'reason': 'Missing body'}), 400

    problem_card_id = payload.get('problemCardId')
    ngo_id = payload.get('ngoId')
    if not problem_card_id or not ngo_id:
        return jsonify({'status': 'error', 'reason': 'problemCardId and ngoId required'}), 400

    try:
        pc_ref = db.collection('problem_cards').document(problem_card_id)
        pc_doc = pc_ref.get()
        if not pc_doc.exists:
            return jsonify({'status': 'error', 'reason': 'ProblemCard not found'}), 404
        pc = pc_doc.to_dict()
    except Exception as e:
        return jsonify({'status': 'error', 'reason': f'Firestore read failed: {e}'}), 500

    description   = pc.get('description', 'No description')
    issue_type    = pc.get('issueType', 'other')
    severity_level = pc.get('severityLevel', 'low')
    affected_count = pc.get('affectedCount', 0)

    task_prompt = (
        f"Community problem: {description}, issue type: {issue_type}, "
        f"severity: {severity_level}, affected: {affected_count}. "
        "Decompose into 1-3 volunteer tasks. Return ONLY a JSON array. "
        "Each object: taskType (data_collection|community_outreach|logistics_coordination|"
        "technical_repair|awareness_session|other), description (max 100 chars), "
        "skillTags (array from: communication,data_entry,transport,technical,medical,"
        "education,physical_labor,community_outreach), estimatedVolunteers (1-5), "
        "estimatedDurationHours (1-8). No extra text."
    )

    raw = gemini_generate(task_prompt)
    tasks_json = None
    if raw:
        try:
            m = re.search(r'\[.*\]', raw, re.DOTALL)
            cleaned = m.group(0) if m else raw.replace('```json', '').replace('```', '').strip()
            tasks_json = json.loads(cleaned)
        except Exception as e:
            print(f"Gemini JSON parse failed: {e}")

    if not tasks_json:
        tasks_json = [{
            'taskType': 'community_outreach',
            'description': f'Address: {description[:80]}',
            'skillTags': ['communication'],
            'estimatedVolunteers': 2,
            'estimatedDurationHours': 4,
        }]

    created_task_ids = []
    for task_data in tasks_json:
        task_id = str(uuid.uuid4())
        task_doc = {
            'id': task_id,
            'problemCardId': problem_card_id,
            'taskType': task_data.get('taskType', 'other'),
            'description': task_data.get('description', 'Volunteer task'),
            'skillTags': task_data.get('skillTags', []),
            'estimatedVolunteers': task_data.get('estimatedVolunteers', 1),
            'estimatedDurationHours': float(task_data.get('estimatedDurationHours', 1)),
            'status': 'open',
            'assignedVolunteerIds': [],
            'locationWard': pc.get('locationWard', 'Unknown Ward'),
            'locationGeoPoint': pc.get('locationGeoPoint'),
            'ngoId': ngo_id,
            'createdAt': firestore.SERVER_TIMESTAMP,
        }
        try:
            db.collection('tasks').document(task_id).set(task_doc)
            created_task_ids.append(task_id)
        except Exception as e:
            print(f"Task write failed {task_id}: {e}")

    # Priority score
    severity_map = {'low': 25, 'medium': 50, 'high': 75, 'critical': 100}
    severity_score = severity_map.get(severity_level, 25)
    affected_normalized = min(affected_count / 100.0, 1.0) * 100

    created_at = pc.get('createdAt')
    hours_since = 0
    if created_at is not None and hasattr(created_at, 'timestamp'):
        try:
            created_dt = created_at.replace(tzinfo=timezone.utc) if created_at.tzinfo is None else created_at
            hours_since = (datetime.now(timezone.utc) - created_dt).total_seconds() / 3600.0
        except Exception:
            pass

    recency_score     = max(0, 100 - (hours_since / 168.0) * 100)
    severity_contrib  = severity_score * 0.35
    scale_contrib     = affected_normalized * 0.30
    recency_contrib   = recency_score * 0.20
    gap_contrib       = 100 * 0.15
    priority_score    = severity_contrib + scale_contrib + recency_contrib + gap_contrib

    try:
        pc_ref.update({
            'priorityScore':   round(priority_score, 2),
            'severityContrib': round(severity_contrib, 2),
            'scaleContrib':    round(scale_contrib, 2),
            'recencyContrib':  round(recency_contrib, 2),
            'gapContrib':      round(gap_contrib, 2),
        })
    except Exception as e:
        print(f"Priority score update failed: {e}")

    # Chain matching directly — no fake HTTP context
    for tid in created_task_ids:
        try:
            result, status = _run_matching_internal(tid)
            print(f"Matching for {tid}: {status}")
        except Exception as e:
            print(f"Matching failed for {tid}: {e}")

    return jsonify({'status': 'success', 'taskIds': created_task_ids, 'priorityScore': round(priority_score, 2)}), 200


@app.route('/run-matching', methods=['POST'])
def run_matching():
    payload = request.json
    task_id = payload.get('taskId') if payload else None
    if not task_id:
        return jsonify({'error': 'Missing taskId'}), 400
    result, status_code = _run_matching_internal(task_id)
    return jsonify(result), status_code


@app.route('/send-availability-reminders', methods=['POST'])
def send_availability_reminders():
    if not db:
        return jsonify({'error': 'Firestore disconnected'}), 500

    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
    notified_count = 0

    try:
        for doc in db.collection('volunteer_profiles').stream():
            v_data = doc.to_dict()
            fcm_token = v_data.get('fcmToken')
            if not fcm_token:
                continue

            window_active = v_data.get('availabilityWindowActive', False)
            updated_at = v_data.get('availabilityUpdatedAt')
            is_stale = True

            if updated_at and hasattr(updated_at, 'replace'):
                try:
                    update_dt = updated_at.replace(tzinfo=timezone.utc) if updated_at.tzinfo is None else updated_at
                    is_stale = update_dt < seven_days_ago
                except Exception:
                    is_stale = True

            if not window_active or is_stale:
                try:
                    messaging.send(messaging.Message(
                        notification=messaging.Notification(
                            title="Available this weekend?",
                            body="Tap to check-in and get matched with nearby community needs.",
                        ),
                        token=fcm_token,
                    ))
                    notified_count += 1
                except Exception as e:
                    print(f"FCM push failed for {doc.id}: {e}")

        return jsonify({'status': 'success', 'notified': notified_count}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/notify-proof-submitted', methods=['POST'])
def notify_proof_submitted():
    data = request.json
    if not data or 'matchRecordId' not in data:
        return jsonify({'error': 'Missing matchRecordId'}), 400

    match_record_id = data['matchRecordId']
    try:
        mr_doc = db.collection('match_records').document(match_record_id).get()
        if not mr_doc.exists:
            return jsonify({'error': 'MatchRecord not found'}), 404
        mr_data = mr_doc.to_dict()

        task_id = mr_data.get('taskId', '')
        task_doc = db.collection('tasks').document(task_id).get()
        task_desc = 'Unknown Task'
        ngo_id = None
        if task_doc.exists:
            task_data = task_doc.to_dict()
            task_desc = task_data.get('description', 'Volunteer Task')
            pc_id = task_data.get('problemCardId', '')
            if pc_id:
                pc_doc = db.collection('problem_cards').document(pc_id).get()
                if pc_doc.exists:
                    ngo_id = pc_doc.to_dict().get('ngoId')

        notif_id = str(uuid.uuid4())
        db.collection('ngo_notifications').document(notif_id).set({
            'id': notif_id,
            'ngoId': ngo_id or 'unknown',
            'type': 'proof_submitted',
            'matchRecordId': match_record_id,
            'taskId': task_id,
            'message': f'Proof submitted for: {task_desc} — tap to review.',
            'read': False,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
        return jsonify({'status': 'success', 'notificationId': notif_id}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/complete-task', methods=['POST'])
def complete_task():
    data = request.json
    if not data or 'matchRecordId' not in data:
        return jsonify({'error': 'Missing matchRecordId'}), 400

    match_record_id = data['matchRecordId']
    try:
        mr_ref = db.collection('match_records').document(match_record_id)
        mr_doc = mr_ref.get()
        if not mr_doc.exists:
            return jsonify({'error': 'MatchRecord not found'}), 404
        mr_data = mr_doc.to_dict()
        task_id = mr_data.get('taskId', '')

        if not task_id:
            return jsonify({'error': 'MatchRecord missing taskId'}), 400
        if mr_data.get('status') != 'proof_approved':
            return jsonify({'error': 'Must be proof_approved first'}), 409
        if mr_data.get('completionCascadeProcessed') is True:
            return jsonify({'status': 'success', 'alreadyProcessed': True, 'impactStatement': mr_data.get('impactStatement', '')}), 200

        task_ref = db.collection('tasks').document(task_id)
        task_doc = task_ref.get()
        if not task_doc.exists:
            return jsonify({'error': 'Task not found'}), 404
        task_data = task_doc.to_dict()
        problem_card_id = task_data.get('problemCardId', '')

        issue_type = 'other'
        affected_count = 0
        location_ward = task_data.get('locationWard', 'Unknown Ward')
        if problem_card_id:
            pc_doc = db.collection('problem_cards').document(problem_card_id).get()
            if pc_doc.exists:
                pc_data = pc_doc.to_dict()
                issue_type = pc_data.get('issueType', issue_type)
                affected_count = int(pc_data.get('affectedCount', 0) or 0)
                location_ward = pc_data.get('locationWard', location_ward)

        impact_statement = generate_impact_statement(
            task_data.get('description', 'Community task'),
            issue_type, affected_count, location_ward,
        )

        current_count = int(task_data.get('completionCount', 0) or 0)
        new_count = current_count + 1
        assigned_ids = task_data.get('assignedVolunteerIds') or []
        est_volunteers = int(task_data.get('estimatedVolunteers', 0) or 0)
        if est_volunteers <= 0:
            est_volunteers = max(len(assigned_ids), 1)

        should_close = new_count >= est_volunteers
        task_updates = {'completionCount': new_count, 'updatedAt': firestore.SERVER_TIMESTAMP}
        if should_close:
            task_updates['status'] = 'done'
            task_updates['completedAt'] = firestore.SERVER_TIMESTAMP
        task_ref.update(task_updates)

        mr_ref.update({
            'completionCascadeProcessed': True,
            'completionCascadeProcessedAt': firestore.SERVER_TIMESTAMP,
            'impactStatement': impact_statement,
        })

        problem_resolved = False
        if should_close and problem_card_id:
            sibling_docs = [d.to_dict() for d in db.collection('tasks').where('problemCardId', '==', problem_card_id).stream()]
            if sibling_docs and all(t.get('status') == 'done' for t in sibling_docs):
                db.collection('problem_cards').document(problem_card_id).update({'status': 'resolved', 'resolvedAt': firestore.SERVER_TIMESTAMP})
                problem_resolved = True

        return jsonify({
            'status': 'success',
            'taskId': task_id,
            'taskCompleted': should_close,
            'completionCount': new_count,
            'estimatedVolunteers': est_volunteers,
            'problemCardResolved': problem_resolved,
            'impactStatement': impact_statement,
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/notify-proof-rejected', methods=['POST'])
def notify_proof_rejected():
    data = request.json
    if not data or 'matchRecordId' not in data:
        return jsonify({'error': 'Missing matchRecordId'}), 400

    match_record_id = data['matchRecordId']
    try:
        mr_doc = db.collection('match_records').document(match_record_id).get()
        if not mr_doc.exists:
            return jsonify({'error': 'MatchRecord not found'}), 404
        mr_data = mr_doc.to_dict()
        volunteer_id = mr_data.get('volunteerId', '')
        reason = mr_data.get('adminReviewNote', 'No reason given')

        if not volunteer_id:
            return jsonify({'error': 'Missing volunteerId'}), 400

        task_id = mr_data.get('taskId', '')
        message = f"Proof not accepted — {reason}. Please resubmit."

        notif_id = str(uuid.uuid4())
        db.collection('volunteer_notifications').document(notif_id).set({
            'id': notif_id,
            'volunteerId': volunteer_id,
            'type': 'proof_rejected',
            'matchRecordId': match_record_id,
            'taskId': task_id,
            'message': message,
            'adminReviewNote': reason,
            'route': {'screen': 'active_task', 'reopenProofSheet': True},
            'read': False,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })

        azure_sent = send_azure_notification(volunteer_id, 'Proof needs revision', message, {
            'type': 'proof_rejected',
            'matchRecordId': match_record_id,
            'taskId': task_id,
            'reopenProofSheet': True,
        })

        fcm_sent = False
        vol_doc = db.collection('volunteer_profiles').document(volunteer_id).get()
        if vol_doc.exists:
            fcm_token = vol_doc.to_dict().get('fcmToken')
            if fcm_token:
                try:
                    messaging.send(messaging.Message(
                        notification=messaging.Notification(title="Proof needs revision", body=message),
                        data={'type': 'proof_rejected', 'matchRecordId': match_record_id, 'taskId': task_id, 'reopenProofSheet': 'true'},
                        token=fcm_token,
                    ))
                    fcm_sent = True
                except Exception as e:
                    print(f"FCM to volunteer failed: {e}")

        return jsonify({'status': 'success', 'notificationId': notif_id, 'azureSent': azure_sent, 'fcmSent': fcm_sent}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── Scheduler — only in main process to avoid multi-worker duplicates ─────────
def _start_scheduler():
    scheduler = BackgroundScheduler(daemon=True)
    scheduler.add_job(
        func=lambda: send_availability_reminders(),
        trigger="cron", day_of_week='fri', hour=12, minute=30,
    )
    scheduler.start()
    atexit.register(lambda: scheduler.shutdown(wait=False))
    print("APScheduler started.")


# Gunicorn sets GUNICORN_WORKER_ID env per worker. Only start scheduler in worker 0.
if os.getenv('GUNICORN_WORKER_ID', '0') == '0' or __name__ == '__main__':
    _start_scheduler()


if __name__ == '__main__':
    app.run(port=8080, host='0.0.0.0', debug=False)
