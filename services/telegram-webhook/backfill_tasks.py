import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
import json
from dotenv import load_dotenv

# Load env for credentials and endpoint
load_dotenv(dotenv_path='../../.env')
BACKEND_URL = os.getenv('BACKEND_URL', 'https://telegram-webhook-c7dxdhg6czb6bpdt.southindia-01.azurewebsites.net')
FIREBASE_CREDS_NAME = os.getenv('FIREBASE_CREDENTIALS', 'sahaya-7df6d-firebase-adminsdk-fbsvc-ca821d9e1b.json')

# The JSON is in the project root
FIREBASE_CREDS = os.path.join('../../', FIREBASE_CREDS_NAME)

def backfill():
    if not os.path.exists(FIREBASE_CREDS):
        print(f"Error: Credentials not found at {FIREBASE_CREDS}")
        return

    # Initialize Firebase
    cred = credentials.Certificate(FIREBASE_CREDS)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    print("Checking for approved cards needing tasks...")
    
    # 1. Get all approved cards
    approved_cards = db.collection('problem_cards').where('status', '==', 'approved').get()
    
    # 2. Identify cards that already have tasks
    tasks = db.collection('tasks').get()
    cards_with_tasks = {t.to_dict().get('problemCardId') for t in tasks}
    
    needs_tasks = [c for c in approved_cards if c.id not in cards_with_tasks]
    
    if not needs_tasks:
        print("No approved cards need backfilling. Everything is up to date!")
        return

    print(f"Found {len(needs_tasks)} cards needing tasks. Starting backfill...")

    for card in needs_tasks:
        card_data = card.to_dict()
        print(f"Processing Card ID: {card.id} (NGO: {card_data.get('ngoId')})")
        
        # Trigger the task generation endpoint
        try:
            payload = {
                'problemCardId': card.id,
                'ngoId': card_data.get('ngoId')
            }
            response = requests.post(f"{BACKEND_URL}/generate-tasks", json=payload, timeout=30)
            
            if response.status_code == 200:
                print(f"  Successfully generated tasks for {card.id}: {response.json().get('taskIds')}")
            else:
                print(f"  Failed for {card.id}: {response.status_code} - {response.text}")
        except Exception as e:
            print(f"  Error processing {card.id}: {e}")

if __name__ == "__main__":
    backfill()
