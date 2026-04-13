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
import hashlib
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

ALLOWED_ISSUE_TYPES = {
    'sdg1_no_poverty',
    'sdg2_zero_hunger',
    'sdg3_good_health_and_well_being',
    'sdg4_quality_education',
    'sdg5_gender_equality',
    'sdg6_clean_water_and_sanitation',
    'sdg7_affordable_and_clean_energy',
    'sdg8_decent_work_and_economic_growth',
    'sdg9_industry_innovation_and_infrastructure',
    'sdg10_reduced_inequalities',
    'sdg11_sustainable_cities_and_communities',
    'sdg12_responsible_consumption_and_production',
    'sdg13_climate_action',
    'sdg14_life_below_water',
    'sdg15_life_on_land',
    'sdg16_peace_justice_and_strong_institutions',
    'sdg17_partnerships_for_the_goals',
}
ALLOWED_SEVERITY = {'low', 'medium', 'high', 'critical'}

LEGACY_ISSUE_TYPE_MAP = {
    'water_access': 'sdg6_clean_water_and_sanitation',
    'sanitation': 'sdg6_clean_water_and_sanitation',
    'education': 'sdg4_quality_education',
    'nutrition': 'sdg2_zero_hunger',
    'healthcare': 'sdg3_good_health_and_well_being',
    'livelihood': 'sdg8_decent_work_and_economic_growth',
    'other': 'sdg11_sustainable_cities_and_communities',
}

ALLOWED_TASK_TYPES = {
    'data_collection',
    'community_outreach',
    'logistics_coordination',
    'technical_repair',
    'awareness_session',
    'other',
}

ALLOWED_TASK_SKILLS = {
    'communication',
    'data_entry',
    'transport',
    'technical',
    'medical',
    'education',
    'physical_labor',
    'community_outreach',
}


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


def _safe_int(value, default=0, min_value=0, max_value=100000):
    try:
        n = int(value)
    except Exception:
        n = default
    return max(min_value, min(n, max_value))


def _safe_float(value, default=0.0, min_value=0.0, max_value=100000.0):
    try:
        n = float(value)
    except Exception:
        n = default
    return max(min_value, min(n, max_value))


def _norm_text(value):
    if value is None:
        return ''
    return re.sub(r'\s+', ' ', str(value).strip().lower())


def _normalize_issue_type(value):
    key = _norm_text(value)
    if key in ALLOWED_ISSUE_TYPES:
        return key
    if key in LEGACY_ISSUE_TYPE_MAP:
        return LEGACY_ISSUE_TYPE_MAP[key]
    return 'sdg11_sustainable_cities_and_communities'


def _near_duplicate_score(a, b):
    tokens_a = set(re.findall(r'[a-z0-9]+', _norm_text(a)))
    tokens_b = set(re.findall(r'[a-z0-9]+', _norm_text(b)))
    if not tokens_a and not tokens_b:
        return 0.0
    inter = len(tokens_a.intersection(tokens_b))
    union = max(1, len(tokens_a.union(tokens_b)))
    return inter / union


def _fingerprint(*parts):
    joined = '||'.join(_norm_text(p) for p in parts)
    return hashlib.sha256(joined.encode('utf-8')).hexdigest()[:24]


