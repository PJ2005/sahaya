from flask import Flask, request, jsonify
import os
import requests
import cloudinary
import cloudinary.uploader
import firebase_admin
from firebase_admin import credentials, firestore
import uuid
import json
from dotenv import load_dotenv

# Load env safely
load_dotenv(dotenv_path='../../.env')

app = Flask(__name__)

# Envs
TELEGRAM_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
CLOUDINARY_CLOUD_NAME = os.getenv('CLOUDINARY_CLOUD_NAME')
CLOUDINARY_API_KEY = os.getenv('CLOUDINARY_API_KEY')
CLOUDINARY_API_SECRET = os.getenv('CLOUDINARY_API_SECRET')
CLOUDINARY_UPLOAD_PRESET = os.getenv('CLOUDINARY_UPLOAD_PRESET')

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

@app.route('/', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'Sahaya Ingestion Pipeline v1'}), 200

if __name__ == '__main__':
    app.run(port=5000, host='0.0.0.0', debug=True)
