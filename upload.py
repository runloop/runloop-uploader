import os
import json
import sys

from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Define the required scopes
SCOPES = ['https://www.googleapis.com/auth/youtube.upload']
CLIENT_SECRETS_FILE = 'client-secret.json'
TOKEN_FILE = 'token.json'
DEFAULTS_FILE = 'metadata.json'


def authenticate():
    credentials = None

    # Check if the token file exists
    if os.path.exists(TOKEN_FILE):
        credentials = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)

    # If there are no (valid) credentials available, let the user log in.
    if not credentials or not credentials.valid:
        if credentials and credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                CLIENT_SECRETS_FILE,
                SCOPES
            )
            credentials = flow.run_local_server(port=0)

        # Save the credentials for the next run
        with open(TOKEN_FILE, 'w') as token:
            token.write(credentials.to_json())

    return build('youtube', 'v3', credentials=credentials)


def upload_video(youtube, video_file):
    with open(DEFAULTS_FILE, 'r') as file:
        request_body = json.load(file)

    total_size = os.path.getsize(video_file)
    request_body['snippet']['title'] = os.path.basename(video_file)

    media = MediaFileUpload(video_file, chunksize=-1, resumable=True)
    request = youtube.videos().insert(
        part='snippet,status,localizations',
        body=request_body,
        media_body=media
    )

    # response = None
    # while response is None:
    #     status, response = request.next_chunk()
    #     if status:
    #         progress = int((status.resumable_progress / total_size) * 100)
    #         print(f"Upload progress: {progress}%")

    response = request.execute()
    print(f'Video uploaded: https://youtu.be/{response["id"]}')


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python upload_to_youtube.py <path_to_video_file>")
        sys.exit(1)

    video_file = sys.argv[1]

    if not os.path.exists(video_file):
        print(f"Error: The file '{video_file}' does not exist.")
        sys.exit(1)

    youtube = authenticate()
    upload_video(youtube, video_file)