def _log_quality_event(event_type, severity='info', ngo_id=None, related=None, flags=None, details=None):
    if not db:
        return
    try:
        event_id = str(uuid.uuid4())
        db.collection('quality_events').document(event_id).set({
            'id': event_id,
            'eventType': event_type,
            'severity': severity,
            'ngoId': ngo_id,
            'related': related or {},
            'flags': flags or [],
            'details': details or {},
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
    except Exception as e:
        print(f"quality event log failed: {e}")


def _check_recent_text_duplicate(ngo_id, upload_fingerprint, hours=48):
    if not db or not upload_fingerprint:
        return False
    try:
        threshold = datetime.now(timezone.utc) - timedelta(hours=hours)
        candidates = db.collection('raw_uploads') \
            .where('ngoId', '==', ngo_id) \
            .where('uploadFingerprint', '==', upload_fingerprint) \
            .stream()
        for doc in candidates:
            d = doc.to_dict() or {}
            ts = d.get('uploadedAt')
            if ts and hasattr(ts, 'replace'):
                t = ts.replace(tzinfo=timezone.utc) if ts.tzinfo is None else ts
                if t >= threshold:
                    return True
        return False
    except Exception as e:
        print(f"duplicate check failed: {e}")
        return False


def _check_problem_duplicate(problem_card_id, ngo_id, issue_type, ward, city, description):
    if not db:
        return False, ''
    fp = _fingerprint(issue_type, ward, city, description)
    try:
        candidates = db.collection('problem_cards') \
            .where('ngoId', '==', ngo_id) \
            .where('dupFingerprint', '==', fp) \
            .limit(5) \
            .stream()
        for doc in candidates:
            if doc.id != problem_card_id:
                return True, fp
        return False, fp
    except Exception as e:
        print(f"problem duplicate check failed: {e}")
        return False, fp


def _check_problem_near_duplicates(problem_card_id, ngo_id, issue_type, ward, city, description, limit=30):
    if not db:
        return []
    results = []
    try:
        stream = db.collection('problem_cards').where('ngoId', '==', ngo_id).order_by('createdAt', direction=firestore.Query.DESCENDING).limit(limit).stream()
        for doc in stream:
            if doc.id == problem_card_id:
                continue
            d = doc.to_dict() or {}
            score = 0.0
            if _normalize_issue_type(d.get('issueType')) == _normalize_issue_type(issue_type):
                score += 0.25
            if _norm_text(d.get('locationWard')) == _norm_text(ward):
                score += 0.20
            if _norm_text(d.get('locationCity')) == _norm_text(city):
                score += 0.20
            score += 0.35 * _near_duplicate_score(d.get('description', ''), description)
            if score >= 0.65:
                results.append({'problemCardId': doc.id, 'score': round(score, 3)})
        results.sort(key=lambda x: x['score'], reverse=True)
        return results[:5]
    except Exception as e:
        print(f"near duplicate check failed: {e}")
        return []


def _coerce_value_to_shape(value, template):
    if template is None:
        return value
    if isinstance(template, bool):
        if isinstance(value, bool):
            return value
        t = _norm_text(value)
        return t in ('true', '1', 'yes', 'y')
    if isinstance(template, int) and not isinstance(template, bool):
        return _safe_int(value, default=template, min_value=-1000000, max_value=1000000)
    if isinstance(template, float):
        return _safe_float(value, default=template, min_value=-1000000.0, max_value=1000000.0)
    if isinstance(template, str):
        return str(value) if value is not None else ''
    if isinstance(template, list):
        if isinstance(value, list):
            return value
        return template
    if isinstance(template, dict):
        if isinstance(value, dict):
            return value
        return template
    return value


def _sanitize_ai_edit_object(candidate, current_data):
    if not isinstance(candidate, dict):
        return dict(current_data)

    immutable_keys = {
        'id', 'ngoId', 'problemCardId', 'createdAt', 'updatedAt', 'anonymized',
        'assignedVolunteerIds', 'uploadFingerprint', 'dupFingerprint',
    }
    out = dict(current_data)
    for key, original in current_data.items():
        if key in immutable_keys:
            continue
        if key in candidate:
            out[key] = _coerce_value_to_shape(candidate[key], original)

    if 'issueType' in out:
        out['issueType'] = _normalize_issue_type(out.get('issueType'))
    if 'severityLevel' in out:
        sev = _norm_text(out.get('severityLevel'))
        out['severityLevel'] = sev if sev in ALLOWED_SEVERITY else 'low'
    return out


def _sanitize_ai_task_item(candidate):
    if not isinstance(candidate, dict):
        return None
    item = dict(candidate)
    task_type = _norm_text(item.get('taskType', 'other'))
    if task_type not in ALLOWED_TASK_TYPES:
        task_type = 'other'

    raw_skills = item.get('skillTags') if isinstance(item.get('skillTags'), list) else []
    skill_tags = [
        _norm_text(s) for s in raw_skills
        if _norm_text(s) in ALLOWED_TASK_SKILLS
    ]
    if not skill_tags:
        skill_tags = ['communication']

    return {
        'id': str(item.get('id', 'NEW')),
        'taskType': task_type,
        'description': str(item.get('description', 'Volunteer task'))[:140],
        'skillTags': skill_tags,
        'estimatedVolunteers': _safe_int(item.get('estimatedVolunteers', 1), default=1, min_value=1, max_value=10),
        'estimatedDurationHours': _safe_float(item.get('estimatedDurationHours', 2), default=2.0, min_value=0.5, max_value=24.0),
    }


def _compute_adaptive_match_weights():
    defaults = {
        'skill': 0.50,
        'distance': 0.28,
        'availability': 0.06,
        'language': 0.11,
        'trust': 0.05,
    }
    if not db:
        return defaults

    try:
        succ = {'skill': [], 'distance': [], 'availability': [], 'language': [], 'trust': []}
        fail = {'skill': [], 'distance': [], 'availability': [], 'language': [], 'trust': []}

        stream = db.collection('match_records').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(250).stream()
        for doc in stream:
            d = doc.to_dict() or {}
            factors = d.get('explainFactors') or {}
            if not factors:
                continue
            status = _norm_text(d.get('status'))
            bucket = succ if status in ('proof_approved', 'proof_submitted', 'accepted') else fail
            bucket['skill'].append(_safe_float(factors.get('skillScore', 0.0), default=0.0, min_value=0.0, max_value=1.0))
            bucket['distance'].append(_safe_float(factors.get('distanceScore', 0.0), default=0.0, min_value=0.0, max_value=1.0))
            bucket['availability'].append(_safe_float(factors.get('availabilityBonus', 0.0), default=0.0, min_value=0.0, max_value=1.0))
            bucket['language'].append(_safe_float(factors.get('languageScore', 0.0), default=0.0, min_value=0.0, max_value=1.0))
            bucket['trust'].append(_safe_float(factors.get('trustScoreNorm', 0.0), default=0.0, min_value=0.0, max_value=1.0))

        if sum(len(v) for v in succ.values()) < 20:
            return defaults

        tuned = {}
        for k, base in defaults.items():
            s_mean = (sum(succ[k]) / len(succ[k])) if succ[k] else 0.0
            f_mean = (sum(fail[k]) / len(fail[k])) if fail[k] else 0.0
            lift = max(-0.25, min(0.25, s_mean - f_mean))
            tuned[k] = max(0.02, base * (1.0 + lift))

        total = sum(tuned.values())
        return {k: round(v / total, 4) for k, v in tuned.items()}
    except Exception as e:
        print(f"adaptive weight computation failed: {e}")
        return defaults


def _to_utc(value):
    if not value or not hasattr(value, 'replace'):
        return None
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def _estimate_travel_minutes(distance_km):
    # baseline ETA for dispatch ordering only
    speed_kmh = 25.0
    return max(3, int(round((max(distance_km, 0.0) / speed_kmh) * 60)))


def _log_sync_conflict(match_record_id, task_id, volunteer_id, local_note, reason, action_id=None):
    if not db:
        return
    try:
        conflict_id = str(uuid.uuid4())
        db.collection('sync_conflicts').document(conflict_id).set({
            'id': conflict_id,
            'actionId': action_id,
            'matchRecordId': match_record_id,
            'taskId': task_id,
            'volunteerId': volunteer_id,
            'reason': reason,
            'localMergeNote': local_note,
            'policy': 'server_wins',
            'status': 'logged',
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
    except Exception as e:
        print(f"sync conflict log failed: {e}")


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

    norm_text = _norm_text(text_content)
    upload_fp = _fingerprint(ngo_id, 'text', norm_text)
    quality_flags = []
    if len(norm_text) < 20:
        quality_flags.append('too_short_text')
    if _check_recent_text_duplicate(ngo_id, upload_fp):
        quality_flags.append('possible_duplicate_upload')
        _log_quality_event(
            event_type='duplicate_upload_detected',
            severity='medium',
            ngo_id=ngo_id,
            flags=quality_flags,
            details={'uploadFingerprint': upload_fp},
        )

    doc_id = str(uuid.uuid4())
    db.collection('raw_uploads').document(doc_id).set({
        'id': doc_id, 'ngoId': ngo_id,
        'cloudinaryUrl': upload_result.get('secure_url'),
        'cloudinaryPublicId': upload_result.get('public_id'),
        'fileType': 'text',
        'uploadFingerprint': upload_fp,
        'qualityFlags': quality_flags,
        'uploadedAt': firestore.SERVER_TIMESTAMP,
        'status': 'pending',
    })
    return doc_id


def _run_matching_internal(task_id, exclude_volunteer_ids=None, redispatch_reason=None):
    """Core matching logic — callable without HTTP context."""
    if not db:
        return {'error': 'Firestore not connected'}, 500

    task_doc = db.collection('tasks').document(task_id).get()
    if not task_doc.exists:
        return {'error': 'Task not found'}, 404
    task_data = task_doc.to_dict()
    if task_data.get('status') not in (None, 'open'):
        return {'status': 'skipped', 'reason': 'Task is not open'}, 200

    excluded_ids = set(exclude_volunteer_ids or [])
    try:
        existing_matches = db.collection('match_records').where('taskId', '==', task_id).stream()
        for m in existing_matches:
            md = m.to_dict() or {}
            vid = md.get('volunteerId')
            st = _norm_text(md.get('status'))
            if vid and st in ('open', 'accepted', 'proof_submitted', 'proof_approved'):
                excluded_ids.add(vid)
    except Exception as e:
        print(f"existing match scan failed: {e}")

    task_skills = task_data.get('skillTags', [])
    required_language = _norm_text(task_data.get('languagePref') or task_data.get('preferredLanguage') or '')
    min_trust_score = _safe_int(task_data.get('minTrustScore', 0), default=0, min_value=0, max_value=1000)
    requires_verified = bool(task_data.get('requiresVerifiedVolunteer', False))
    safety_level = _norm_text(task_data.get('safetyLevel', 'normal'))

    if safety_level in ('high', 'critical'):
        min_trust_score = max(min_trust_score, 40)
    if requires_verified:
        min_trust_score = max(min_trust_score, 50)

    pc_id = task_data.get('problemCardId')
    pc_doc = db.collection('problem_cards').document(pc_id).get()
    if not pc_doc.exists:
        return {'error': 'Orphaned task'}, 404
    pc_data = pc_doc.to_dict()

    pc_geo = pc_data.get('locationGeoPoint')
    pc_lat, pc_lon = (pc_geo.latitude, pc_geo.longitude) if pc_geo else (13.0827, 80.2707)

    volunteers_query = db.collection('volunteer_profiles').where('availabilityWindowActive', '==', True).stream()
    weights = _compute_adaptive_match_weights()
    matches = []
    filtered_language = 0
    filtered_trust = 0
    filtered_radius = 0

    for v_doc in volunteers_query:
        if v_doc.id in excluded_ids:
            continue

        v_data = v_doc.to_dict()
        v_geo = v_data.get('locationGeoPoint')
        if not v_geo:
            continue

        trust_score = _safe_int(v_data.get('trustScore', 0), default=0, min_value=0, max_value=1000)
        if trust_score < min_trust_score:
            filtered_trust += 1
            continue

        radius_km = float(v_data.get('radiusKm', 10.0))
        dist_km = haversine(v_geo.latitude, v_geo.longitude, pc_lat, pc_lon)
        if dist_km > radius_km + 5.0:
            filtered_radius += 1
            continue

        normalized_distance = min(dist_km / max(radius_km, 1.0), 1.0)
        v_skills = v_data.get('skillTags', [])
        overlap = len(set(v_skills).intersection(set(task_skills)))
        is_partial = bool(v_data.get('isPartialAvailability', False))
        window_active = bool(v_data.get('availabilityWindowActive', False))

        volunteer_language = _norm_text(v_data.get('languagePref', ''))
        language_match = 1.0 if (not required_language or volunteer_language == required_language) else 0.0
        if required_language and language_match < 1.0:
            filtered_language += 1
            continue

        availability_bonus = 0.05 if is_partial else (0.10 if window_active else 0.0)

        skill_score = (overlap / max(len(task_skills), 1)) if task_skills else 0.5
        distance_score = (1.0 - normalized_distance)
        trust_score_norm = min(trust_score / 100.0, 1.0)

        score = (
            skill_score * weights['skill'] +
            distance_score * weights['distance'] +
            availability_bonus * weights['availability'] +
            language_match * weights['language'] +
            trust_score_norm * weights['trust']
        )

        why_parts = []
        why_parts.append(f"{overlap}/{max(len(task_skills), 1)} skills")
        why_parts.append(f"{round(dist_km)}km away")
        if required_language:
            why_parts.append(f"language: {volunteer_language or 'n/a'}")
        if availability_bonus > 0:
            why_parts.append("availability active")
        if trust_score >= 50:
            why_parts.append("strong trust history")

        matches.append({
            'volunteerId': v_doc.id,
            'score': score,
            'distanceKm': round(dist_km, 2),
            'estimatedTravelMinutes': _estimate_travel_minutes(dist_km),
            'skillOverlap': overlap,
            'availabilityBonus': availability_bonus,
            'languageMatch': language_match,
            'trustScoreAtMatch': trust_score,
            'explainFactors': {
                'skillScore': round(skill_score, 4),
                'distanceScore': round(distance_score, 4),
                'availabilityBonus': round(availability_bonus, 4),
                'languageScore': round(language_match, 4),
                'trustScoreNorm': round(trust_score_norm, 4),
                'weightsUsed': weights,
            },
            'whyMatched': ' | '.join(why_parts),
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
            'estimatedTravelMinutes': m['estimatedTravelMinutes'],
            'skillOverlap': m['skillOverlap'],
            'availabilityBonus': m['availabilityBonus'],
            'languageMatch': m['languageMatch'],
            'trustScoreAtMatch': m['trustScoreAtMatch'],
            'explainFactors': m['explainFactors'],
            'whyMatched': m['whyMatched'],
            'explainVersion': 2,
            'requiredLanguage': required_language,
            'minTrustScore': min_trust_score,
            'redispatchReason': redispatch_reason,
            'status': 'open',
            'missionBriefing': task_data.get('description', 'Mission Briefing'),
            'whatToBring': what_to_bring_text,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
    batch.commit()
    return {
        'status': 'success',
        'matches_generated': len(top_matches),
        'excludedVolunteers': len(excluded_ids),
        'filters': {
            'requiredLanguage': required_language,
            'minTrustScore': min_trust_score,
            'filteredByTrust': filtered_trust,
            'filteredByLanguage': filtered_language,
            'filteredByRadius': filtered_radius,
        },
    }, 200


def _redispatch_task(task_id, reason='manual', stale_hours=8):
    if not db:
        return {'error': 'Firestore not connected'}, 500

    task_ref = db.collection('tasks').document(task_id)
    task_doc = task_ref.get()
    if not task_doc.exists:
        return {'error': 'Task not found'}, 404

    task_data = task_doc.to_dict() or {}
    if _norm_text(task_data.get('status')) == 'done':
        return {'status': 'skipped', 'reason': 'Task already done'}, 200

    threshold = datetime.now(timezone.utc) - timedelta(hours=max(1, stale_hours))
    stale_volunteer_ids = []
    stale_match_ids = []

    try:
        mr_stream = db.collection('match_records').where('taskId', '==', task_id).where('status', '==', 'accepted').stream()
        for mr in mr_stream:
            md = mr.to_dict() or {}
            accepted_time = _to_utc(md.get('acceptedAt')) or _to_utc(md.get('createdAt'))
            if accepted_time and accepted_time < threshold:
                vid = md.get('volunteerId')
                if vid:
                    stale_volunteer_ids.append(vid)
                stale_match_ids.append(mr.id)
                db.collection('match_records').document(mr.id).update({
                    'status': 'expired',
                    'redispatchMeta': {
                        'reason': reason,
                        'expiredAt': firestore.SERVER_TIMESTAMP,
                        'staleHours': stale_hours,
                    },
                })
    except Exception as e:
        print(f"redispatch stale scan failed: {e}")

    result, code = _run_matching_internal(
        task_id,
        exclude_volunteer_ids=stale_volunteer_ids,
        redispatch_reason=reason,
    )

    if code == 200:
        try:
            task_ref.update({
                'lastRedispatchAt': firestore.SERVER_TIMESTAMP,
                'lastRedispatchReason': reason,
                'redispatchCount': firestore.Increment(1),
            })
        except Exception as e:
            print(f"task redispatch metadata update failed: {e}")

        result['staleMatchesExpired'] = len(stale_match_ids)
        result['staleVolunteersExcluded'] = len(stale_volunteer_ids)

    return result, code


def _run_redispatch_cycle(stale_hours=8, limit=25):
    if not db:
        return {'error': 'Firestore not connected'}, 500

    threshold = datetime.now(timezone.utc) - timedelta(hours=max(1, stale_hours))
    task_ids = set()

    try:
        accepted_stream = db.collection('match_records').where('status', '==', 'accepted').stream()
        for mr in accepted_stream:
            md = mr.to_dict() or {}
            accepted_time = _to_utc(md.get('acceptedAt')) or _to_utc(md.get('createdAt'))
            task_id = md.get('taskId')
            if not task_id or not accepted_time:
                continue
            if accepted_time < threshold:
                task_ids.add(task_id)
            if len(task_ids) >= max(1, limit):
                break
    except Exception as e:
        return {'error': f'redispatch cycle scan failed: {e}'}, 500

    processed = []
    for tid in task_ids:
        res, code = _redispatch_task(tid, reason='auto_stale_acceptance', stale_hours=stale_hours)
        processed.append({'taskId': tid, 'code': code, 'result': res})

    return {'status': 'success', 'processedCount': len(processed), 'processed': processed}, 200


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
        upload_fp = _fingerprint(ngo_id, file_type, file_path)
        quality_flags = []
        if _check_recent_text_duplicate(ngo_id, upload_fp, hours=12):
            quality_flags.append('possible_duplicate_upload')
            _log_quality_event(
                event_type='duplicate_media_upload_detected',
                severity='low',
                ngo_id=ngo_id,
                related={'rawUploadId': doc_id},
                flags=quality_flags,
                details={'uploadFingerprint': upload_fp},
            )

        db.collection('raw_uploads').document(doc_id).set({
            'id': doc_id, 'ngoId': ngo_id,
            'cloudinaryUrl': cloudinary_url,
            'cloudinaryPublicId': cloudinary_public_id,
            'fileType': file_type,
            'uploadFingerprint': upload_fp,
            'qualityFlags': quality_flags,
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
    force_regenerate = bool(payload.get('forceRegenerate', False))
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

    if pc.get('ngoId') != ngo_id:
        return jsonify({'status': 'error', 'reason': 'ngoId does not own this problem card'}), 403

    if pc.get('status') not in ('approved', 'pending_review', None):
        return jsonify({'status': 'error', 'reason': 'ProblemCard status not valid for task generation'}), 409

    quality_flags = []

    if not force_regenerate:
        try:
            existing = db.collection('tasks').where('problemCardId', '==', problem_card_id).stream()
            existing_ids = [d.id for d in existing]
            if existing_ids:
                return jsonify({
                    'status': 'success',
                    'taskIds': existing_ids,
                    'priorityScore': _safe_float(pc.get('priorityScore', 0.0), default=0.0, min_value=0.0, max_value=100.0),
                    'qualityFlags': quality_flags,
                    'idempotent': True,
                }), 200
        except Exception as e:
            print(f"Existing task check failed: {e}")

    description = str(pc.get('description', 'No description'))[:600]
    raw_issue_type = str(pc.get('issueType', '')).strip().lower()
    issue_type = _normalize_issue_type(raw_issue_type)
    severity_level = str(pc.get('severityLevel', 'low')).strip().lower()
    affected_count = _safe_int(pc.get('affectedCount', 0), default=0, min_value=0, max_value=100000)

    if raw_issue_type != issue_type:
        quality_flags.append('issue_type_normalized')
    if severity_level not in ALLOWED_SEVERITY:
        severity_level = 'low'
        quality_flags.append('severity_normalized')

    is_duplicate_card, dup_fp = _check_problem_duplicate(
        problem_card_id,
        ngo_id,
        issue_type,
        pc.get('locationWard', ''),
        pc.get('locationCity', ''),
        description,
    )
    quality_flags.append('possible_duplicate_problem_card' if is_duplicate_card else 'no_duplicate_problem_card')
    near_duplicates = _check_problem_near_duplicates(
        problem_card_id,
        ngo_id,
        issue_type,
        pc.get('locationWard', ''),
        pc.get('locationCity', ''),
        description,
    )
    if near_duplicates:
        quality_flags.append('near_duplicate_problem_card')

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
        safe_task = _sanitize_ai_task_item(task_data)
        if not safe_task:
            continue
        task_id = str(uuid.uuid4())
        estimated_volunteers = _safe_int(safe_task.get('estimatedVolunteers', 1), default=1, min_value=1, max_value=10)
        estimated_hours = _safe_float(safe_task.get('estimatedDurationHours', 1), default=1.0, min_value=0.5, max_value=24.0)
        task_doc = {
            'id': task_id,
            'problemCardId': problem_card_id,
            'taskType': str(safe_task.get('taskType', 'other')),
            'description': str(safe_task.get('description', 'Volunteer task'))[:140],
            'skillTags': safe_task.get('skillTags', []),
            'estimatedVolunteers': estimated_volunteers,
            'estimatedDurationHours': estimated_hours,
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
            'dupFingerprint': dup_fp,
            'qualityFlags': quality_flags,
            'nearDuplicates': near_duplicates,
        })
    except Exception as e:
        print(f"Priority score update failed: {e}")

    if is_duplicate_card:
        _log_quality_event(
            event_type='duplicate_problem_card_detected',
            severity='high',
            ngo_id=ngo_id,
            related={'problemCardId': problem_card_id},
            flags=quality_flags,
            details={'dupFingerprint': dup_fp},
        )

    # Chain matching directly — no fake HTTP context
    for tid in created_task_ids:
        try:
            result, status = _run_matching_internal(tid)
            print(f"Matching for {tid}: {status}")
        except Exception as e:
            print(f"Matching failed for {tid}: {e}")

    return jsonify({'status': 'success', 'taskIds': created_task_ids, 'priorityScore': round(priority_score, 2), 'qualityFlags': quality_flags}), 200


@app.route('/run-matching', methods=['POST'])
def run_matching():
    payload = request.json
    task_id = payload.get('taskId') if payload else None
    if not task_id:
        return jsonify({'error': 'Missing taskId'}), 400
    result, status_code = _run_matching_internal(task_id)
    return jsonify(result), status_code


@app.route('/redispatch-task', methods=['POST'])
def redispatch_task():
    payload = request.json or {}
    task_id = payload.get('taskId')
    reason = payload.get('reason', 'manual')
    stale_hours = _safe_int(payload.get('staleHours', 8), default=8, min_value=1, max_value=240)
    if not task_id:
        return jsonify({'error': 'Missing taskId'}), 400
    result, status_code = _redispatch_task(task_id, reason=reason, stale_hours=stale_hours)
    return jsonify(result), status_code


@app.route('/redispatch-cycle', methods=['POST'])
def redispatch_cycle():
    payload = request.json or {}
    stale_hours = _safe_int(payload.get('staleHours', 8), default=8, min_value=1, max_value=240)
    limit = _safe_int(payload.get('limit', 25), default=25, min_value=1, max_value=200)
    result, status_code = _run_redispatch_cycle(stale_hours=stale_hours, limit=limit)
    return jsonify(result), status_code


@app.route('/sync-task-update', methods=['POST'])
def sync_task_update():
    payload = request.json or {}
    action_id = payload.get('actionId')
    match_record_id = payload.get('matchRecordId')
    task_id = payload.get('taskId')
    volunteer_id = payload.get('volunteerId')
    updates = payload.get('updates', {}) or {}
    client_updated_iso = payload.get('clientUpdatedAtIso')
    local_merge_note = payload.get('localMergeNote', '')

    if not match_record_id:
        return jsonify({'error': 'Missing matchRecordId'}), 400

    if not isinstance(updates, dict):
        return jsonify({'error': 'updates must be an object'}), 400

    mr_ref = db.collection('match_records').document(match_record_id)
    mr_doc = mr_ref.get()
    if not mr_doc.exists:
        return jsonify({'error': 'MatchRecord not found'}), 404

    mr_data = mr_doc.to_dict() or {}
    if not task_id:
        task_id = mr_data.get('taskId', '')
    if not volunteer_id:
        volunteer_id = mr_data.get('volunteerId', '')

    server_updated = _to_utc(mr_data.get('updatedAt')) or _to_utc(mr_data.get('createdAt'))
    client_updated = None
    if client_updated_iso:
        try:
            client_updated = datetime.fromisoformat(str(client_updated_iso).replace('Z', '+00:00'))
            client_updated = client_updated.astimezone(timezone.utc)
        except Exception:
            client_updated = None

    conflict = bool(server_updated and client_updated and server_updated > client_updated)
    if conflict:
        note = _norm_text(local_merge_note)
        patch = {
            'pendingLocalMergeNote': note,
            'pendingLocalMergeAt': firestore.SERVER_TIMESTAMP,
            'pendingLocalMergeSource': 'offline_queue',
            'updatedAt': firestore.SERVER_TIMESTAMP,
        }
        mr_ref.update(patch)

        _log_sync_conflict(
            match_record_id=match_record_id,
            task_id=task_id,
            volunteer_id=volunteer_id,
            local_note=note,
            reason='server_newer_than_client',
            action_id=action_id,
        )

        _log_quality_event(
            event_type='offline_sync_conflict',
            severity='medium',
            ngo_id=None,
            related={'matchRecordId': match_record_id, 'taskId': task_id, 'volunteerId': volunteer_id},
            flags=['server_wins_conflict'],
            details={'actionId': action_id, 'localMergeNote': note},
        )

        return jsonify({'status': 'conflict_resolved_server_wins', 'conflict': True, 'policy': 'server_wins'}), 200

    match_updates = {}
    allowed_match_status = {'accepted', 'proof_submitted', 'proof_rejected', 'proof_approved'}
    new_match_status = _norm_text(updates.get('matchStatus'))
    if new_match_status in allowed_match_status:
        match_updates['status'] = new_match_status

    offline_note = _norm_text(updates.get('offlineNote') or local_merge_note)
    if offline_note:
        match_updates['offlineNote'] = offline_note[:240]

    if match_updates:
        match_updates['updatedAt'] = firestore.SERVER_TIMESTAMP
        mr_ref.update(match_updates)

    if task_id:
        task_updates = {}
        new_task_status = _norm_text(updates.get('taskStatus'))
        if new_task_status in {'open', 'filled', 'done'}:
            task_updates['status'] = new_task_status
        if offline_note:
            task_updates['offlineNote'] = offline_note[:240]
        if task_updates:
            task_updates['updatedAt'] = firestore.SERVER_TIMESTAMP
            db.collection('tasks').document(task_id).update(task_updates)

    return jsonify({'status': 'applied', 'conflict': False}), 200


@app.route('/simulate-scenario', methods=['POST'])
def simulate_scenario():
    payload = request.json or {}
    ngo_id = payload.get('ngoId')
    if not ngo_id:
        return jsonify({'error': 'Missing ngoId'}), 400

    shortage_percent = _safe_float(payload.get('shortagePercent', 20), default=20.0, min_value=0.0, max_value=95.0)
    surge_percent = _safe_float(payload.get('surgePercent', 30), default=30.0, min_value=0.0, max_value=300.0)
    horizon_days = _safe_int(payload.get('horizonDays', 7), default=7, min_value=1, max_value=30)

    try:
        tasks = []
        for tdoc in db.collection('tasks').where('ngoId', '==', ngo_id).stream():
            t = tdoc.to_dict() or {}
            status = _norm_text(t.get('status'))
            if status in ('open', 'filled', 'accepted', ''):
                tasks.append(t)

        active_volunteers = 0
        for vdoc in db.collection('volunteer_profiles').where('availabilityWindowActive', '==', True).stream():
            v = vdoc.to_dict() or {}
            if _safe_int(v.get('trustScore', 0), default=0, min_value=0, max_value=1000) >= 0:
                active_volunteers += 1

        total_slots = 0.0
        avg_duration = 2.0
        if tasks:
            durations = []
            for t in tasks:
                slots = _safe_int(t.get('estimatedVolunteers', 1), default=1, min_value=1, max_value=20)
                total_slots += slots
                durations.append(_safe_float(t.get('estimatedDurationHours', 2), default=2.0, min_value=0.5, max_value=48.0))
            avg_duration = sum(durations) / max(len(durations), 1)

        base_demand = max(total_slots, 1.0)
        base_supply = max(float(active_volunteers), 1.0)

        adjusted_supply = max(1.0, base_supply * (1.0 - shortage_percent / 100.0))
        adjusted_demand = max(1.0, base_demand * (1.0 + surge_percent / 100.0))

        projected_coverage = min(100.0, (adjusted_supply / adjusted_demand) * 100.0)
        backlog_slots = max(0.0, adjusted_demand - adjusted_supply)
        expected_delay_hours = min(96.0, (adjusted_demand / adjusted_supply) * avg_duration)

        if projected_coverage < 40:
            risk_level = 'critical'
        elif projected_coverage < 65:
            risk_level = 'high'
        elif projected_coverage < 85:
            risk_level = 'medium'
        else:
            risk_level = 'low'

        run_id = str(uuid.uuid4())
        result = {
            'runId': run_id,
            'ngoId': ngo_id,
            'inputs': {
                'shortagePercent': round(shortage_percent, 1),
                'surgePercent': round(surge_percent, 1),
                'horizonDays': horizon_days,
            },
            'baseline': {
                'activeVolunteers': int(base_supply),
                'openTaskSlots': int(round(base_demand)),
                'avgTaskDurationHours': round(avg_duration, 2),
            },
            'projection': {
                'projectedCoveragePercent': round(projected_coverage, 1),
                'expectedBacklogSlots': int(round(backlog_slots)),
                'expectedDelayHours': round(expected_delay_hours, 1),
                'riskLevel': risk_level,
            },
        }

        db.collection('scenario_runs').document(run_id).set({
            'id': run_id,
            'ngoId': ngo_id,
            'inputs': result['inputs'],
            'baseline': result['baseline'],
            'projection': result['projection'],
            'createdAt': firestore.SERVER_TIMESTAMP,
        })

        return jsonify({'status': 'success', 'result': result}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


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

        # AI Proof Verification
        proof_photos = mr_data.get('proof', {}).get('photoUrls', [])
        if not proof_photos and mr_data.get('proof', {}).get('photoUrl'):
            proof_photos = [mr_data.get('proof', {}).get('photoUrl')]

        is_auto_approved = False
        ai_reason = "No photos for AI analysis"
        confidence = 0
        rubric = {
            'taskEvidenceScore': 0,
            'clarityScore': 0,
            'geoTemporalPlausibilityScore': 0,
            'tamperRiskScore': 0,
            'summary': 'No photos for AI analysis',
        }

        if proof_photos and genai_client:
            prompt = f'''
You are an NGO admin verifying volunteer proof.
Task description: "{task_desc}"
Score proof using this rubric (0-100 each):
- taskEvidenceScore: does image clearly show task outcome?
- clarityScore: image quality and visibility
- geoTemporalPlausibilityScore: context plausibly matches location/time
- tamperRiskScore: higher means more likely manipulated or irrelevant

Return ONLY valid JSON:
{{
    "taskEvidenceScore": 0-100,
    "clarityScore": 0-100,
    "geoTemporalPlausibilityScore": 0-100,
    "tamperRiskScore": 0-100,
    "summary": "short explanation"
}}
'''
            contents = [prompt]
            for url in proof_photos:
                try:
                    res = requests.get(url, timeout=10)
                    if res.ok:
                        contents.append(genai.types.Part.from_bytes(data=res.content, mime_type='image/jpeg'))
                except Exception:
                    pass
            
            if len(contents) > 1:
                try:
                    resp = genai_client.models.generate_content(model=GEMINI_MODEL, contents=contents)
                    raw = resp.text or '{}'
                    m = re.search(r'\{.*\}', raw, re.DOTALL)
                    cleaned = m.group(0) if m else raw.replace('```json', '').replace('```', '').strip()
                    parsed = json.loads(cleaned)
                    rubric['taskEvidenceScore'] = _safe_float(parsed.get('taskEvidenceScore', 0), default=0.0, min_value=0.0, max_value=100.0)
                    rubric['clarityScore'] = _safe_float(parsed.get('clarityScore', 0), default=0.0, min_value=0.0, max_value=100.0)
                    rubric['geoTemporalPlausibilityScore'] = _safe_float(parsed.get('geoTemporalPlausibilityScore', 0), default=0.0, min_value=0.0, max_value=100.0)
                    rubric['tamperRiskScore'] = _safe_float(parsed.get('tamperRiskScore', 100), default=100.0, min_value=0.0, max_value=100.0)
                    rubric['summary'] = str(parsed.get('summary', 'AI checked'))[:240]

                    confidence = round(
                        rubric['taskEvidenceScore'] * 0.45 +
                        rubric['clarityScore'] * 0.20 +
                        rubric['geoTemporalPlausibilityScore'] * 0.25 +
                        (100 - rubric['tamperRiskScore']) * 0.10,
                        2,
                    )
                    ai_reason = rubric['summary']
                    if confidence >= 85 and rubric['tamperRiskScore'] <= 35:
                        is_auto_approved = True
                except Exception as e:
                    ai_reason = f"AI Error: {e}"

        label = 'approved' if is_auto_approved else 'needs_clarification'
        ai_verification_reason = f"[AUTO-APPROVED {confidence}%] {ai_reason}" if is_auto_approved else f"[MANUAL REVIEW REQUIRED {confidence}%] {ai_reason}"

        db.collection('match_records').document(match_record_id).update({
            'aiVerificationReason': ai_verification_reason,
            'aiVerificationLabel': label,
            'aiVerificationConfidence': confidence,
            'aiVerificationRubric': rubric,
            'aiVerifiedAt': firestore.SERVER_TIMESTAMP,
        })

        if is_auto_approved:
            # Auto Approve Data Changes
            db.collection('match_records').document(match_record_id).update({
                'status': 'proof_approved',
            })
            
            # Trust & Gamification Increment
            volunteer_id = mr_data.get('volunteerId')
            if volunteer_id:
                vol_ref = db.collection('volunteer_profiles').document(volunteer_id)
                vol_doc = vol_ref.get()
                if vol_doc.exists:
                    v_data = vol_doc.to_dict()
                    curr_score = _safe_int(v_data.get('trustScore', 0), default=0, min_value=0, max_value=1000)
                    tasks_comp = _safe_int(v_data.get('tasksCompleted', 0), default=0, min_value=0, max_value=100000)
                    anomaly_flags = []

                    ms = _safe_float(mr_data.get('matchScore', 0.0), default=0.0, min_value=0.0, max_value=10.0)
                    if ms > 1.0:
                        anomaly_flags.append('match_score_out_of_expected_range')

                    if curr_score + 10 > 200:
                        anomaly_flags.append('trust_score_high_growth')

                    try:
                        recent_threshold = datetime.now(timezone.utc) - timedelta(hours=24)
                        recent = db.collection('match_records') \
                            .where('volunteerId', '==', volunteer_id) \
                            .where('status', '==', 'proof_approved') \
                            .stream()
                        recent_count = 0
                        for r in recent:
                            rd = r.to_dict() or {}
                            ts = rd.get('completedAt') or rd.get('createdAt')
                            if ts and hasattr(ts, 'replace'):
                                t = ts.replace(tzinfo=timezone.utc) if ts.tzinfo is None else ts
                                if t >= recent_threshold:
                                    recent_count += 1
                        if recent_count >= 20:
                            anomaly_flags.append('high_approval_volume_24h')
                    except Exception as e:
                        print(f"recent anomaly check failed: {e}")

                    if anomaly_flags:
                        _log_quality_event(
                            event_type='proof_approval_anomaly',
                            severity='medium',
                            ngo_id=ngo_id,
                            related={'matchRecordId': match_record_id, 'volunteerId': volunteer_id},
                            flags=anomaly_flags,
                            details={'currentTrustScore': curr_score},
                        )

                    vol_ref.update({
                        'trustScore': curr_score + 10,
                        'tasksCompleted': tasks_comp + 1
                    })

                    if anomaly_flags:
                        db.collection('match_records').document(match_record_id).update({
                            'qualityFlags': anomaly_flags,
                            'qualityReviewedAt': firestore.SERVER_TIMESTAMP,
                        })
            
            # Return immediate success without creating NGO notification queue
            # (Note: App can poll or rely on stream for completion cascade)
            return jsonify({'status': 'success', 'autoApproved': True, 'reason': ai_reason}), 200

        # Create Manual Notification if Auto-Approval Fails
        notif_id = str(uuid.uuid4())
        db.collection('ngo_notifications').document(notif_id).set({
            'id': notif_id,
            'ngoId': ngo_id or 'unknown',
            'type': 'proof_submitted',
            'matchRecordId': match_record_id,
            'taskId': task_id,
            'message': f'Proof submitted for: {task_desc} — tap to review. (AI insight: {ai_reason})',
            'read': False,
            'createdAt': firestore.SERVER_TIMESTAMP,
        })
        return jsonify({'status': 'success', 'autoApproved': False, 'notificationId': notif_id}), 200
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

        issue_type = 'sdg11_sustainable_cities_and_communities'
        affected_count = 0
        location_ward = task_data.get('locationWard', 'Unknown Ward')
        if problem_card_id:
            pc_doc = db.collection('problem_cards').document(problem_card_id).get()
            if pc_doc.exists:
                pc_data = pc_doc.to_dict()
                issue_type = _normalize_issue_type(pc_data.get('issueType', issue_type))
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


# ── Gemini Migrated Endpoints ──────────────────────────────────────────────────

@app.route('/api/gemini/extract-problems', methods=['POST'])
def gemini_extract_problems():
    if not genai_client:
        return jsonify({'error': 'Gemini not configured'}), 500
        
    data = request.json or {}
    file_type = data.get('fileType', 'text')
    text_payload = data.get('textPayload', '')
    url = data.get('url', '')

    prompt_text = (
        "You are a massive array-extraction agent for NGO community surveys. "
        "Extract every single independent field problem into its own logical structure. "
        "Return ONLY a valid geometric JSON Array `[...]` of mapped objects. "
        "For EACH independent extracted problem, strictly return: "
        "- issueType (one of: sdg1_no_poverty, sdg2_zero_hunger, sdg3_good_health_and_well_being, sdg4_quality_education, sdg5_gender_equality, sdg6_clean_water_and_sanitation, sdg7_affordable_and_clean_energy, sdg8_decent_work_and_economic_growth, sdg9_industry_innovation_and_infrastructure, sdg10_reduced_inequalities, sdg11_sustainable_cities_and_communities, sdg12_responsible_consumption_and_production, sdg13_climate_action, sdg14_life_below_water, sdg15_life_on_land, sdg16_peace_justice_and_strong_institutions, sdg17_partnerships_for_the_goals)\n"
        "- locationWard (string)\n"
        "- locationCity (string)\n"
        "- severityLevel (one of: low, medium, high, critical)\n"
        "- affectedCount (integer or null)\n"
        "- description (max 120 chars, anonymized)\n"
        "- confidenceScore (float 0.0 to 1.0)"
    )

    contents = []
    if file_type in ['text', 'csv', 'document'] or text_payload:
        contents.append(prompt_text)
        contents.append(f"PAYLOAD NATIVE DATA:\n{text_payload}")
    else:
        try:
            res = requests.get(url, timeout=15)
            if res.ok:
                mime_type = res.headers.get('content-type', 'audio/mp4' if file_type == 'audio' else 'image/jpeg')
                contents.append(prompt_text)
                contents.append(genai.types.Part.from_bytes(data=res.content, mime_type=mime_type))
            else:
                return jsonify({'error': 'Failed to fetch media'}), 400
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    try:
        resp = genai_client.models.generate_content(model=GEMINI_MODEL, contents=contents)
        raw_text = resp.text or '[]'
        m = re.search(r'\[.*\]', raw_text, re.DOTALL)
        cleaned = m.group(0) if m else raw_text.replace('```json', '').replace('```', '').strip()
        parsed = json.loads(cleaned)
        if not isinstance(parsed, list):
            return jsonify({'error': 'Expected JSON array from model'}), 500

        normalized = []
        for row in parsed:
            if not isinstance(row, dict):
                continue
            sev = _norm_text(row.get('severityLevel', 'low'))
            normalized.append({
                'issueType': _normalize_issue_type(row.get('issueType')),
                'locationWard': str(row.get('locationWard', 'Unknown Ward')),
                'locationCity': str(row.get('locationCity', 'Unknown City')),
                'severityLevel': sev if sev in ALLOWED_SEVERITY else 'low',
                'affectedCount': _safe_int(row.get('affectedCount', 0), default=0, min_value=0, max_value=100000),
                'description': str(row.get('description', 'Extracted problem'))[:120],
                'confidenceScore': _safe_float(row.get('confidenceScore', 0.0), default=0.0, min_value=0.0, max_value=1.0),
            })
        return jsonify(normalized), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/gemini/extract-problems-audio', methods=['POST'])
def gemini_extract_problems_audio():
    if not genai_client:
        return jsonify({'error': 'Gemini not configured'}), 500

    audio_file = request.files.get('audio')
    if not audio_file:
        return jsonify({'error': 'Missing audio file'}), 400

    mime_type = audio_file.mimetype or 'audio/m4a'
    try:
        audio_bytes = audio_file.read()
    except Exception as e:
        return jsonify({'error': f'Could not read audio: {e}'}), 400

    prompt_text = (
        "You are a massive array-extraction agent for NGO community surveys. "
        "The input is an audio field note. Extract each independent problem. "
        "Return ONLY valid JSON array. Each object must include: issueType (SDG value), "
        "locationWard, locationCity, severityLevel, affectedCount, description, confidenceScore. "
        "issueType must be one of sdg1_no_poverty ... sdg17_partnerships_for_the_goals."
    )

    try:
        contents = [
            prompt_text,
            genai.types.Part.from_bytes(data=audio_bytes, mime_type=mime_type),
        ]
        resp = genai_client.models.generate_content(model=GEMINI_MODEL, contents=contents)
        raw_text = resp.text or '[]'
        m = re.search(r'\[.*\]', raw_text, re.DOTALL)
        cleaned = m.group(0) if m else raw_text.replace('```json', '').replace('```', '').strip()
        parsed = json.loads(cleaned)
        if not isinstance(parsed, list):
            return jsonify({'error': 'Expected JSON array from model'}), 500

        normalized = []
        for row in parsed:
            if not isinstance(row, dict):
                continue
            normalized.append({
                'issueType': _normalize_issue_type(row.get('issueType')),
                'locationWard': str(row.get('locationWard', 'Unknown Ward')),
                'locationCity': str(row.get('locationCity', 'Unknown City')),
                'severityLevel': _norm_text(row.get('severityLevel', 'low')) if _norm_text(row.get('severityLevel', 'low')) in ALLOWED_SEVERITY else 'low',
                'affectedCount': _safe_int(row.get('affectedCount', 0), default=0, min_value=0, max_value=100000),
                'description': str(row.get('description', 'Extracted from audio'))[:120],
                'confidenceScore': _safe_float(row.get('confidenceScore', 0.0), default=0.0, min_value=0.0, max_value=1.0),
            })
        return jsonify(normalized), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/gemini/ai-edit', methods=['POST'])
def gemini_ai_edit_endpoint():
    data = request.json or {}
    current_data = data.get('currentData', {})
    instruction = data.get('instruction', '')
    context_desc = data.get('contextDescription', 'data structure')

    prompt = f'''
You are an AI assistant helping an NGO admin edit {context_desc}.
Here is the current data as JSON:
{json.dumps(current_data)}

The admin says: "{instruction}"
Apply the requested changes and return ONLY the full modified JSON object. Return ONLY valid JSON, no markdown wrappers.
'''
    try:
        resp = gemini_generate(prompt)
        m = re.search(r'\{.*\}', resp, re.DOTALL)
        cleaned = m.group(0) if m else (resp or '{}').replace('```json', '').replace('```', '').strip()
        parsed = json.loads(cleaned)
        safe = _sanitize_ai_edit_object(parsed, current_data)
        return jsonify(safe), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/gemini/ai-edit-list', methods=['POST'])
def gemini_ai_edit_list_endpoint():
    data = request.json or {}
    current_items = data.get('currentItems', [])
    instruction = data.get('instruction', '')
    context_desc = data.get('contextDescription', 'items')

    prompt = f'''
You are an AI assistant helping an NGO admin refactor {context_desc}.
Here is the current list of items:
{json.dumps(current_items)}

The admin says: "{instruction}"
Apply changes. Return ONLY a valid JSON array. For NEW items, set "id" to "NEW". Return ONLY valid JSON, no markdown.
'''
    try:
        resp = gemini_generate(prompt)
        m = re.search(r'\[.*\]', resp, re.DOTALL)
        cleaned = m.group(0) if m else (resp or '[]').replace('```json', '').replace('```', '').strip()
        parsed = json.loads(cleaned)
        if not isinstance(parsed, list):
            return jsonify({'error': 'AI response is not a list'}), 500
        safe_items = []
        for row in parsed:
            safe = _sanitize_ai_task_item(row)
            if safe:
                safe_items.append(safe)
        return jsonify(safe_items), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── Scheduler — only in main process to avoid multi-worker duplicates ─────────
def _start_scheduler():
    scheduler = BackgroundScheduler(daemon=True)
    scheduler.add_job(
        func=lambda: send_availability_reminders(),
        trigger="cron", day_of_week='fri', hour=12, minute=30,
    )
    scheduler.add_job(
        func=lambda: _run_redispatch_cycle(stale_hours=8, limit=25),
        trigger="interval", minutes=30,
    )
    scheduler.start()
    atexit.register(lambda: scheduler.shutdown(wait=False))
    print("APScheduler started.")


# Gunicorn sets GUNICORN_WORKER_ID env per worker. Only start scheduler in worker 0.
if os.getenv('GUNICORN_WORKER_ID', '0') == '0' or __name__ == '__main__':
    _start_scheduler()


if __name__ == '__main__':
    app.run(port=8080, host='0.0.0.0', debug=False)
