# Dynamically pull Google Python lightweight backend core
FROM python:3.13-slim

# Force application Python streams unbuffered directly binding native cloud logger structurally
ENV PYTHONUNBUFFERED True

WORKDIR /app

# Upgrade pip and suppress root warning natively
RUN pip install --upgrade pip --root-user-action=ignore

# Load explicitly the dependencies 
COPY requirements.txt ./

# Inject specific Gunicorn WSGI pipeline and physical text processors explicitly securely globally
RUN pip install --no-cache-dir -r requirements.txt gunicorn --root-user-action=ignore

# Secure strictly the application pipeline payload exclusively into Docker runtime filesystem
COPY . ./

# Map port automatically natively bound directly from Cloud Run initialization infrastructure securely globally! 
CMD exec gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 8 --timeout 0 app:app
